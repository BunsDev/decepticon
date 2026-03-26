# Attack Graph 온톨로지 상세 스펙

> Decepticon 지식 그래프의 구체적인 노드/엣지 스키마와 추론 규칙 정의

## 1. 엔티티 스키마 (Pydantic v2)

```python
from __future__ import annotations

from enum import StrEnum
from pydantic import BaseModel, Field
from datetime import datetime


# ── 상태 열거형 ──

class HostStatus(StrEnum):
    UP = "up"
    DOWN = "down"
    FILTERED = "filtered"
    UNKNOWN = "unknown"


class VulnVerification(StrEnum):
    VERIFIED = "verified"         # 확인됨 (exploit 성공)
    PROBABLE = "probable"         # 높은 확률 (버전 매칭)
    UNTESTED = "untested"         # 미검증
    FALSE_POSITIVE = "false_positive"


class CredentialType(StrEnum):
    PASSWORD = "password"
    HASH_NTLM = "hash_ntlm"
    HASH_NTLMv2 = "hash_ntlmv2"
    SSH_KEY = "ssh_key"
    TOKEN = "token"
    COOKIE = "cookie"
    KERBEROS_TGT = "kerberos_tgt"
    KERBEROS_TGS = "kerberos_tgs"


class PrivilegeLevel(StrEnum):
    ANONYMOUS = "anonymous"
    USER = "user"
    ADMIN = "admin"
    ROOT = "root"
    SYSTEM = "system"
    DOMAIN_USER = "domain_user"
    DOMAIN_ADMIN = "domain_admin"


# ── 엔티티 모델 ──

class EntityBase(BaseModel):
    """모든 엔티티의 기본 클래스"""
    uuid: str
    name: str
    discovered_at: datetime
    discovered_by: str         # objective_id (OBJ-RECON-001 등)
    confidence: float = 1.0    # 0.0~1.0 발견 신뢰도
    source_tool: str = ""      # nmap, nikto, manual, etc.


class Host(EntityBase):
    ip_address: str
    hostname: str = ""
    os_fingerprint: str = ""
    status: HostStatus = HostStatus.UNKNOWN
    mac_address: str = ""


class Service(EntityBase):
    port: int
    protocol: str = "tcp"      # tcp|udp
    service_name: str = ""     # http, ssh, smb, ldap, etc.
    version: str = ""
    banner: str = ""
    state: str = "open"        # open|closed|filtered


class WebApplication(EntityBase):
    url: str
    technology: str = ""       # WordPress 6.4, Django 4.2, etc.
    auth_type: str = "none"    # none|basic|form|oauth|cookie
    endpoints: list[str] = Field(default_factory=list)


class Domain(EntityBase):
    fqdn: str
    registrar: str = ""
    nameservers: list[str] = Field(default_factory=list)
    dns_records: dict[str, list[str]] = Field(default_factory=dict)  # A, AAAA, MX, NS, TXT


class Vulnerability(EntityBase):
    cve_id: str = ""                          # CVE-2024-XXXX 또는 빈 문자열 (0-day/misconfig)
    cvss_score: float = 0.0
    vuln_type: str = ""                       # rce|sqli|xss|ssrf|lfi|misconfig|default-cred|info-leak
    description: str = ""
    exploit_available: bool = False
    exploit_reference: str = ""               # exploit-db, metasploit module, PoC URL
    verification: VulnVerification = VulnVerification.UNTESTED
    remediation: str = ""


class Technique(EntityBase):
    technique_id: str                         # T1059.001
    technique_name: str = ""                  # Command and Scripting Interpreter: PowerShell
    tactic: str = ""                          # initial-access|execution|persistence|...
    sub_technique: str = ""
    platforms: list[str] = Field(default_factory=list)  # linux|windows|macos|network
    data_sources: list[str] = Field(default_factory=list)


class Credential(EntityBase):
    cred_type: CredentialType
    username: str
    value_hash: str = ""      # 실제 값이 아닌 해시 (보안)
    privilege_level: PrivilegeLevel = PrivilegeLevel.USER
    valid: bool = True
    expires_at: datetime | None = None


class User(EntityBase):
    username: str
    domain: str = ""
    privilege_level: PrivilegeLevel = PrivilegeLevel.USER
    groups: list[str] = Field(default_factory=list)  # Domain Admins, etc.
    active: bool = True


class NetworkSegment(EntityBase):
    cidr: str                  # 10.0.1.0/24
    segment_name: str = ""     # DMZ, Internal, Management
    vlan_id: int | None = None


class Asset(EntityBase):
    """폴백 엔티티"""
    asset_type: str
    description: str = ""
```

## 2. 엣지 스키마

```python
class EdgeBase(BaseModel):
    """모든 엣지의 기본 클래스"""
    uuid: str
    edge_type: str             # HOSTS_SERVICE, HAS_VULNERABILITY, etc.
    source_uuid: str
    target_uuid: str
    fact: str                  # 자연어 설명 ("호스트 10.0.1.5가 SSH:22를 실행 중")
    discovered_at: datetime
    discovered_by: str         # objective_id
    confidence: float = 1.0

    # 시간축 (MiroFish 패턴)
    valid_at: datetime | None = None      # 관계 유효 시작
    invalid_at: datetime | None = None    # 관계 유효 종료
    expired_at: datetime | None = None    # 관계 만료 (불가역)

    # 추론 메타데이터
    inferred: bool = False     # LLM 추론으로 생성된 관계인지
    source_evidence: str = ""  # 근거 (tool output snippet)


# ── 구체적 엣지 타입 ──

class HostsService(EdgeBase):
    """Host --HOSTS_SERVICE--> Service"""
    edge_type: str = "HOSTS_SERVICE"


class ResolvesTo(EdgeBase):
    """Domain --RESOLVES_TO--> Host"""
    edge_type: str = "RESOLVES_TO"
    record_type: str = "A"     # A, AAAA, CNAME


class BelongsToSegment(EdgeBase):
    """Host --BELONGS_TO_SEGMENT--> NetworkSegment"""
    edge_type: str = "BELONGS_TO_SEGMENT"


class ServesApp(EdgeBase):
    """Service --SERVES_APP--> WebApplication"""
    edge_type: str = "SERVES_APP"


class HasVulnerability(EdgeBase):
    """Service|WebApp|Host --HAS_VULNERABILITY--> Vulnerability"""
    edge_type: str = "HAS_VULNERABILITY"


class ExploitedBy(EdgeBase):
    """Vulnerability --EXPLOITED_BY--> Technique"""
    edge_type: str = "EXPLOITED_BY"
    success_probability: float = 0.5  # 예상 성공 확률


class EnablesAccess(EdgeBase):
    """Technique --ENABLES_ACCESS--> Credential|Host"""
    edge_type: str = "ENABLES_ACCESS"
    access_level: PrivilegeLevel = PrivilegeLevel.USER


class AuthenticatesTo(EdgeBase):
    """Credential --AUTHENTICATES_TO--> Service|Host"""
    edge_type: str = "AUTHENTICATES_TO"


class OwnedBy(EdgeBase):
    """Credential --OWNED_BY--> User"""
    edge_type: str = "OWNED_BY"


class HasAccess(EdgeBase):
    """User --HAS_ACCESS--> Host|Service"""
    edge_type: str = "HAS_ACCESS"
    access_method: str = ""  # ssh|rdp|smb|web|local


class CanReach(EdgeBase):
    """Host --CAN_REACH--> Host (네트워크 도달 가능)"""
    edge_type: str = "CAN_REACH"
    port_range: str = ""      # "22,80,443" 또는 "1-65535"
    firewall_rules: str = ""  # allow|deny|filtered


class LateralMoveTo(EdgeBase):
    """Host --LATERAL_MOVE_TO--> Host (확인된 횡적 이동)"""
    edge_type: str = "LATERAL_MOVE_TO"
    method: str = ""          # psexec, wmi, ssh, pass-the-hash, etc.
    privilege_used: PrivilegeLevel = PrivilegeLevel.USER
```

## 3. 추론 규칙 (Inference Rules)

그래프에 명시적으로 없는 관계를 LLM + 규칙으로 추론:

### 3.1 횡적 이동 가능성 추론

```
IF Host_A --HOSTS_SERVICE--> Service(SMB:445)
   AND Host_B --HOSTS_SERVICE--> Service(SMB:445)
   AND Host_A --BELONGS_TO_SEGMENT--> Segment_X
   AND Host_B --BELONGS_TO_SEGMENT--> Segment_X
   AND Credential(admin) --AUTHENTICATES_TO--> Host_A
THEN
   INFER Host_A --CAN_REACH{confidence=0.7}--> Host_B
   SUGGEST Technique(T1021.002, SMB/Windows Admin Shares)
```

### 3.2 권한 상승 추론

```
IF Host --HOSTS_SERVICE--> Service(version=X)
   AND CVE_DB.lookup(Service.name, version=X) → CVE-YYYY-ZZZZ(type=privilege-escalation)
THEN
   INFER Service --HAS_VULNERABILITY{verification=probable, confidence=0.6}--> Vulnerability(CVE-YYYY-ZZZZ)
   INFER Vulnerability --EXPLOITED_BY--> Technique(mapped from CVE)
```

### 3.3 크레덴셜 재사용 추론

```
IF Credential(username=X, cred_type=password) --AUTHENTICATES_TO--> Service_A
   AND Service_B(same_protocol) exists on another Host
   AND NO explicit AuthenticatesTo edge from Credential to Service_B
THEN
   INFER Credential --AUTHENTICATES_TO{confidence=0.4, inferred=true}--> Service_B
   NOTE "Password reuse hypothesis — needs verification"
```

### 3.4 킬 체인 완성도 추론

```
FOR EACH kill_chain_phase:
    COUNT entities and edges in that phase
    CALCULATE phase_completeness = discovered / expected
    IF phase_completeness < 0.3:
        SUGGEST "Phase {phase} needs more reconnaissance"
    IF previous_phase_completeness > 0.7 AND current_phase_completeness < 0.1:
        SUGGEST "Ready to advance to {phase}"
```

## 4. MITRE ATT&CK 매핑

### 그래프 내 Technique 노드와 ATT&CK 프레임워크 연동

```python
# 발견된 취약점 → ATT&CK 기법 자동 매핑
VULN_TO_TECHNIQUE_MAP = {
    "rce":           ["T1059", "T1203"],          # Execution
    "sqli":          ["T1190", "T1059.004"],       # Initial Access, Unix Shell
    "ssrf":          ["T1190", "T1071.001"],       # Initial Access, Web Protocols
    "default-cred":  ["T1078", "T1110.001"],       # Valid Accounts, Brute Force
    "misconfig":     ["T1574", "T1068"],           # Hijack Execution Flow, Priv Esc
    "lfi":           ["T1005", "T1083"],           # Data from Local System, File Discovery
    "info-leak":     ["T1087", "T1069"],           # Account Discovery, Permission Groups
}

# Tactic 단계별 우선순위
TACTIC_PRIORITY = [
    "reconnaissance",      # TA0043
    "initial-access",      # TA0001
    "execution",           # TA0002
    "persistence",         # TA0003
    "privilege-escalation",# TA0004
    "defense-evasion",     # TA0005
    "credential-access",   # TA0006
    "discovery",           # TA0007
    "lateral-movement",    # TA0008
    "collection",          # TA0009
    "exfiltration",        # TA0010
    "impact",              # TA0040
]
```

## 5. 그래프 쿼리 인터페이스

에이전트가 사용할 쿼리 도구 API:

```python
class AttackGraphQuery:
    """에이전트에 제공되는 그래프 쿼리 도구"""

    def find_attack_paths(
        self,
        from_entity: str,        # 시작 엔티티 UUID 또는 이름
        to_goal: str,            # 목표 (host UUID, "domain-admin", "data-exfil")
        max_depth: int = 6,
        only_verified: bool = False
    ) -> list[AttackPath]:
        """BFS/DFS로 공격 경로 탐색"""

    def get_exploitable_vulns(
        self,
        scope: list[str] = None,  # 범위 내 호스트 UUID 목록
        min_cvss: float = 0.0,
        verified_only: bool = False
    ) -> list[VulnChain]:
        """공격 가능한 취약점 + 기법 체인 조회"""

    def suggest_next_action(
        self,
        current_host: str,        # 현재 위치
        current_privilege: str,   # 현재 권한
        objective: str            # 목표
    ) -> list[ActionSuggestion]:
        """현재 상태에서 가능한 다음 액션 제안"""

    def get_asset_summary(
        self,
        entity_type: str = None,  # Host, Service, Vulnerability 등 필터
        segment: str = None       # 네트워크 세그먼트 필터
    ) -> AssetSummary:
        """findings.md 대체 — 구조화된 자산 요약"""

    def get_timeline(
        self,
        entity_uuid: str = None,  # 특정 엔티티 이력 (None이면 전체)
        since: datetime = None
    ) -> list[TimelineEvent]:
        """시간순 이벤트 이력"""
```
