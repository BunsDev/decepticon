# MiroFish 아키텍처 분석

> MiroFish (666ghj/MiroFish) — 군중 지능 기반 범용 예측 엔진, 42K+ GitHub stars

## 기술 스택

| 레이어 | 기술 | 역할 |
|--------|------|------|
| Backend | Flask (Python 3.11) | REST API 서버 |
| Frontend | Vue 3 + D3.js | SPA + 그래프 시각화 |
| Graph Engine | Zep Cloud (SaaS) | 지식 그래프 저장/검색/온톨로지 |
| Simulation | OASIS Framework | 멀티 에이전트 소셜 시뮬레이션 |
| LLM | OpenAI 호환 API (gpt-4o-mini) | 온톨로지/프로필/설정/리포트 생성 |
| Infra | Docker Compose | 컨테이너 오케스트레이션 |

## 5단계 파이프라인

```
문서 업로드 → 온톨로지 생성 → 그래프 구축 → 시뮬레이션 실행 → 리포트 생성
  (Step 1)      (Step 1)       (Step 2)       (Step 3-5)        (Step 4-5)
```

## 백엔드 모듈 구조

```
backend/app/
├── __init__.py              # Flask 앱 팩토리 (create_app)
├── config.py                # 환경변수 기반 설정 (Config 클래스)
├── api/
│   ├── graph.py             # /api/graph — 프로젝트/온톨로지/그래프 CRUD
│   ├── simulation.py        # /api/simulation — 시뮬레이션 라이프사이클
│   └── report.py            # /api/report — 리포트 생성/조회/채팅
├── services/
│   ├── ontology_generator.py       # LLM → 엔티티/관계 타입 정의
│   ├── graph_builder.py            # Zep API로 지식 그래프 구축
│   ├── text_processor.py           # 텍스트 전처리/청킹
│   ├── zep_entity_reader.py        # 그래프 노드 필터링/읽기
│   ├── zep_tools.py                # 시맨틱 검색 도구 (InsightForge, Panorama)
│   ├── zep_graph_memory_updater.py # 시뮬레이션 중 실시간 그래프 업데이트
│   ├── oasis_profile_generator.py  # 엔티티 → 에이전트 프로필 변환
│   ├── simulation_config_generator.py # LLM → 시뮬레이션 파라미터
│   ├── simulation_manager.py       # 시뮬레이션 라이프사이클 관리
│   ├── simulation_runner.py        # 서브프로세스 실행/모니터링
│   ├── simulation_ipc.py           # 파일 기반 IPC (Flask ↔ OASIS)
│   └── report_agent.py             # ReACT 패턴 리포트 생성
├── models/
│   ├── project.py           # 프로젝트 상태 (파일시스템 영속화)
│   └── task.py              # 태스크 상태 (인메모리 싱글톤)
└── utils/
    ├── llm_client.py        # OpenAI SDK 래퍼
    ├── file_parser.py       # PDF/MD/TXT 파서
    ├── zep_paging.py        # Zep 페이지네이션 유틸
    ├── retry.py             # 재시도 유틸
    └── logger.py            # 로깅
```

## 핵심 설계 패턴

### 1. 파일 시스템 기반 영속화
- DB 없음. `uploads/projects/{id}/project.json`, `uploads/simulations/{id}/state.json`
- 장점: 단순, 디버깅 용이
- 단점: 동시성 제한, 검색 불가

### 2. Threading 기반 비동기
- 그래프 구축, 시뮬레이션 준비, 리포트 생성 → `threading.Thread(daemon=True)`
- TaskManager (싱글톤)로 진행률 추적
- asyncio 미사용

### 3. LLM 전 파이프라인 드리븐
- 온톨로지 생성, 프로필 생성, 시뮬레이션 설정, 리포트 작성 모두 LLM 호출
- 각 단계에서 컨텍스트 제한 (50K자) 적용

### 4. 파일 기반 IPC
- Flask ↔ OASIS 서브프로세스 간 통신
- `ipc_commands/` → `ipc_responses/` 디렉토리 폴링

### 5. REST Polling
- WebSocket 미구현, 프론트엔드가 주기적 REST 요청으로 상태 확인
