# Decepticon 지식 그래프 기반 추론 엔진 설계

> MiroFish의 온톨로지/그래프/검색 패턴을 Decepticon의 보안 도메인에 적용하여,
> 취약점 추론 탐색과 공격 TTP를 지식 그래프에서 추론하는 엔진 설계안.

## 1. 현재 Decepticon 아키텍처와 한계

### 현재 지식 관리 방식

```
findings.md          ← 비정형 마크다운, append-only
lessons_learned.md   ← 실패 기록, 비정형
opplan.json          ← 목표 리스트, 구조화되었으나 관계 없음
```

### 한계

| 한계 | 설명 |
|------|------|
| **관계 추론 불가** | "호스트 A의 서비스 B에서 발견한 취약점 C를 이용해 호스트 D로 이동 가능"과 같은 관계 추론 불가 |
| **공격 경로 탐색 불가** | 발견된 자산 간의 경로 탐색이 불가, 에이전트가 findings.md를 텍스트로 읽어 추론해야 함 |
| **시간축 부재** | 크레덴셜 만료, 세션 종료, 패치 적용 등 시간에 따른 유효성 추적 불가 |
| **컨텍스트 폭발** | 발견사항이 늘어나면 findings.md가 거대해져 에이전트 컨텍스트 소모 |
| **교차 목표 지식 단절** | 목표별 에이전트가 독립 컨텍스트로 실행, 이전 목표의 발견을 구조적으로 활용 불가 |

## 2. 목표: 그래프 기반 추론 엔진

```
┌──────────────────────────────────────────────────────────────┐
│                    Decepticon 추론 엔진                        │
│                                                              │
│  findings.md ──→ 엔티티/관계 추출 ──→ ┌─────────────────┐   │
│  tool output ──→ (LLM 기반)       ──→ │  Attack Graph   │   │
│  nmap/nikto  ──→                  ──→ │  (지식 그래프)    │   │
│                                       └────────┬────────┘   │
│                                                │             │
│                    ┌───────────────────────────┘             │
│                    ▼                                         │
│  ┌─────────────────────────────────────────────────────┐    │
│  │             그래프 추론 도구                           │    │
│  │  attack_path_query()  ← 공격 경로 탐색              │    │
│  │  vuln_chain_query()   ← 취약점 체인 추론            │    │
│  │  ttp_suggest()        ← MITRE ATT&CK TTP 제안      │    │
│  │  lateral_move_map()   ← 횡적 이동 경로 탐색         │    │
│  │  asset_timeline()     ← 자산별 시간축 이력          │    │
│  └─────────────────────────────────────────────────────┘    │
│                    │                                         │
│                    ▼                                         │
│  Orchestrator가 다음 목표 선정 시 그래프 쿼리 활용           │
│  Sub-Agent가 실행 시 관련 엔티티/관계를 컨텍스트로 주입      │
└──────────────────────────────────────────────────────────────┘
```

## 3. 보안 도메인 온톨로지

### 3.1 엔티티 타입

MiroFish의 "10개 엔티티 타입" 패턴을 보안 도메인에 적용:

```yaml
entity_types:
  # ── 인프라 자산 ──
  - name: Host
    description: "Physical or virtual machine with an IP address"
    attributes:
      - {name: ip_address, type: text}
      - {name: hostname, type: text}
      - {name: os_fingerprint, type: text}
      - {name: status, type: text}  # up|down|filtered

  - name: Service
    description: "Network service running on a host (port + protocol)"
    attributes:
      - {name: port, type: text}
      - {name: protocol, type: text}
      - {name: version, type: text}
      - {name: banner, type: text}

  - name: WebApplication
    description: "HTTP/HTTPS web application with endpoints"
    attributes:
      - {name: url, type: text}
      - {name: technology, type: text}  # WordPress, Django, etc.
      - {name: auth_type, type: text}   # none|basic|oauth|cookie

  - name: Domain
    description: "DNS domain or subdomain"
    attributes:
      - {name: fqdn, type: text}
      - {name: registrar, type: text}
      - {name: dns_records, type: text}

  # ── 취약점/공격 ──
  - name: Vulnerability
    description: "Known or discovered security weakness (CVE, misconfig, logic flaw)"
    attributes:
      - {name: cve_id, type: text}
      - {name: cvss_score, type: text}
      - {name: vuln_type, type: text}    # rce|sqli|xss|ssrf|lfi|misconfig|default-cred
      - {name: exploit_available, type: text}
      - {name: verified, type: text}     # true|false|untested

  - name: Technique
    description: "MITRE ATT&CK technique or sub-technique"
    attributes:
      - {name: technique_id, type: text}  # T1059.001
      - {name: tactic, type: text}        # initial-access|execution|persistence|...
      - {name: platform, type: text}      # linux|windows|macos|network

  # ── 인증/접근 ──
  - name: Credential
    description: "Authentication material (password, key, token, hash)"
    attributes:
      - {name: cred_type, type: text}  # password|hash|ssh-key|token|cookie
      - {name: username, type: text}
      - {name: privilege_level, type: text}  # user|admin|root|domain-admin

  - name: User
    description: "System or application user account"
    attributes:
      - {name: username, type: text}
      - {name: privilege_level, type: text}
      - {name: domain, type: text}

  # ── 폴백 ──
  - name: NetworkSegment
    description: "Logical network segment or VLAN"
    attributes:
      - {name: cidr, type: text}
      - {name: segment_name, type: text}

  - name: Asset
    description: "Generic asset not fitting other types (fallback)"
    attributes:
      - {name: asset_type, type: text}
      - {name: description, type: text}
```

### 3.2 엣지 타입 (관계)

```yaml
edge_types:
  # ── 인프라 관계 ──
  - name: HOSTS_SERVICE
    description: "Host runs a network service"
    source_targets: [{source: Host, target: Service}]

  - name: RESOLVES_TO
    description: "Domain resolves to IP/Host"
    source_targets: [{source: Domain, target: Host}]

  - name: BELONGS_TO_SEGMENT
    description: "Host belongs to network segment"
    source_targets: [{source: Host, target: NetworkSegment}]

  - name: SERVES_APP
    description: "Service serves a web application"
    source_targets: [{source: Service, target: WebApplication}]

  # ── 취약점/공격 관계 ──
  - name: HAS_VULNERABILITY
    description: "Service or application has a vulnerability"
    source_targets:
      - {source: Service, target: Vulnerability}
      - {source: WebApplication, target: Vulnerability}
      - {source: Host, target: Vulnerability}

  - name: EXPLOITED_BY
    description: "Vulnerability can be exploited by a technique"
    source_targets: [{source: Vulnerability, target: Technique}]

  - name: ENABLES_ACCESS
    description: "Exploitation grants access to a credential or host"
    source_targets:
      - {source: Technique, target: Credential}
      - {source: Technique, target: Host}

  # ── 인증/접근 관계 ──
  - name: AUTHENTICATES_TO
    description: "Credential authenticates to a service or host"
    source_targets:
      - {source: Credential, target: Service}
      - {source: Credential, target: Host}

  - name: OWNED_BY
    description: "Credential belongs to a user"
    source_targets: [{source: Credential, target: User}]

  - name: HAS_ACCESS
    description: "User has access to a host or service"
    source_targets:
      - {source: User, target: Host}
      - {source: User, target: Service}

  # ── 횡적 이동 ──
  - name: CAN_REACH
    description: "Network reachability between hosts/segments"
    source_targets:
      - {source: Host, target: Host}
      - {source: NetworkSegment, target: NetworkSegment}

  - name: LATERAL_MOVE_TO
    description: "Confirmed lateral movement path"
    source_targets: [{source: Host, target: Host}]
```

### 3.3 시간축 속성

MiroFish의 `valid_at`/`invalid_at`/`expired_at` 패턴 적용:

```python
# 모든 엣지에 시간축 추가
{
    "fact": "SSH 서비스(22/tcp)에서 기본 크레덴셜로 접근 가능",
    "valid_at": "2024-01-15T10:30:00",    # 발견 시점
    "invalid_at": None,                     # 아직 유효
    "expired_at": None,                     # 만료 안 됨

    # 세션이 끊기면:
    "invalid_at": "2024-01-15T14:00:00",   # 세션 종료 시점
}
```

활용:
- **유효한 크레덴셜만 쿼리**: `WHERE expired_at IS NULL`
- **공격 타임라인 재구성**: 엣지의 시간 순서대로 정렬
- **세션 관리**: 접근 유효기간 추적

## 4. 공격 경로 추론 (Attack Path Reasoning)

### 4.1 그래프 기반 공격 경로 탐색

```
[문제] 초기 접근점에서 목표 자산까지의 공격 경로 찾기

[그래프 쿼리]
Entry Point (Discovered Credential)
    → AUTHENTICATES_TO → Service (SSH:22)
        → HOSTS_SERVICE ← Host (10.0.1.5)
            → CAN_REACH → Host (10.0.2.10, DC)
                → HOSTS_SERVICE → Service (LDAP:389)
                    → HAS_VULNERABILITY → Vuln (CVE-2024-XXXX)
                        → EXPLOITED_BY → Technique (T1210)
                            → ENABLES_ACCESS → Credential (Domain Admin)
```

### 4.2 LLM + 그래프 추론 통합

MiroFish의 InsightForge 패턴을 보안 도메인에 적용:

```python
class AttackPathReasoner:
    """그래프 기반 공격 경로 추론"""

    def find_attack_paths(self, source_entity: str, target_goal: str) -> list:
        """
        source_entity: 시작점 (발견한 크레덴셜, 취약점 등)
        target_goal: 목표 (domain-admin, data-exfil, persistence 등)

        1. LLM이 서브 질문 생성:
           - "이 크레덴셜로 접근 가능한 호스트는?"
           - "해당 호스트에서 도달 가능한 네트워크 세그먼트는?"
           - "목표 세그먼트의 알려진 취약점은?"
        2. 각 서브 질문으로 그래프 시맨틱 검색
        3. BFS/DFS로 경로 탐색
        4. 경로별 리스크 점수 계산
        """

    def suggest_next_technique(self, current_position: str) -> list:
        """
        현재 위치 (호스트/서비스/권한)에서 가능한 다음 기법 제안

        1. 현재 노드의 이웃 엣지 조회
        2. HAS_VULNERABILITY → EXPLOITED_BY 체인 탐색
        3. CAN_REACH → 다른 호스트 도달 가능 여부
        4. MITRE ATT&CK 매핑으로 TTP 제안
        """
```

### 4.3 TTP 추론 체인

```
[발견된 사실]
  Host:10.0.1.5 --HOSTS_SERVICE--> Service:SMB:445
  Service:SMB:445 --HAS_VULNERABILITY--> Vuln:EternalBlue(MS17-010)

[TTP 추론]
  Vuln:EternalBlue --EXPLOITED_BY--> Technique:T1210(Exploitation of Remote Services)
  Technique:T1210 --ENABLES_ACCESS--> Host:10.0.1.5(SYSTEM)

[연쇄 추론]
  Host:10.0.1.5(SYSTEM) --CAN_REACH--> Host:10.0.2.10(DC)
  → Technique:T1003.001(LSASS Memory) → Credential:DomainAdmin
  → Technique:T1021.002(SMB/Windows Admin Shares) → Host:10.0.2.10
```

## 5. 통합 포인트: Decepticon 파이프라인에 그래프 삽입

### 5.1 Finding 추출 → 그래프 업데이트 (MiroFish의 ZepGraphMemoryUpdater 패턴)

```
Sub-Agent 실행 완료
    ↓
[기존] findings.md에 텍스트 append
    ↓
[신규] GraphUpdater가 finding 파싱:
    - nmap 결과 → Host, Service, Port 엔티티 + HOSTS_SERVICE 관계
    - nikto 결과 → Vulnerability 엔티티 + HAS_VULNERABILITY 관계
    - credential dump → Credential, User 엔티티 + OWNED_BY, AUTHENTICATES_TO 관계
    - 횡적 이동 성공 → LATERAL_MOVE_TO 관계 (시간축 포함)
    ↓
Attack Graph 업데이트
```

### 5.2 Orchestrator 의사결정 강화

```
[기존 Ralph 루프]
1. opplan.json 읽기 → next_objective()
2. findings.md 읽기 → 텍스트 컨텍스트

[강화된 Ralph 루프]
1. opplan.json 읽기 → next_objective()
2. Attack Graph 쿼리:
   - "현재 접근 가능한 자산은?" → 유효한 AUTHENTICATES_TO 관계
   - "목표까지 최단 공격 경로는?" → BFS 경로 탐색
   - "가장 높은 성공 확률의 기법은?" → 취약점-기법 매핑
3. 그래프 쿼리 결과를 에이전트 컨텍스트에 주입
4. 목표가 BLOCKED일 때 → 대안 경로 자동 탐색
```

### 5.3 Sub-Agent 컨텍스트 주입

```python
# 현재: findings.md 전체를 텍스트로 전달
context = read_file("findings.md")

# 개선: 그래프 쿼리로 관련 엔티티만 선별 전달
relevant = graph.query("""
    현재 목표: {objective.title}
    관련 호스트: {hosts in scope}
    발견된 취약점: {vulns on those hosts}
    사용 가능한 크레덴셜: {valid credentials}
    권장 기법: {techniques mapped to vulns}
""")
```

**컨텍스트 절약 효과**: findings.md 전체 (수천 줄) 대신, 현재 목표에 관련된 엔티티/관계만 구조화하여 전달.

### 5.4 킬 체인 분석 스킬 강화

```
[기존] skills/decepticon/kill-chain-analysis/SKILL.md
    - findings.md를 텍스트로 읽고 분석

[강화]
    - 그래프에서 킬 체인 phase별 엔티티/관계 집계
    - 각 phase의 completeness 평가:
      Recon: 발견된 Host/Service/Domain 수
      Exploitation: Vulnerability→Technique 매핑 완료 여부
      Post-Exploit: Credential→Host 접근 체인 존재 여부
    - 공격 경로 시각화 (그래프 서브셋)
```

## 6. 구현 전략

### Phase 1: 로컬 그래프 엔진 (Zep 대체)

Decepticon은 Docker sandbox 내에서 동작하므로, **SaaS 의존 없는 로컬 그래프** 필요:

| 옵션 | 장단점 |
|------|--------|
| **NetworkX (인메모리)** | 가장 단순, Python 네이티브, 영속화는 JSON, 소규모 적합 |
| **Neo4j (컨테이너)** | 강력한 Cypher 쿼리, 시각화, 오버헤드 큼 |
| **Graphiti (Zep 오픈소스)** | MiroFish와 가장 유사한 API, Neo4j 기반 |
| **JSON 파일 그래프** | 가장 경량, Decepticon의 파일 기반 패턴과 일치 |

**권장: Phase 1은 NetworkX + JSON 영속화, Phase 2에서 Graphiti/Neo4j 고려**

### Phase 2: LLM 기반 엔티티 추출

MiroFish의 `OntologyGenerator` → `GraphBuilder` 패턴을 보안 도메인에 적용:

```python
class SecurityEntityExtractor:
    """보안 도구 출력에서 엔티티/관계 추출"""

    EXTRACTION_PROMPT = """
    다음 보안 도구 출력에서 엔티티와 관계를 추출하세요.

    엔티티 타입: Host, Service, Vulnerability, Credential, User, ...
    관계 타입: HOSTS_SERVICE, HAS_VULNERABILITY, AUTHENTICATES_TO, ...

    출력 형식: JSON
    """

    def extract_from_nmap(self, nmap_output: str) -> dict: ...
    def extract_from_nikto(self, nikto_output: str) -> dict: ...
    def extract_from_cred_dump(self, output: str) -> dict: ...
    def extract_generic(self, tool_output: str) -> dict: ...  # LLM 폴백
```

### Phase 3: 그래프 검색 도구 (에이전트 도구)

```python
# 에이전트에 제공할 그래프 검색 도구
tools = [
    attack_path_query,    # 공격 경로 탐색
    vuln_chain_query,     # 취약점 체인 추론
    ttp_suggest,          # MITRE TTP 제안
    lateral_move_map,     # 횡적 이동 경로
    asset_summary,        # 자산 요약 (findings.md 대체)
    asset_timeline,       # 자산별 시간축 이력
]
```

## 7. MiroFish 패턴 → Decepticon 매핑 요약

| MiroFish 패턴 | Decepticon 적용 |
|---------------|----------------|
| OntologyGenerator (LLM → 온톨로지) | SecurityOntology (보안 도메인 고정 스키마) |
| GraphBuilder (Zep SaaS) | AttackGraphBuilder (NetworkX 로컬) |
| ZepEntityReader (노드 필터링) | AssetReader (타입별 자산 필터링) |
| ZepToolsService.InsightForge (깊은 검색) | AttackPathReasoner (공격 경로 추론) |
| ZepToolsService.PanoramaSearch (광역 BFS) | LateralMoveMapper (횡적 이동 탐색) |
| ZepGraphMemoryUpdater (실시간 업데이트) | FindingsGraphUpdater (도구 출력 → 그래프) |
| SimulationConfigGenerator (LLM → 설정) | TTPSuggestor (그래프 → 기법 추천) |
| ReportAgent (ReACT → 리포트) | EngagementReporter (그래프 기반 리포트) |
| 시간축 (valid_at/expired_at) | 세션 유효성, 크레덴셜 만료, 패치 추적 |
