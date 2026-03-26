# MiroFish 온톨로지 시스템

## 개요

MiroFish는 LLM을 사용하여 입력 문서와 시뮬레이션 요구사항으로부터 **도메인 특화 온톨로지**를 자동 생성한다.
생성된 온톨로지는 그래프 스키마, 에이전트 프로필, 시뮬레이션 설정의 기반이 된다.

## 핵심: `OntologyGenerator`

위치: `backend/app/services/ontology_generator.py`

### 입력

```python
generate(
    document_texts: List[str],      # 문서 텍스트 목록
    simulation_requirement: str,     # 시뮬레이션 요구사항
    additional_context: str = None   # 추가 컨텍스트
) → Dict[str, Any]                  # 온톨로지 JSON
```

### 출력 스키마

```json
{
  "entity_types": [
    {
      "name": "Professor",
      "description": "University faculty member with research focus",
      "attributes": [
        {"name": "research_field", "type": "text", "description": "연구 분야"}
      ],
      "examples": ["김교수", "이교수"]
    }
  ],
  "edge_types": [
    {
      "name": "ADVISES",
      "description": "Advisory relationship between faculty and students",
      "source_targets": [{"source": "Professor", "target": "Student"}],
      "attributes": []
    }
  ],
  "analysis_summary": "분석 요약 텍스트"
}
```

## 설계 규칙

### 엔티티 타입 규칙
- **정확히 10개**: 8개 도메인 특화 + 2개 폴백 (`Person`, `Organization`)
- **실체만 허용**: 소셜 미디어에서 발언 가능한 주체
  - 허용: 개인, 회사, 조직, 정부기관, 미디어, 플랫폼
  - 금지: 추상 개념 ("여론"), 주제 ("학술 윤리"), 태도 ("지지파")
- **PascalCase** 명명

### 엣지 타입 규칙
- **6~10개**
- **UPPER_SNAKE_CASE** 명명
- `source_targets`로 허용 방향 명시

### 속성 규칙
- 엔티티당 1~3개
- **예약어 금지**: `name`, `uuid`, `group_id`, `created_at`, `summary` (Zep 내부 필드)
- 대체: `full_name`, `org_name`, `entity_name` 등

## 시스템 프롬프트 구조 (155줄)

```
[역할]         지식 그래프 온톨로지 설계 전문가
[배경]         소셜 미디어 여론 시뮬레이션 시스템
[엔티티 기준]  허용 목록 (7종) + 금지 목록 (3종)
[출력 형식]    JSON 스키마 + 예시
[설계 가이드]  10개 규칙, 계층 구조, 폴백 타입 필수
[참조]         개인류 8종, 조직류 7종, 관계류 12종 예시
```

## 후처리 (`_validate_and_process`)

```python
1. 필수 필드 보장 → entity_types, edge_types, analysis_summary 빈 값 채움
2. description 100자 제한 → 초과 시 97자 + "..."
3. 폴백 타입 강제:
   - Person / Organization 미존재 → 끝에 추가
   - 10개 초과 시 → 기존 타입을 뒤에서 제거 (앞쪽 = 중요)
4. Zep API 제한 → entity_types ≤ 10, edge_types ≤ 10
```

## 텍스트 제한

```python
MAX_TEXT_LENGTH_FOR_LLM = 50000  # 5만 자
# 온톨로지 생성용 LLM 입력만 제한, 그래프 구축 시에는 전체 텍스트 사용
```

## Decepticon 적용 시사점

MiroFish의 온톨로지 시스템은 "소셜 미디어 주체" 중심이지만,
Decepticon에서는 **보안 도메인 온톨로지**로 변환 가능:

| MiroFish | Decepticon (보안 도메인) |
|----------|----------------------|
| Person, Organization | Host, Service, User, NetworkSegment |
| Professor, Student | Vulnerability, Exploit, Technique |
| ADVISES, WORKS_FOR | EXPOSES, EXPLOITS, MITIGATES, LATERAL_MOVE |
| 소셜 시뮬레이션 | 공격 경로 추론 / TTP 매핑 |
