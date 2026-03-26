# MiroFish 그래프 시스템

## 아키텍처

```
텍스트 청킹 → Zep 에피소드 전송 → Zep 자동 추출 → 노드/엣지 생성
                                    (서버사이드)
                                         ↓
                              시맨틱 검색 / BFS 검색
                                         ↓
                              시뮬레이션 중 실시간 업데이트
```

MiroFish는 자체 그래프 DB를 구현하지 않고 **Zep Cloud SaaS**에 모든 그래프 연산을 위임한다.

## GraphBuilderService

위치: `backend/app/services/graph_builder.py`

### 비동기 구축 파이프라인

```
build_graph_async() → daemon thread:

  [5%]   TaskStatus.PROCESSING
  [10%]  create_graph()
           → Zep.graph.create(graph_id="mirofish_{uuid16}")
  [15%]  set_ontology()
           → 동적 Pydantic 모델 생성 → Zep.graph.set_ontology()
  [20%]  TextProcessor.split_text(chunk_size=500, overlap=50)
  [20-60%] add_text_batches(batch_size=3)
           → EpisodeData(data=chunk, type="text")
           → Zep.graph.add_batch() + time.sleep(1)
  [60-90%] _wait_for_episodes()
           → episode.processed 폴링 (3초 간격, 600초 타임아웃)
  [90%]  _get_graph_info() → fetch_all_nodes/edges
  [100%] TaskManager.complete_task()
```

### 동적 Pydantic 모델 생성

온톨로지 JSON의 각 entity/edge 타입을 런타임에 Python 클래스로 변환:

```python
# 엔티티 클래스
entity_class = type(name, (EntityModel,), {
    "__doc__": description,
    "__annotations__": {attr_name: Optional[EntityText]},
    attr_name: Field(description=..., default=None)
})

# 엣지 클래스
edge_class = type(class_name, (EdgeModel,), {
    "__doc__": description,
    "__annotations__": {attr_name: Optional[str]},
})
```

- 예약어 안전 변환: `name` → `entity_name`, `uuid` → `entity_uuid`
- 엣지에 `EntityEdgeSourceTarget(source, target)` 방향 매핑

### 그래프 데이터 구조

```python
{
  "graph_id": str,
  "nodes": [{
      "uuid": str,
      "name": str,
      "labels": ["Entity", "Professor"],  # 온톨로지 타입 = 두 번째 라벨
      "summary": str,                     # Zep 자동 생성 요약
      "attributes": {},
      "created_at": str
  }],
  "edges": [{
      "uuid": str,
      "name": "ADVISES",                  # 관계 타입명
      "fact": "교수 A가 학생 B를 지도한다",  # Zep 추출 사실
      "fact_type": str,
      "source_node_uuid": str,
      "target_node_uuid": str,
      "source_node_name": str,            # node_map 역참조
      "target_node_name": str,
      "created_at": str,
      "valid_at": str,                    # 시간축: 유효 시작
      "invalid_at": str,                  # 시간축: 유효 종료
      "expired_at": str,                  # 시간축: 만료
      "episodes": []                      # 출처 에피소드 ID
  }]
}
```

## ZepEntityReader

위치: `backend/app/services/zep_entity_reader.py`

### 필터링 로직

```python
for node in all_nodes:
    custom_labels = [l for l in labels if l not in ["Entity", "Node"]]
    if not custom_labels:
        continue  # 온톨로지에 매칭 안 된 노드 → 스킵
```

- `labels`가 `["Entity"]`만 있는 노드 = Zep가 추출했지만 온톨로지 타입에 안 맞는 엔티티 → 필터링
- Edge Enrichment: 엔티티별 관련 엣지를 in-memory 조인 (direction, edge_name, fact 포함)
- 재시도: 최대 3회, 지수 백오프 (2s → 4s → 8s)

### 출력: FilteredEntities

```python
EntityNode:
    uuid, name, labels, summary, attributes
    related_edges: [{direction, edge_name, fact, target/source_node_uuid}]
    related_nodes: [{uuid, name, labels, summary}]

FilteredEntities:
    entities: List[EntityNode]
    entity_types: Set[str]
    total_count / filtered_count
```

## ZepToolsService — 그래프 검색 도구

위치: `backend/app/services/zep_tools.py`

Report Agent가 그래프를 검색하는 3가지 전략:

### InsightForge (깊은 시맨틱 검색)

```
사용자 질문
    → LLM이 3-5개 서브 질문 자동 생성
    → 각 서브 질문으로 Zep 시맨틱 검색
    → 결과 종합: semantic_facts + entity_insights + relationship_chains
```

반환: `InsightForgeResult`
- `sub_queries`: 자동 생성된 서브 질문
- `semantic_facts`: 시맨틱 매칭된 사실 목록
- `entity_insights`: 관련 엔티티 (이름/타입/요약/관련사실)
- `relationship_chains`: 관계 체인 설명

### PanoramaSearch (광역 BFS)

```
Zep 시맨틱 검색 → 전체 결과 (만료된 엣지 포함)
    → active_facts (현재 유효)
    → historical_facts (과거/만료)
    → 시간축 정보 (valid_at, invalid_at, expired_at)
```

반환: `PanoramaResult`
- 핵심 차별점: `expired_at` 있는 엣지 포함 → 시간 경과에 따른 변화 추적

### QuickSearch (단순 검색)

반환: `SearchResult` — facts, edges, nodes

## ZepGraphMemoryUpdater — 실시간 그래프 업데이트

위치: `backend/app/services/zep_graph_memory_updater.py`

시뮬레이션 중 에이전트 행동을 자연어로 변환하여 그래프에 실시간 반영:

```
actions.jsonl 파싱
    → AgentActivity 생성 (DO_NOTHING 스킵)
    → Queue → daemon worker thread
        → 플랫폼별 버퍼 (twitter/reddit)
        → BATCH_SIZE=5 도달 → 자연어 텍스트 합본
        → Zep.graph.add(type="text", data=combined_text)
```

### 자연어 변환 예시

| 액션 | 변환 결과 |
|------|----------|
| CREATE_POST | `"Alice: 发布了一条帖子：「내용」"` |
| LIKE_POST | `"Alice: 点赞了Bob的帖子：「내용」"` |
| REPOST | `"Alice: 转发了Bob的帖子：「내용」"` |
| CREATE_COMMENT | `"Alice: 在Bob的帖子下评论道：「댓글」"` |
| FOLLOW | `"Alice: 关注了用户「Bob」"` |
| MUTE | `"Alice: 屏蔽了用户「Bob」"` |

`action_args`에서 원본 콘텐츠와 작성자명을 최대한 포함 → Zep가 새 관계를 추출할 수 있도록 함.

## Decepticon 적용 시사점

MiroFish 그래프 시스템의 핵심 패턴:

1. **온톨로지 기반 동적 스키마** → 런타임에 도메인 특화 그래프 구조 정의
2. **텍스트 → 자동 엔티티/관계 추출** → Zep가 비정형 텍스트에서 구조화된 지식 추출
3. **실시간 그래프 업데이트** → 이벤트 스트림을 자연어로 변환하여 그래프 갱신
4. **다층 검색 전략** → 깊은 검색(InsightForge) + 넓은 검색(Panorama) + 빠른 검색(Quick)
5. **시간축 추적** → valid_at/invalid_at/expired_at으로 사실의 유효기간 관리
