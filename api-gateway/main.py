import os
import requests
import chromadb
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from gptcache import cache
from gptcache.processor.pre import get_prompt
from gptcache.embedding import Onnx
from gptcache.manager import CacheBase, VectorBase, get_data_manager
from gptcache.similarity_evaluation.distance import SearchDistanceEvaluation

# 환경 변수 주입
OLLAMA_ENDPOINT = os.getenv("OLLAMA_ENDPOINT", "http://service-llm-serving:11434/api/generate")
CHROMA_ENDPOINT = os.getenv("CHROMA_ENDPOINT", "http://service-vector-db:8000")

app = FastAPI(title="LLMOps API Gateway with Real RAG")

# 1. 시맨틱 캐시 엔진 초기화
print("Initializing Semantic Cache...")
onnx = Onnx()
data_manager = get_data_manager(CacheBase("sqlite"), VectorBase("faiss", dimension=onnx.dimension))
cache.init(
    pre_embedding_func=get_prompt,
    embedding_func=onnx.to_embeddings,
    data_manager=data_manager,
    similarity_evaluation=SearchDistanceEvaluation(),
)

# 2. 실제 ChromaDB 클라이언트 초기화 및 가상 사내 문서 주입 (Bootstrap)
print(f"Connecting to ChromaDB at {CHROMA_ENDPOINT}...")
chroma_client = chromadb.HttpClient(host=CHROMA_ENDPOINT.split("//")[1].split(":")[0], port=int(CHROMA_ENDPOINT.split(":")[-1]))

# 'company_docs'라는 이름의 테이블(컬렉션) 생성 또는 가져오기
collection = chroma_client.get_or_create_collection(name="company_docs")

# 테스트용 사내 지식 데이터가 비어있다면 강제로 주입 (최초 1회만 실행됨)
if collection.count() == 0:
    print("Database is empty. Injecting internal company guidelines...")
    collection.add(
        documents=[
            "AWS EKS 비용 절감 가이드: 무조건 Karpenter를 도입하고 스팟 인스턴스 비율을 70% 이상으로 유지할 것. 사용하지 않는 개발계 클러스터는 주말 동안 복제본(Replicas)을 0으로 스케일 다운한다.",
            "사내 인프라 보안 수칙: 모든 쿠버네티스 서비스는 ClusterIP를 기본으로 하며, 외부 노출이 필요한 경우 오직 전면의 Traefik Ingress Controller를 통해서만 라우팅 경로를 개설해야 한다.",
            "데이터베이스 백업 정책: Vector DB 및 메인 데이터베이스는 매일 새벽 3시에 AWS S3 스토리지로 가용 영역을 교차하여 스냅샷 백업을 수행한다."
        ],
        ids=["doc_eks_cost", "doc_security", "doc_backup"]
    )
print("ChromaDB Initialization Completed.")

class ChatRequest(BaseModel):
    query: str

@app.post("/v1/chat")
async def chat_endpoint(request: ChatRequest):
    user_query = request.query

    # 단계 1: 시맨틱 캐시 확인
    cache_result = cache.get(user_query)
    if cache_result:
        return {
            "query": user_query,
            "response": cache_result,
            "cache_status": "HIT",
            "cost_saved": True
        }

    try:
        # 단계 2: 캐시 미스 시, 실제 ChromaDB에서 사용자 질문과 유사한 사내 지식 검색 (RAG)
        # 사용자가 던진 질문과 가장 유사한 문서 1개를 DB에서 서칭해옵니다.
        db_results = collection.query(
            query_texts=[user_query],
            n_results=1
        )
        
        # DB에 일치하는 문서가 있으면 가져오고, 없으면 기본 컨텍스트 지정
        if db_results and db_results['documents'] and db_results['documents'][0]:
            retrieved_context = db_results['documents'][0][0]
        else:
            retrieved_context = "관련 사내 지식 문서를 찾지 못했습니다."
        
        # 단계 3: DB에서 뽑아온 실제 문맥을 프롬프트에 조립
        enriched_prompt = f"Context: {retrieved_context}\n\nQuestion: {user_query}\n\n사내 가이드라인 문맥(Context)을 기반으로 질문에 친절하게 답변해줘."
        payload = {
            "model": "llama3",
            "prompt": enriched_prompt,
            "stream": False
        }

        # 단계 4: 백엔드 Ollama 엔진으로 추론 요청
        response = requests.post(OLLAMA_ENDPOINT, json=payload, timeout=120)
        response.raise_for_status()
        llm_response = response.json().get("response", "")

        # 단계 5: 새로운 답변을 캐시에 저장
        cache.import_data(user_query, llm_response)

        return {
            "query": user_query,
            "response": llm_response,
            "cache_status": "MISS",
            "cost_saved": False,
            "retrieved_doc": retrieved_context # 어떤 문서를 DB에서 참조했는지 증적 노출
        }
        
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=502, detail=f"LLM Engine Connection Error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Database Query Error: {str(e)}")