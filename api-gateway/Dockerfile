# 기존의 alpine이나 단순 python:3.10 대신, ML 호환성이 가장 높은 bookworm-slim 사용
FROM python:3.10-slim-bookworm

WORKDIR /app

# 시스템 레벨의 의존성 패키지 설치 (빌드 에러 방지)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80"]