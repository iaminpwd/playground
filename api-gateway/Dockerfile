FROM python:3.10-slim-bookworm

WORKDIR /app

# 1. 시스템 의존성 및 Poetry 설치
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir poetry==1.8.3

# 2. 컨테이너 내부 가상환경 생성 비활성화 (컨테이너 자체가 격리 환경이므로)
RUN poetry config virtualenvs.create false

# 3. 레이어 캐싱 최적화: 소스코드보다 패키지 명세서를 먼저 복사
COPY pyproject.toml poetry.lock* ./

# 4. 의존성 설치 (캐시 활용)
RUN poetry install --no-root --no-interaction --no-ansi

# 5. 소스코드 복사
COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80"]