# 1. 경량화된 Python 3.10 기반 이미지 사용
FROM python:3.10-slim

# 2. 작업 디렉토리 설정
WORKDIR /app

# 3. 시스템 의존성 패키지 설치 (FAISS 및 ONNX 빌드용)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# 4. 의존성 목록 복사 및 캐시 없이 설치 (이미지 경량화)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 5. 애플리케이션 소스코드 복사
COPY main.py .

# 6. 통신 포트 노출 (K8s 매니페스트의 80번 포트와 매핑됨)
EXPOSE 80

# 7. FastAPI 서버 실행 (Uvicorn ASGI 서버 활용)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80"]