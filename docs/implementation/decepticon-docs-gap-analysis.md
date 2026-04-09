# decepticon-docs 갭 분석

> `/home/catow/GIT/decepticon-docs/` 기존 문서 vs 새 비전/연구 결과 비교 분석
> 
> 목적: 기존 Mintlify 문서 사이트에 추가/수정해야 할 내용 식별

## 1. 기존 문서 구조

```
decepticon-docs/
  en/
    introduction/
      overview.mdx              — "Offensive Vaccine" 첫 언급, 동기
      history-and-evolution.mdx — 프로젝트 역사
      pentesting-vs-redteaming.mdx — 방법론 차이
    vision/
      autonomous-hacking.mdx    — Vibe→Autonomous 진화, 3단계 비전
      core-philosophy.mdx       — Reasoning, Hybrid Intel, Vaccine, HITL, Stealth
      why-open-source.mdx       — 집단 지성, Red/Blue 커뮤니티
      target-architecture.mdx   — 리팩터링 방향 (현재 한계 → 목표)
    architecture/
      infrastructure.mdx        — 2중 Docker 네트워크 (mgmt/sandbox)
      agents.mdx                — 5개 전문 에이전트
    features/
      autonomous-execution.mdx  — Kill chain 오케스트레이션
      c2-integration.mdx        — Sliver C2
      engagement-planning.mdx   — RoE, ConOps, OPPLAN
      skill-system.mdx          — MITRE ATT&CK 스킬
      multi-model-routing.mdx   — LiteLLM 멀티모델
    getting-started/            — 설치, 설정
    contributing/               — 개발 환경, 기여 가이드
    cli-reference.mdx           — CLI 명령어
  ko/                           — 한국어 미러
```

## 2. 갭 분석 요약

### 2.1 이미 존재하고 잘 작성된 내용 ✅

| 기존 문서 | 내용 | 상태 |
|----------|------|------|
| `overview.mdx` | "Offensive Vaccine" 동기, 기본 개념 | ✅ 잘 작성됨 |
| `core-philosophy.mdx` | Reasoning, Hybrid Intelligence, HITL, Stealth | ✅ 잘 작성됨 |
| `autonomous-hacking.mdx` | Vibe→Autonomous 진화, 3단계 비전 | ✅ 잘 작성됨 |
| `why-open-source.mdx` | 집단 지성, Red/Blue 커뮤니티 | ✅ 잘 작성됨 |
| `infrastructure.mdx` | 2중 Docker 네트워크 격리 | ✅ 잘 작성됨 |
| `agents.mdx` | 5개 에이전트 (Decepticon, Soundwave, Recon, Exploit, PostExploit) | ✅ 잘 작성됨 |
| `autonomous-execution.mdx` | Kill chain 순차 실행 루프 | ✅ 잘 작성됨 |
| `engagement-planning.mdx` | RoE, ConOps, OPPLAN | ✅ 잘 작성됨 |

### 2.2 수정이 필요한 기존 문서 🔄

| 기존 문서 | 현재 | 수정 필요 |
|----------|------|----------|
| `target-architecture.mdx` | Phase 1-5 로드맵 (리팩터링 관점) | **RedGate, Defensive Agents, Hardening Loop 추가 필요** |
| `core-philosophy.mdx` | "Offensive Vaccine" 3줄 요약 | **상세 Vaccine 모델 추가** (Finding→Remediation→Immunity) |
| `autonomous-hacking.mdx` | Step 2/3이 추상적 | **구체적 Feedback Pipeline, Defense Agent 연결** |
| `agents.mdx` | 공격형 5개만 | **방어형 에이전트 (WAF, Patch, Config, Detection) 추가** |
| `infrastructure.mdx` | Docker 네트워크만 | **RedGate WS 서버, Discord 채널 추가** |
| `autonomous-execution.mdx` | 순차 실행만 | **병렬 AgentPool, Steer, 24/7 Cron 추가** |

### 2.3 신규 추가가 필요한 문서 ➕

| 신규 문서 | 위치 | 내용 |
|----------|------|------|
| **`offensive-vaccine-deep.mdx`** | `vision/` | Offensive Vaccine 심층 (백신 비유, Finding→Immunity 라이프사이클, 수렴 모델) |
| **`redgate.mdx`** | `architecture/` | RedGate 제어 평면 (WS JSON-RPC, Auth, Config reload) |
| **`defensive-agents.mdx`** | `architecture/` | 방어형 에이전트 (WAF/Patch/Config/Detection) |
| **`feedback-pipeline.mdx`** | `features/` | Finding → Analysis → Remediation → Verification |
| **`hardening-loop.mdx`** | `features/` | Continuous Hardening Ralph Loop, 수렴 메트릭 |
| **`discord-integration.mdx`** | `features/` | Discord 채널 통합, 운영자 인터페이스 |
| **`scheduling.mdx`** | `features/` | Cron 스케줄링, Night Window, 24/7 운용 |
| **`convergence-metrics.mdx`** | `features/` | 면역률, 수렴 그래프, 보고서 |
| **`plan-adapters.mdx`** | `architecture/` | Universal Ralph Loop + PlanAdapter 패턴 |

## 3. 상세 갭 분석

### 3.1 `target-architecture.mdx` — 대폭 수정 필요

**현재 내용**:
- 현재 한계 (Monolithic, Limited State)
- Stealth-First 실행
- Multi-Agent Hybrid Architecture
- Human in the Loop
- Phase 1-5 로드맵

**누락된 내용** (우리 비전 문서에서):

```diff
+ ## RedGate Control Plane
+   WS JSON-RPC 서버, Discord 채널 통합, Config hot-reload
+   (현재: LangGraph Dev Server만 존재)

+ ## Defensive Agent Lane
+   WAF Agent, Patch Agent, Config Agent, Detection Agent
+   (현재: 공격형만 언급)

+ ## Feedback Pipeline
+   Finding → RemediationAction 자동 변환
+   (현재: "Infinite Feedback" 추상적 언급만)

+ ## Continuous Hardening Loop
+   AttackDefensePlanAdapter, 수렴 메트릭
+   (현재: 순차 실행 루프만)

+ ## AgentPool (Parallel Execution)
+   병렬 sandbox, 동시 에이전트 실행
+   (현재: "한번에 하나" 순차만)

+ ## Scheduling & 24/7
+   APScheduler cron, Night Window
+   (현재: 수동 시작만)

기존 Phase 1-5 → 새 Phase 0-5로 업데이트:
  Phase 0: Current (공격형 에이전트)  ← 현재 여기
  Phase 1: RedGate + Discord
  Phase 2: AgentPool + 병렬화
  Phase 3: Feedback Pipeline + Defensive Agents
  Phase 4: Continuous Hardening Loop
  Phase 5: Ecosystem (커뮤니티 모듈)
```

### 3.2 `core-philosophy.mdx` — Vaccine 섹션 강화

**현재**: "The Offensive Vaccine" 섹션이 3개 bullet로 간략 설명

**추가 필요**:

```diff
현재:
  1. Infinite Feedback Loop
  2. Realistic Threat Simulation
  3. Measurable Evolution

추가:
+ 4. Attack-Defense Closed Loop
+    공격 → 발견 → 방어 → 검증이 하나의 시스템 안에서 자동화
+
+ 5. Convergence Model
+    반복할수록 발견되는 취약점이 줄어들고 면역률이 높아짐
+    "Every attack makes us stronger."
+
+ 6. Real Defense Actions
+    보고서가 아닌 실제 패치, 실제 WAF 규칙, 실제 탐지 규칙
+
+ ## Finding → Immunity Lifecycle
+    Discovery → Analysis → Remediation → Verification → Immunity
+    (offensive-vaccine.md의 Section 3.1 참조)
```

### 3.3 `autonomous-hacking.mdx` — Step 2/3 구체화

**현재**:
```
Step 1: Autonomous Offensive Agent ← We are here
Step 2: Infinite Offensive Feedback (추상적)
Step 3: Defensive Evolution (추상적)
```

**수정 필요**:
```diff
  Step 2: Infinite Offensive Feedback
-   Deploy the agent to generate continuous, diverse attack scenarios
+   Deploy the agent with Continuous Hardening Loop:
+   - Ralph Loop Engine drives autonomous iteration
+   - APScheduler cron for 24/7 scheduling
+   - Night Window operation (22:00-06:00)
+   - Finding extraction from tool outputs (nuclei, nmap, sqlmap)
+   - Knowledge Graph accumulation

  Step 3: Defensive Evolution
-   Channel that feedback into Blue Team capabilities
+   Defensive Agent Lane executes real remediation:
+   - WAF Agent: ModSecurity/Cloudflare 규칙 자동 추가
+   - Patch Agent: 코드 패치 생성 → PR → CI
+   - Config Agent: 서버 설정 강화 (Ansible)
+   - Detection Agent: Sigma 규칙 → SIEM 배포
+   - Verification: 재공격으로 면역 확인
```

### 3.4 `agents.mdx` — 방어형 에이전트 추가

**현재**: Decepticon, Soundwave, Recon, Exploit, PostExploit (5개)

**추가 필요**:
```diff
+ ## Defensive Agents (Phase 3)
+
+ <CardGroup cols={2}>
+   <Card title="WAF Agent" icon="shield">
+     WAF 규칙 자동 관리. ModSecurity/Cloudflare/AWS WAF에 Finding 기반
+     차단 규칙 추가. Monitor → Block 2단계 적용.
+   </Card>
+   <Card title="Patch Agent" icon="wrench">
+     LLM 기반 코드 패치 자동 생성. Finding의 root cause를 분석하여
+     최소 변경 패치 생성 → PR → CI. 인간 승인 후 배포.
+   </Card>
+   <Card title="Config Agent" icon="settings">
+     서버/서비스 설정 강화. Ansible playbook 생성 + 실행.
+     nginx, SSH, DB 설정 하드닝.
+   </Card>
+   <Card title="Detection Agent" icon="eye">
+     탐지 규칙 자동 생성. Finding에서 Sigma 규칙 생성 →
+     Splunk/ElasticSIEM 자동 배포.
+   </Card>
+ </CardGroup>
+
+ ## Additional Offensive Agents
+
+ <CardGroup cols={2}>
+   <Card title="Cloud Hunter" icon="cloud">
+     클라우드 환경 특화 공격. AWS/Azure/GCP IAM, S3, Lambda.
+   </Card>
+   <Card title="AD Operator" icon="network">
+     Active Directory 특화. Kerberos, ADCS, BloodHound.
+   </Card>
+   <Card title="Analyst" icon="microscope">
+     소스 코드 취약점 분석, CVE 연구.
+   </Card>
+   <Card title="Reverser" icon="cpu">
+     바이너리 역공학. Ghidra, radare2.
+   </Card>
+ </CardGroup>
```

### 3.5 `infrastructure.mdx` — RedGate 추가

**현재**: 2중 Docker 네트워크 (decepticon-net + sandbox-net)

**추가 필요**:
```diff
+ ## RedGate Control Plane
+
+ RedGate는 OpenClaw Gateway 패턴을 적용한 WebSocket 제어 평면입니다.
+ 기존 LangGraph Dev Server를 대체하며, Discord/CLI/Web에서 접근 가능합니다.
+
+ ```
+ ┌─────────────────────────────────────┐
+ │        decepticon-net (mgmt)        │
+ │                                     │
+ │  ┌─────────────┐ ┌──────────────┐  │
+ │  │  RedGate    │ │ LiteLLM Proxy│  │
+ │  │  (WS+HTTP)  │ │              │  │
+ │  │  :18789     │ │  :4000       │  │
+ │  └──────┬──────┘ └──────────────┘  │
+ │         │                           │
+ │  ┌──────┴──────┐ ┌──────────────┐  │
+ │  │ Discord Bot │ │  Database    │  │
+ │  │             │ │  (SQLite)    │  │
+ │  └─────────────┘ └──────────────┘  │
+ └─────────────────────────────────────┘
+ ```
+
+ ### Discord Channel Integration
+ - #engagement-control — 인게이지먼트 관리
+ - #attack-log — 공격 진행 상황
+ - #defense-log — 방어 적용 상황
+ - #alerts — CRITICAL/HIGH 즉시 알림
+ - #approvals — 방어 액션 승인 대기
+ - #reports — 수렴 보고서
```

### 3.6 `autonomous-execution.mdx` — 병렬화 + Cron 추가

**현재**: Kill chain 순차 실행 (Select → Build → Spawn → Execute → Parse → Iterate)

**추가 필요**:
```diff
+ ## Parallel Agent Execution
+
+ AgentPool을 통해 독립 목표를 동시에 실행:
+ - SandboxPool: 최대 N개 Docker Kali 동시 운용
+ - Session isolation: 목표별 독립 세션 키
+ - Steer: 실행 중 에이전트에 메시지 주입 (방향 전환)
+
+ ## Scheduled Execution (24/7)
+
+ APScheduler 기반 cron으로 자율 실행:
+ - 야간 전체 사이클 (22:00-06:00)
+ - 6시간마다 정찰 스캔
+ - 주간 수렴 보고서
+ - Night Window: 허용 시간대 자동 관리
+
+ ## Continuous Hardening Loop
+
+ Attack → Finding → Defense → Verify → Repeat
+ 수렴할 때까지 무한 반복.
```

## 4. docs.json 네비게이션 변경안

```jsonc
// docs.json navigation 수정안
{
  "group": "Vision & Philosophy",
  "pages": [
    "en/vision/autonomous-hacking",
    "en/vision/core-philosophy",
    "en/vision/offensive-vaccine-deep",  // ← 신규
    "en/vision/why-open-source",
    "en/vision/target-architecture"
  ]
},
{
  "group": "Features",
  "pages": [
    "en/features/engagement-planning",
    "en/features/autonomous-execution",
    "en/features/hardening-loop",         // ← 신규
    "en/features/feedback-pipeline",      // ← 신규
    "en/features/discord-integration",    // ← 신규
    "en/features/scheduling",             // ← 신규
    "en/features/convergence-metrics",    // ← 신규
    "en/features/c2-integration",
    "en/features/skill-system",
    "en/features/multi-model-routing"
  ]
},
{
  "group": "Architecture",
  "pages": [
    "en/architecture/infrastructure",
    "en/architecture/redgate",            // ← 신규
    "en/architecture/agents",
    "en/architecture/defensive-agents",   // ← 신규
    "en/architecture/plan-adapters"       // ← 신규
  ]
}
```

## 5. 우선순위별 작업 목록

### P0: 비전 일관성 (즉시)

| 작업 | 유형 | 영향 |
|------|------|------|
| `target-architecture.mdx` 전면 업데이트 | 수정 | Phase 로드맵이 현재 비전과 불일치 |
| `core-philosophy.mdx` Vaccine 섹션 확장 | 수정 | 핵심 철학 누락 |
| `autonomous-hacking.mdx` Step 2/3 구체화 | 수정 | 비전 실현 경로 불명확 |

### P1: 아키텍처 반영 (1주)

| 작업 | 유형 | 영향 |
|------|------|------|
| `offensive-vaccine-deep.mdx` 신규 | 추가 | Vaccine 모델 심층 설명 |
| `agents.mdx` 방어형 에이전트 추가 | 수정 | 에이전트 아키텍처 불완전 |
| `infrastructure.mdx` RedGate 추가 | 수정 | 인프라 아키텍처 불완전 |
| `redgate.mdx` 신규 | 추가 | 제어 평면 문서화 |
| `defensive-agents.mdx` 신규 | 추가 | 방어 에이전트 문서화 |

### P2: 기능 문서화 (2주)

| 작업 | 유형 | 영향 |
|------|------|------|
| `hardening-loop.mdx` 신규 | 추가 | 핵심 기능 문서 |
| `feedback-pipeline.mdx` 신규 | 추가 | Finding→Defense 파이프라인 |
| `discord-integration.mdx` 신규 | 추가 | 채널 통합 |
| `scheduling.mdx` 신규 | 추가 | 24/7 운용 |
| `convergence-metrics.mdx` 신규 | 추가 | 수렴 측정 |
| `autonomous-execution.mdx` 병렬화 추가 | 수정 | 현재 순차만 |
| `plan-adapters.mdx` 신규 | 추가 | 확장성 아키텍처 |

### P3: 한국어 미러 (3주)

모든 신규/수정 문서의 한국어 버전 `ko/` 디렉토리에 생성

## 6. 기존 문서의 강점 (보존해야 할 것)

기존 문서에서 매우 잘 작성된 부분 — **절대 삭제하면 안됨**:

1. **"Reasoning Over Signatures"** (core-philosophy.mdx) — 서명 기반 → 추론 기반 전환 설명이 탁월
2. **"Hybrid Intelligence"** — AI가 전략가, 도구가 전문가 — 균형 잡힌 설명
3. **"Stealth as Foundation"** — 레드팀의 본질(탐지 테스트)을 정확히 짚음
4. **"From Vibe Hacking to Autonomous Hacking"** — 브랜딩 진화 스토리
5. **"Pentesting vs Red Teaming"** — 방법론 차이 명확히 설명
6. **인프라 다이어그램** — decepticon-net / sandbox-net 분리 설명
7. **Interactive Shell Sessions** — tmux 기반 도구 조작의 차별점
8. **3단계 비전** (Step 1→2→3) — 골격은 유지, 내용만 구체화

## 7. 문서 작성 참조 소스

| 수정/추가 대상 | 참조할 우리 문서 (decepticon_new/docs/) |
|-------------|--------------------------------------|
| `target-architecture.mdx` | `implementation/redgate-control-plane.md`, `implementation/hardening-loop-engine.md` |
| `core-philosophy.mdx` | `vision/offensive-vaccine.md` (Section 1, 9) |
| `autonomous-hacking.mdx` | `vision/offensive-vaccine.md` (Section 3, 4) |
| `agents.mdx` | `vision/attack-defense-architecture.md` (Section 3) |
| `infrastructure.mdx` | `implementation/redgate-control-plane.md` (Section 2, 5) |
| `autonomous-execution.mdx` | `implementation/agent-pool-defense.md` (Section 1) |
| `offensive-vaccine-deep.mdx` (신규) | `vision/offensive-vaccine.md` (전체) |
| `redgate.mdx` (신규) | `implementation/redgate-control-plane.md` |
| `defensive-agents.mdx` (신규) | `implementation/agent-pool-defense.md` (Section 3) |
| `hardening-loop.mdx` (신규) | `vision/continuous-hardening-loop.md`, `implementation/hardening-loop-engine.md` |
| `feedback-pipeline.mdx` (신규) | `implementation/agent-pool-defense.md` (Section 2) |
| `discord-integration.mdx` (신규) | `implementation/redgate-control-plane.md` (Section 5) |
| `scheduling.mdx` (신규) | `implementation/hardening-loop-engine.md` (Section 3) |
| `convergence-metrics.mdx` (신규) | `implementation/hardening-loop-engine.md` (Section 5) |
| `plan-adapters.mdx` (신규) | `openclaw-analysis/universal-ralph-loop.md` (Section 3) |
