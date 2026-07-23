# 코드 리뷰 리포트

## auth_function.py (140줄)

### 스타일 검사
다음은 코드에서 발견된 PEP 8 및 일반적인 스타일 규칙 위반 목록입니다.

---

**공백 및 줄 길이 관련**

- [37] 줄 길이 초과: `logger.info(f"User {username} already exists. Proceeding to update credentials.")` — 79자 초과
- [47] 인라인 주석 공백 부족: `PasswordResetRequired=True # 최초 로그인 시...` — 인라인 주석 앞에는 공백 2칸이 필요 (`True  # ...`)
- [99] 줄 길이 초과: `return {"statusCode": 400, "body": json.dumps({"error": "Missing required field: username"})}` — 79자 초과
- [108] 줄 길이 초과: `"message": f"IAM User '{username}' created & assigned to '{department}'"` — 79자 초과
- [116] 줄 길이 초과: `return {"statusCode": 200, "body": json.dumps({"message": f"IAM User '{username}' deleted successfully"})}` — 79자 초과

---

**함수 간 빈 줄 관련**

- [21] 함수 정의 전 빈 줄 부족: 모듈 최상위 레벨의 함수/클래스 정의 사이에는 빈 줄 2개가 필요하나, `GROUP_MAPPING` 딕셔너리와 `generate_temp_password()` 함수 사이에 빈 줄이 1개만 존재
- [35] 함수 정의 전 빈 줄 부족: `generate_temp_password()`와 `create_iam_user()` 사이에 빈 줄이 1개만 존재 (2개 필요)
- [66] 함수 정의 전 빈 줄 부족: `create_iam_user()`와 `delete_iam_user()` 사이에 빈 줄이 1개만 존재 (2개 필요)
- [94] 함수 정의 전 빈 줄 부족: `delete_iam_user()`와 `lambda_handler()` 사이에 빈 줄이 1개만 존재 (2개 필요)

---

**변수명 관련**

- [104] 변수명 스타일 혼용: `temp_pwd`는 축약형으로, 코드 내 다른 곳에서 사용된 `temp_password`와 일관성이 없음 — 동일한 의미의 변수는 일관된 이름 사용 권장

---

**기타**

- [27] 미사용 루프 변수: `for i in range(length)`에서 `i`가 루프 내에서 사용되지 않으므로 관례상 `_`로 대체 권장 (`for _ in range(length)`)
- [29~32] 들여쓰기 정렬: 여러 줄에 걸친 조건문에서 `any(...)` 들여쓰기가 여는 괄호 기준으로 정렬되지 않고 임의로 들여쓰기 되어 있음

### 보안 검사
## 코드 보안 취약점 분석 결과

---

### ✅ 요청하신 3가지 항목 검토 결과

| 항목 | 결과 |
|------|------|
| SQL Injection | 해당 없음 (DB 미사용) |
| XSS | 해당 없음 (HTML 렌더링 없음) |
| 하드코딩된 비밀번호 | 없음 (secrets 모듈로 동적 생성) |

---

### ⚠️ 발견된 보안 취약점

---

#### 🔴 [심각도: 높음] 취약점 1 - 임시 비밀번호 평문 응답 반환

- **위치**: `lambda_handler()` 내 POST 응답 블록
```python
response_payload = {
    "temp_password": temp_pwd,  # 평문 비밀번호가 HTTP 응답에 포함
}
return {"statusCode": 201, "body": json.dumps(response_payload)}
```
- **유형**: 민감 정보 노출 (OWASP A02: Cryptographic Failures)
- **설명**: 생성된 임시 비밀번호가 API 응답 본문에 평문으로 포함되어 네트워크 로그, API Gateway 로그, 클라이언트 측 로그 등에 노출될 수 있습니다.
- **수정 제안**:
  - 비밀번호를 응답으로 반환하는 대신, AWS SES/SNS 등을 통해 사용자 이메일로 직접 전달
  - 또는 AWS Secrets Manager에 저장 후 별도 채널로 접근 권한 부여
  - 불가피하게 반환해야 한다면 HTTPS 통신 강제 및 응답 로깅 비활성화 필수

---

#### 🔴 [심각도: 높음] 취약점 2 - username 입력값 미검증

- **위치**: `lambda_handler()` 및 `create_iam_user()`, `delete_iam_user()`
```python
username = body.get('username')
if not username:
    return {"statusCode": 400, ...}
# 이후 username을 그대로 IAM API에 사용
iam.create_user(UserName=username)
iam.delete_user(UserName=username)
```
- **유형**: 입력값 검증 부재 (OWASP A03: Injection 유사 / A04: Insecure Design)
- **설명**: IAM UserName에 허용되지 않는 특수문자나 경로 조작 문자가 포함될 경우 예외 처리 없이 AWS API 호출로 이어지며, 악의적인 입력으로 의도하지 않은 리소스 조작 가능성이 있습니다. IAM UserName은 영숫자, `+`, `=`, `,`, `.`, `@`, `-`, `_` 만 허용됩니다.
- **수정 제안**:
```python
import re
def validate_username(username):
    if not re.match(r'^[\w+=,.@-]{1,64}$', username):
        raise ValueError(f"Invalid IAM username format: {username}")
```

---

#### 🟠 [심각도: 중간] 취약점 3 - department 미검증으로 인한 임의 그룹 할당 시도 가능

- **위치**: `lambda_handler()` POST 처리 블록
```python
department = body.get('department')
temp_pwd = create_iam_user(username, department)
```
- **유형**: 입력값 검증 부재 (OWASP A04: Insecure Design)
- **설명**: `department` 값이 None이거나 공백이어도 `create_iam_user()`로 전달됩니다. GROUP_MAPPING에 없으면 그룹 할당이 생략되지만, 이에 대한 명시적 오류 처리가 없어 사용자가 어느 그룹에도 속하지 않는 "고아 계정"이 생성될 수 있습니다.
- **수정 제안**:
```python
department = body.get('department')
if not department or department not in GROUP_MAPPING:
    return {"statusCode": 400, "body": json.dumps({"error": "Invalid or missing department"})}
```

---

#### 🟠 [심각도: 중간] 취약점 4 - 에러 메시지 내부 정보 노출

- **위치**: `lambda_handler()` 예외 처리
```python
return {"statusCode": 500, "body": json.dumps({"error": f"Internal Error: {str(e))"})}
```
- **유형**: 민감 정보 노출 (OWASP A05: Security Misconfiguration)
- **설명**: 내부 예외 메시지가 그대로 클라이언트에 반환되어 AWS ARN, 리소스명, 내부 구조 등 공격자에게 유용한 정보가 노출될 수 있습니다.
- **수정 제안**:
```python
logger.error(f"Error: {str(e)}")  # 상세 내용은 로그에만 기록
return {"statusCode": 500, "body": json.dumps({"error": "Internal server error"})}
```

---

#### 🟡 [심각도: 낮음] 취약점 5 - 인증/인가 메커니즘 부재

- **위치**: `lambda_handler()` 전체
- **유형**: 인증 실패 (OWASP A07: Identification and Authentication Failures)
- **설명**: Lambda 함수 자체에 호출자 인증 로직이 없습니다. API Gateway에서 IAM Auth 또는 Cognito Authorizer가 설정되어 있지 않다면 누구나 IAM 사용자 생성/삭제 API를 호출할 수 있습니다.
- **수정 제안**: API Gateway에 IAM 권한 기반 인증 또는 Lambda Authorizer 적용 필수

---

### 📋 종합 요약

| # | 위치 | 유형 | 심각도 |
|---|------|------|--------|
| 1 | POST 응답부 | 임시 비밀번호 평문 반환 | 🔴 높음 |
| 2 | username 처리 | 입력값 미검증 | 🔴 높음 |
| 3 | department 처리 | 입력값 미검증 | 🟠 중간 |
| 4 | 예외 처리부 | 내부 정보 노출 | 🟠 중간 |
| 5 | 함수 전체 | 인증/인가 부재 | 🟡 낮음 |

---

