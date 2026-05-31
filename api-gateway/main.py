import os
import requests
import chromadb
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# gptcache 표준 조회/적재 API 임포트
from gptcache import cache
from gptcache.adapter.api import get, put
from gptcache.processor.pre import get_prompt
from gptcache.embedding import Onnx
from gptcache.manager import CacheBase, VectorBase, get_data_manager
from gptcache.similarity_evaluation.distance import SearchDistanceEvaluation

OLLAMA_ENDPOINT = os.getenv("OLLAMA_ENDPOINT", "http://service-llm-serving:11434/api/generate")
CHROMA_ENDPOINT = os.getenv("CHROMA_ENDPOINT", "http://service-vector-db:8000")

app = FastAPI(title="LLMOps API Gateway - Production Stable")

# 1. 시맨틱 캐시 초기화
print("Initializing Semantic Cache Engine...")
try:
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
except Exception as cache_err:
    print(f"Cache Initialization Warnings: {str(cache_err)}")

# 2. ChromaDB 연결 및 가상 지식 주입 (Bootstrap)
print(f"Connecting to ChromaDB at {CHROMA_ENDPOINT}...")
try:
    host_ip = CHROMA_ENDPOINT.split("//")[-1].split(":")[0]
    host_port = int(CHROMA_ENDPOINT.split(":")[-1])
    chroma_client = chromadb.HttpClient(host=host_ip, port=host_port)
    collection = chroma_client.get_or_create_collection(name="company_docs")
    
    if collection.count() == 0:
        print("Injecting bootstrap data into ChromaDB...")
        collection.add(
            documents=[
                "AWS EKS 비용 절감 가이드: 무조건 Karpenter를 도입하고 스팟 인스턴스 비율을 70% 이상으로 유지할 것. 사용하지 않는 개발계 클러스터는 주말 동안 복제본(Replicas)을 0으로 스케일 다운한다.",
                "사내 인프라 보안 수칙: 모든 쿠버네티스 서비스는 ClusterIP를 기본으로 하며, 외부 노출이 필요한 경우 오직 전면의 Traefik Ingress Controller를 통해서만 라우팅 경로를 개설해야 한다.",
                "데이터베이스 백업 정책: Vector DB 및 메인 데이터베이스는 매일 새벽 3시에 AWS S3 스토리지로 가용 영역을 교차하여 스냅샷 백업을 수행한다."
            ],
            ids=["doc_eks_cost", "doc_security", "doc_backup"]
        )
except Exception as chroma_err:
    print(f"ChromaDB Bridge Failed: {str(chroma_err)}")

class ChatRequest(BaseModel):
    query: str

@app.post("/v1/chat")
async def chat_endpoint(request: ChatRequest):
    user_query = request.query

    # [교정] 단계 1: gptcache 표준 API 함수로 캐시 레이어 검증
    try:
        cache_result = get(user_query) # cache.get(user_query) 대신 공식 get 함수 사용
        if cache_result:
            return {
                "query": user_query, 
                "response": cache_result, 
                "cache_status": "HIT", 
                "cost_saved": True
            }
    except Exception as e:
        print(f"Cache get error: {str(e)}")

    try:
        # 단계 2: DB 지식 문서 조회 (RAG)
        retrieved_context = "관련 사내 지식 문서를 찾지 못했습니다."
        try:
            db_results = collection.query(query_texts=[user_query], n_results=1)
            if db_results and db_results['documents'] and db_results['documents'][0]:
                retrieved_context = db_results['documents'][0][0]
        except Exception as db_err:
            print(f"DB Query warning: {str(db_err)}")

        # 단계 3: 프롬프트 빌드 및 백엔드 추론 요청
        enriched_prompt = f"Context: {retrieved_context}\n\nQuestion: {user_query}\n\n사내 가이드라인 문맥(Context)을 기반으로 질문에 친절하게 답변해줘."
        payload = {"model": "llama3", "prompt": enriched_prompt, "stream": False}

        response = requests.post(OLLAMA_ENDPOINT, json=payload, timeout=60)
        response.raise_for_status()
        llm_response = response.json().get("response", "")

        # [교정] 단계 4: gptcache 표준 API 함수로 새로운 데이터 캐시 적재
        try:
            put(user_query, llm_response) # cache.import_data 대신 공식 put 함수 사용
        except Exception as e:
            print(f"Cache put error: {str(e)}")

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
        raise HTTPException(status_code=500, detail=f"Internal Server Pipeline Error: {str(e)}")