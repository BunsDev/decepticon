# MiroFish 시뮬레이션 파이프라인

## 전체 흐름

```
SimulationManager.create_simulation()
    → CREATED
        ↓
SimulationManager.prepare_simulation()
    → PREPARING
    [Stage 1] ZepEntityReader.filter_defined_entities()
    [Stage 2] OasisProfileGenerator.generate_profiles_from_entities()
    [Stage 3] SimulationConfigGenerator.generate_config()
    → READY
        ↓
SimulationRunner.start_simulation()
    → RUNNING
    subprocess.Popen(run_parallel_simulation.py)
    _monitor_thread → actions.jsonl / rounds.jsonl 파싱
    ZepGraphMemoryUpdater → 실시간 그래프 업데이트
    → COMPLETED | STOPPED | FAILED
        ↓
ReportAgent.generate_report()
    → 그래프 검색 + ReACT 리포트 생성
```

## 상태 머신

```
CREATED → PREPARING → READY → RUNNING → COMPLETED
               ↓                  ↓         ↓
            FAILED             PAUSED    STOPPED
```

## Stage 1: 엔티티 읽기

```python
ZepEntityReader.filter_defined_entities(graph_id, enrich_with_edges=True)
```

- 그래프의 모든 노드 조회
- 온톨로지 타입에 매칭되는 노드만 필터링
- 각 엔티티에 관련 엣지/노드 정보 첨부
- 출력: `FilteredEntities` (entities, entity_types, counts)

## Stage 2: 프로필 생성

```python
OasisProfileGenerator.generate_profiles_from_entities(
    entities, use_llm=True,
    graph_id=graph_id,          # Zep 검색으로 컨텍스트 강화
    parallel_count=3,            # 3개씩 병렬 생성
    realtime_output_path=...     # 생성 중 실시간 파일 저장
)
```

### 엔티티 타입 분류

- **개인형** (student, professor, person, journalist 등): 구체적 인물 프로필
- **집단형** (university, organization, company 등): "대표자" 프로필 생성

### 프로필 구조 (OasisAgentProfile)

```python
{
    "user_id": int,
    "username": str,
    "name": str,
    "bio": str,
    "persona": str,          # 상세 인물 설정 (LLM 생성)
    "karma": int,            # Reddit 카르마
    "friend_count": int,     # Twitter 친구
    "follower_count": int,   # Twitter 팔로워
    "age": int,
    "gender": str,
    "mbti": str,
    "country": str,
    "profession": str,
    "interested_topics": [str],
    "source_entity_uuid": str,
    "source_entity_type": str
}
```

### Zep 검색 컨텍스트 강화

```python
_search_zep_for_entity(entity):
    ThreadPoolExecutor:
        - graph.edge.search(query=entity.name)  # 관련 사실
        - graph.node.search(query=entity.name)  # 관련 노드
    → facts + node_summaries + context 통합
```

## Stage 3: 시뮬레이션 설정 생성

```python
SimulationConfigGenerator.generate_config(
    simulation_requirement, document_text, entities, ...)
```

### 분할 생성 전략 (LLM 출력 길이 제한 대응)

```
Step 1: _generate_time_config()       → TimeSimulationConfig
Step 2: _generate_event_config()      → EventConfig
Step 3: _generate_agent_configs()     → 15개씩 배치 AgentActivityConfig
Step 4: _generate_platform_config()   → PlatformConfig
```

### 설정 구조 (SimulationParameters)

```
SimulationParameters:
├── time_config:
│     total_simulation_hours=72, minutes_per_round=60
│     peak_hours=[19-22], off_peak_hours=[0-5]
│     activity_multipliers (중국 시간대 기반)
├── agent_configs: (에이전트별)
│     activity_level (0.0-1.0)
│     posts_per_hour, comments_per_hour
│     sentiment_bias (-1.0~1.0), stance, influence_weight
├── event_config:
│     initial_posts[], scheduled_events[], hot_topics[]
│     narrative_direction
└── platform_config: (Twitter/Reddit)
      recency/popularity/relevance_weight
      viral_threshold=10, echo_chamber_strength=0.5
```

## 시뮬레이션 실행

### SimulationRunner

```python
start_simulation(simulation_id):
    1. simulation_config.json 로드
    2. subprocess.Popen(["python", "scripts/run_parallel_simulation.py", ...])
    3. stdout → script_stdout.log
    4. _monitor_thread 시작
    5. ZepGraphMemoryManager.create_updater()
```

### 실시간 모니터링

```
_monitor_thread:
    while process.poll() is None:
        actions.jsonl 새 줄 → AgentAction → run_state.add_action()
                                          → ZepGraphMemoryUpdater.add_activity()
        rounds.jsonl 새 줄 → RoundSummary
        "simulation_end" 이벤트 감지 → 플랫폼 완료
```

### IPC (Flask ↔ OASIS)

```
Flask: ipc_commands/{command_id}.json 생성
OASIS: 커맨드 디렉토리 폴링 → 실행 → ipc_responses/{command_id}.json
Flask: 응답 디렉토리 폴링 (0.5초 간격, 60초 타임아웃)
```

커맨드: `INTERVIEW`, `BATCH_INTERVIEW`, `CLOSE_ENV`

## 리포트 생성

### ReportAgent (ReACT 패턴)

```
[Planning]   LLM → 아웃라인 (섹션 목록 + 연구 방향)
[Generation] 각 섹션별:
    ReACT 루프 (최대 5회):
        ① Thought → 무엇을 조사할지
        ② Action → InsightForge / PanoramaSearch / Statistics
        ③ Observation → 도구 결과
        ④ 반복 or Final Answer
    → section_{index:02d}.md 저장
[Completion] 전체 합치기 → Report
```

### 로깅 시스템

- `agent_log.jsonl`: 모든 단계 구조화 기록 (타임스탬프, 도구 호출/결과, LLM 응답 전문)
- `console_log.txt`: 사람이 읽는 텍스트 로그
