import os
import requests
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from gptcache import cache
from gptcache.processor.pre import get_prompt
from gptcache.embedding import Onnx
from gptcache.manager import CacheBase, VectorBase, get_data_manager
from gptcache.similarity_evaluation.distance import SearchDistanceEvaluation

# K8s ConfigMap에서 주입되는 환경 변수 (기본값 세팅)
OLLAMA_ENDPOINT = os.getenv("OLLAMA_ENDPOINT", "http://service-llm-serving:11434/api/generate")
CHROMA_ENDPOINT = os.getenv("CHROMA_ENDPOINT", "http://service-vector-db:8000")

app = FastAPI(title="LLMOps API Gateway with Semantic Cache")

# 서버 시작 시 1회: 시맨틱 캐시 엔진 초기화
print("Initializing Semantic Cache...")
onnx = Onnx()
data_manager = get_data_manager(CacheBase("sqlite"), VectorBase("faiss", dimension=onnx.dimension))
cache.init(
    pre_embedding_func=get_prompt,
    embedding_func=onnx.to_embeddings,
    data_manager=data_manager,
    similarity_evaluation=SearchDistanceEvaluation(),
)
print("Semantic Cache Initialized Successfully.")

# API 요청 페이로드 모델
class ChatRequest(BaseModel):
    query: str

@app.post("/v1/chat")
async def chat_endpoint(request: ChatRequest):
    user_query = request.query

    # 단계 1: 시맨틱 캐시 확인 (의미상 유사한 질문이 들어온 적 있는가?)
    cache_result = cache.get(user_query)
    
    if cache_result:
        return {
            "query": user_query,
            "response": cache_result,
            "cache_status": "HIT",  # 캐시 적중: LLM 호출 비용 및 대기 시간 0
            "cost_saved": True
        }

    # 단계 2: 캐시 미스 시, 벡터 DB에서 사내 문서 조회 (RAG)
    # (실무에서는 이 부분에 ChromaDB SDK 쿼리 로직이 들어갑니다)
    retrieved_context = "[사내 인프라 가이드: AWS EKS 비용 절감 규칙...]"
    
    # 프롬프트 조립
    enriched_prompt = f"Context: {retrieved_context}\n\nQuestion: {user_query}"
    payload = {
        "model": "llama3",
        "prompt": enriched_prompt,
        "stream": False
    }

    try:
        # 단계 3: 백엔드 Ollama 엔진으로 실제 추론 요청
        response = requests.post(OLLAMA_ENDPOINT, json=payload, timeout=120)
        response.raise_for_status()
        llm_response = response.json().get("response", "")

        # 단계 4: 새로운 답변을 캐시에 저장 (다음번 유사 질문 방어용)
        cache.import_data(user_query, llm_response)

        return {
            "query": user_query,
            "response": llm_response,
            "cache_status": "MISS", # 캐시 실패: 실제 LLM 연산 발생
            "cost_saved": False
        }
        
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=502, detail=f"LLM Engine Connection Error: {str(e)}")