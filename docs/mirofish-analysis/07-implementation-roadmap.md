# 구현 로드맵

> MiroFish 패턴을 Decepticon에 적용하는 단계별 구현 계획

## Phase 1: 기반 구조 (Attack Graph Core)

### 목표
파일 기반 인메모리 그래프 엔진 구축. 기존 Decepticon 아키텍처를 변경하지 않고 병렬로 동작.

### 구현 항목

```
decepticon/graph/
├── __init__.py
├── schema.py              # 엔티티/엣지 Pydantic 모델 (06-attack-graph-ontology-spec.md)
├── store.py               # NetworkX 기반 그래프 저장소
│                            - add_entity(), add_edge()
│                            - get_entity(), get_neighbors()
│                            - save_to_json(), load_from_json()
│                            - 시간축 필터링 (valid_at/expired_at)
├── serialization.py       # JSON 직렬화/역직렬화
└── exceptions.py          # 그래프 관련 예외
```

### 저장 위치

```
/workspace/<engagement>/
├── plan/
├── findings.md           ← 기존 유지 (호환성)
├── attack_graph.json     ← 신규: 그래프 데이터
└── graph_log.jsonl       ← 신규: 그래프 변경 이력
```

### 핵심 설계 원칙

1. **findings.md와 공존**: 기존 파이프라인 깨지 않음. 그래프는 추가 레이어
2. **파일 기반 영속화**: Decepticon의 "디스크에 지식, 메모리 아님" 원칙 준수
3. **Pydantic v2**: 기존 코드 컨벤션 따름
4. **최소 의존성**: NetworkX만 추가 (순수 Python, C 확장 없음)

---

## Phase 2: 엔티티 추출기 (Entity Extractor)

### 목표
보안 도구 출력에서 엔티티/관계를 자동 추출하여 그래프에 삽입.

### 구현 항목

```
decepticon/graph/
├── extractors/
│   ├── __init__.py
│   ├── base.py            # ExtractorBase ABC
│   ├── nmap.py            # nmap XML/grepable → Host, Service, OS
│   ├── nikto.py           # nikto → Vulnerability, WebApp
│   ├── gobuster.py        # gobuster → WebApp endpoints
│   ├── cred_dump.py       # hashdump/mimikatz → Credential, User
│   ├── dns.py             # dig/nslookup/subfinder → Domain, Host
│   └── llm_fallback.py    # LLM 기반 범용 추출 (MiroFish 패턴)
├── updater.py             # FindingsGraphUpdater
│                            - 도구 출력 수신 → 적절한 extractor 선택
│                            - 추출 결과 → graph.store에 삽입
│                            - 동시에 findings.md에도 append (호환)
└── enrichment.py          # CVE DB 조회, MITRE ATT&CK 매핑
```

### LLM 폴백 추출기

MiroFish의 `OntologyGenerator` 패턴 적용:

```python
class LLMEntityExtractor(ExtractorBase):
    """범용 LLM 기반 엔티티/관계 추출"""

    SYSTEM_PROMPT = """
    보안 도구 출력에서 엔티티와 관계를 추출하세요.

    엔티티 타입: Host, Service, Vulnerability, Credential, User, Domain,
                 WebApplication, NetworkSegment, Technique, Asset

    관계 타입: HOSTS_SERVICE, HAS_VULNERABILITY, AUTHENTICATES_TO,
              RESOLVES_TO, EXPLOITED_BY, ENABLES_ACCESS, CAN_REACH,
              LATERAL_MOVE_TO, OWNED_BY, HAS_ACCESS, BELONGS_TO_SEGMENT,
              SERVES_APP

    JSON 형식으로 출력:
    {
      "entities": [{"type": "Host", "name": "...", "attributes": {...}}],
      "edges": [{"type": "HOSTS_SERVICE", "source": "...", "target": "...", "fact": "..."}]
    }
    """
```

### 통합 포인트: 미들웨어

```python
class GraphUpdateMiddleware:
    """
    에이전트 도구 실행 후 출력을 그래프에 반영하는 미들웨어.
    기존 SummarizationMiddleware와 유사한 위치에 삽입.

    SkillsMiddleware
    → FilesystemMiddleware
    → GraphUpdateMiddleware  ← 신규
    → SummarizationMiddleware
    → PromptCachingMiddleware
    → PatchToolCallsMiddleware
    """
```

---

## Phase 3: 추론 엔진 (Reasoning Engine)

### 목표
그래프 기반 공격 경로 탐색, TTP 추론, 다음 액션 제안.

### 구현 항목

```
decepticon/graph/
├── reasoning/
│   ├── __init__.py
│   ├── path_finder.py     # BFS/DFS 공격 경로 탐색
│   ├── ttp_mapper.py      # Vulnerability → MITRE Technique 매핑
│   ├── inference.py       # 추론 규칙 엔진 (횡적이동, 패스워드 재사용 등)
│   └── scorer.py          # 경로별 리스크/성공확률 스코어링
├── query.py               # AttackGraphQuery (에이전트 도구 인터페이스)
└── tools/
    ├── __init__.py
    └── graph_tools.py     # LangGraph 도구 정의
                             - attack_path_query
                             - vuln_chain_query
                             - ttp_suggest
                             - lateral_move_map
                             - asset_summary
                             - asset_timeline
```

### 에이전트 도구 등록

```python
# decepticon/agents/recon.py 에 추가
from decepticon.graph.tools.graph_tools import (
    attack_path_query,
    asset_summary,
)

# create_agent() 시 tools에 추가
tools = [bash_tool, attack_path_query, asset_summary]
```

---

## Phase 4: Orchestrator 통합

### 목표
Ralph 루프가 그래프를 쿼리하여 의사결정을 강화.

### 변경 사항

```python
# decepticon/agents/prompts/decepticon.md 확장
"""
<GRAPH_CONTEXT>
목표별 관련 자산을 Attack Graph에서 조회하여 컨텍스트를 구성하세요.

사용 가능한 그래프 도구:
- attack_path_query(from, to) — 공격 경로 탐색
- asset_summary(type, segment) — 자산 요약
- ttp_suggest(host, privilege) — 다음 기법 제안

목표 선정 시:
1. opplan.json에서 next_objective() 확인
2. attack_path_query()로 목표까지 경로 존재 여부 확인
3. 경로 없으면 → 선행 목표 우선 실행
4. 경로 있으면 → ttp_suggest()로 기법 확인 후 위임
</GRAPH_CONTEXT>
"""
```

### Kill-Chain Analysis 스킬 강화

```
skills/decepticon/kill-chain-analysis/SKILL.md 확장:

## 그래프 기반 분석

각 phase의 completeness를 그래프에서 평가:

| Phase | 지표 | 그래프 쿼리 |
|-------|------|------------|
| Recon | 발견된 호스트/서비스 수 | asset_summary(type=Host) |
| Initial Access | 공격 가능한 취약점 수 | vuln_chain_query(verified=true) |
| Execution | 확보된 크레덴셜 수 | asset_summary(type=Credential) |
| Lateral Movement | 횡적 이동 경로 수 | lateral_move_map() |
| Privilege Escalation | 권한 상승 경로 | attack_path_query(to="domain-admin") |
```

---

## Phase 5: 리포팅 & 시각화

### 목표
그래프 데이터를 활용한 공격 경로 시각화 및 리포트 자동 생성.

### 구현 항목

```
decepticon/graph/
├── reporting/
│   ├── __init__.py
│   ├── timeline.py        # 공격 타임라인 생성
│   ├── attack_path_viz.py # Mermaid/D3 그래프 시각화
│   └── executive_summary.py # 그래프 통계 기반 경영진 보고
```

### CLI 통합

```
clients/cli/src/components/
├── GraphView.tsx          # D3.js 공격 그래프 시각화 (MiroFish GraphPanel.vue 참조)
├── AttackPathView.tsx     # 공격 경로 하이라이트
└── TimelineView.tsx       # 시간순 이벤트 뷰
```

---

## 의존성 추가

```toml
# pyproject.toml
[project]
dependencies = [
    # ... 기존 ...
    "networkx>=3.2",         # 그래프 엔진
]
```

## 파일 구조 요약

```
decepticon/graph/
├── __init__.py
├── schema.py                 # Pydantic 엔티티/엣지 모델
├── store.py                  # NetworkX 그래프 저장소
├── serialization.py          # JSON 직렬화
├── exceptions.py
├── updater.py                # FindingsGraphUpdater
├── enrichment.py             # CVE/ATT&CK 매핑
├── query.py                  # AttackGraphQuery
├── extractors/
│   ├── __init__.py
│   ├── base.py
│   ├── nmap.py
│   ├── nikto.py
│   ├── gobuster.py
│   ├── cred_dump.py
│   ├── dns.py
│   └── llm_fallback.py
├── reasoning/
│   ├── __init__.py
│   ├── path_finder.py
│   ├── ttp_mapper.py
│   ├── inference.py
│   └── scorer.py
├── tools/
│   ├── __init__.py
│   └── graph_tools.py
└── reporting/
    ├── __init__.py
    ├── timeline.py
    ├── attack_path_viz.py
    └── executive_summary.py
```
