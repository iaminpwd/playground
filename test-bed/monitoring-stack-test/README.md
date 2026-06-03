
<img width="3357" height="1714" alt="스크린샷 2026-03-08 182741" src="https://github.com/user-attachments/assets/2a30ca7f-5fba-422d-a475-688cf4a5ff01" />

# 🚀 K3s Monitoring Automation Stack

이 프로젝트는 앤서블(Ansible)을 사용하여 **K3s 클러스터 구축**부터 **중앙 집중식 모니터링 시스템(Prometheus & Grafana)** 배포까지 전 과정을 자동화합니다. 특히 **Prometheus Remote Write** 모드를 적용하여 에이전트와 서버를 분리한 효율적인 메트릭 수집 환경을 제공합니다.

## 🏗️ Architecture

본 인프라는 부하 분산과 가용성을 고려하여 **Pull & Push 하이브리드 모니터링** 구조를 가집니다.

* **Monitoring Node (Localhost):** Docker Compose를 통해 중앙 Prometheus 서버와 Grafana를 실행합니다. 에이전트가 보내는 데이터를 수신(Remote Write Receiver)하고 시각화하며, 알람을 관리합니다.
* **K3s Agent Node:** K3s 클러스터 내부에서 Prometheus가 **에이전트 모드**로 동작하며, 수집한 메트릭을 중앙 서버로 즉시 전송하여 클러스터 부하를 최소화합니다.
* **Sidecar Exporters:** Nginx와 MySQL 파드에 각각 전용 익스포터를 사이드카로 배치하여 상세 지표를 추출합니다.

---

## 🛠 Tech Stack

| Category | Technology |
| --- | --- |
| **Automation** | Ansible (Collections: `community.docker`) |
| **Orchestration** | K3s (Lightweight Kubernetes) |
| **Container** | Docker, Docker Compose (on Monitoring Node) |
| **Monitoring** | Prometheus (Remote Write & Agent Mode), Node Exporter |
| **Visualization** | Grafana (Automated Provisioning) |
| **Alerting** | Discord Webhook Integration |

---

## 📂 Project Structure

전체 디렉토리 구조와 주요 파일 역할은 다음과 같습니다.

```text
.
├── ansible.cfg              # Ansible 실행 설정 및 Vault 경로 지정 [cite: 2]
├── site.yml                 # 전체 플레이북 통합 실행 파일
├── requirements.yml         # 외부 Ansible Collection 의존성 관리
├── inventory/               # 서버 인벤토리 및 변수 관리
│   ├── hosts.ini            # [control-plane], [web], [db] 그룹 정의
│   └── group_vars/          # K3s 전역 변수 및 암호화된 비밀 정보
├── playbooks/               # 4단계 배포 프로세스
│   ├── 01-setup-env.yml     # 로컬 의존성(Docker Collection) 설치
│   ├── 02-install-k3s.yml   # K3s 마스터 및 워커 노드 구성
│   ├── 03-monitoring.yml    # 중앙 모니터링 서버 및 K3s 에이전트 설치
│   └── 04-install-pods.yml  # Nginx(HPA), MySQL 샘플 워크로드 배포
└── roles/                   # 기능별 자동화 역할(Roles)
    ├── common/              # 공통 시스템 설정
    ├── docker_setup/        # Docker 설치 및 구성
    ├── k3s_master/          # 기초 환경 및 클러스터 구성
    ├── k3s_worker/          # 기초 환경 및 클러스터 구성
    ├── monitoring_stack/    # Docker 기반 중앙 모니터링 시스템 구축
    ├── prometheus_agent/    # K3s 내부 에이전트 및 RBAC 설정
    ├── web_server/          # 샘플 워크로드 배포
    └── mysql_server/        # 샘플 워크로드 배포

```

---

## ✨ Key Features & Implementation

### 1. Prometheus Remote Write & Agent Mode

* K3s 노드에 설치된 Prometheus를 `--agent` 모드로 활성화하여 로컬 저장소 부하를 없애고 중앙 서버로 데이터를 쏩니다.
* 중앙 서버는 `--web.enable-remote-write-receiver` 옵션을 통해 데이터를 수신합니다.

### 2. Automated Grafana Provisioning

* **Dashboards:** K3s 클러스터, Node Exporter, MySQL, Nginx 대시보드가 자동으로 설치됩니다.
* **Alerting:** CPU 80%, 메모리 90%, 디스크 20% 미만 등의 임계치 도달 시 Discord로 알람이 발송됩니다.

### 3. Application Hardening & Scaling

* **Nginx HPA:** CPU 사용량이 60%를 초과할 경우 최대 5개까지 파드를 자동 확장합니다.
* **Security:** Discord Webhook은 **Ansible Vault**를 통해 암호화되고, K3s Secret으로 안전하게 관리됩니다.

---

## 🚀 Quick Start

### 1. 사전 준비

* 관리자 노드에 Ansible 설치
* Vagrant 또는 대상 Ubuntu 서버 환경 구성 (`192.168.56.x` 대역 권장)

### 2. 보안 설정

`.vault_pass` 파일에 Vault 암호를 기재합니다. (해당 파일은 `.gitignore`에 의해 깃 관리에서 제외됩니다.)

```bash
echo "your_vault_password" > .vault_pass

```

### 3. 전체 배포 실행

```bash
# 의존성 컬렉션 설치 및 전체 인프라 배포
ansible-playbook site.yml

```

---

## 📊 Monitoring Dashboards

배포 완료 후 아래 주소를 통해 대시보드에 접속할 수 있습니다.

* **Grafana:** `http://localhost:3000` (ID: admin / PW: 1234)
* **Prometheus:** `http://localhost:9090`
