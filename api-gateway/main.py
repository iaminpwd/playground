import os
import requests
import chromadb
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from gptcache import cache
from gptcache.adapter.api import get, put
from gptcache.processor.pre import get_prompt
from gptcache.embedding import Onnx
from gptcache.manager import CacheBase, VectorBase, get_data_manager
from gptcache.similarity_evaluation.distance import SearchDistanceEvaluation

OLLAMA_ENDPOINT = os.getenv("OLLAMA_ENDPOINT", "http://service-llm-serving:11434/api/generate")
CHROMA_ENDPOINT = os.getenv("CHROMA_ENDPOINT", "http://service-vector-db:8000")

app = FastAPI(title="LLMOps API Gateway - Bulletproof RAG")

print("Initializing Semantic Cache Engine...")
os.makedirs("/tmp/gptcache", exist_ok=True)
onnx = Onnx()
data_manager = get_data_manager(
    CacheBase("sqlite", path="/tmp/gptcache/db.sqlite"), 
    VectorBase("faiss", dimension=onnx.dimension, top_k=1, index_path="/tmp/gptcache/faiss.index")
)
cache.init(
    pre_embedding_func=get_prompt,
    embedding_func=onnx.to_embeddings,
    data_manager=data_manager,
    similarity_evaluation=SearchDistanceEvaluation(),
)

print(f"Connecting to ChromaDB at {CHROMA_ENDPOINT}...")
host_ip = CHROMA_ENDPOINT.split("//")[-1].split(":")[0]
host_port = int(CHROMA_ENDPOINT.split(":")[-1])
chroma_client = chromadb.HttpClient(host=host_ip, port=host_port)

# [교정 1] 초기 지식 적재 시 NumPy 배열의 Rust 코어 패닉을 막기 위해 .tolist() 강제 변환 레이어 추가
collection = chroma_client.get_or_create_collection(
    name="company_docs",
    embedding_function=lambda input: [onnx.to_embeddings(text).tolist() for text in input]
)

if collection.count() == 0:
    print("Injecting enterprise documents with local embeddings...")
    docs = [
        "AWS EKS 비용 절감 가이드: 무조건 Karpenter를 도입하고 스팟 인스턴스 비율을 70% 이상으로 유지할 것. 사용하지 않는 개발계 클러스터는 주말 동안 복제본(Replicas)을 0으로 스케일 다운한다.",
        "사내 인프라 보안 수칙: 모든 쿠버네티스 서비스는 ClusterIP를 기본으로 하며, 외부 노출이 필요한 경우 오직 전면의 Traefik Ingress Controller를 통해서만 라우팅 경로를 개설해야 한다.",
        "데이터베이스 백업 정책: Vector DB 및 메인 데이터베이스는 매일 새벽 3시에 AWS S3 스토리지로 가용 영역을 교차하여 스냅샷 백업을 수행한다."
    ]
    # NumPy 배열을 안전한 파이썬 리스트로 형변환하여 주입
    embeddings = [onnx.to_embeddings(d).tolist() for d in docs]
    collection.add(
        documents=docs,
        embeddings=embeddings,
        ids=["doc_eks_cost", "doc_security", "doc_backup"]
    )

class ChatRequest(BaseModel):
    query: str

# [교정 2] async def -> def 로 변경. 동기식 requests.post가 이벤트 루프를 마비시키지 않도록 스레드풀로 격리
@app.post("/v1/chat")
def chat_endpoint(request: ChatRequest):
    user_query = request.query

    try:
        cache_result = get(user_query)
        if cache_result:
            return {"query": user_query, "response": cache_result, "cache_status": "HIT", "cost_saved": True}
    except Exception as e:
        print(f"Cache lookup bypassed: {str(e)}")

    try:
        # [교정 3] 쿼리 시에도 NumPy 배열을 명시적 리스트로 캐스팅 (.tolist())
        query_vector = onnx.to_embeddings(user_query).tolist()
        retrieved_context = "관련 사내 지식 문서를 찾지 못했습니다."
        
        db_results = collection.query(
            query_embeddings=[query_vector], 
            n_results=1
        )
        if db_results and db_results['documents'] and db_results['documents'][0]:
            retrieved_context = db_results['documents'][0][0]

        enriched_prompt = f"Context: {retrieved_context}\n\nQuestion: {user_query}\n\n사내 가이드라인 문맥(Context)을 기반으로 질문에 친절하게 답변해줘."
        payload = {"model": "llama3", "prompt": enriched_prompt, "stream": False}

        # 스레드풀에서 안전하게 실행되는 블로킹 요청
        response = requests.post(OLLAMA_ENDPOINT, json=payload, timeout=60)
        response.raise_for_status()
        llm_response = response.json().get("response", "")

        try:
            put(user_query, llm_response)
        except Exception:
            pass

        return {
            "query": user_query,
            "response": llm_response,
            "cache_status": "MISS",
            "cost_saved": False,
            "retrieved_doc": retrieved_context
        }
        
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=502, detail=f"LLM Engine Connection Error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")