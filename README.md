# Personal AI Developer Agents

Claude 기반 개인 맞춤형 에이전트 & 멀티 에이전트 개발 루프 모음.

## 구조

```
.claude/agents/          # Claude Code 서브에이전트 정의
.agents/                 # Antigravity 멀티에이전트 개발 루프 템플릿
  agents.md              # @pm / @engineer / @reviewer / @qa 페르소나
  workflows/             # /dev-loop, /pr-review 슬래시 커맨드
  scripts/               # 멀티 터미널 자동화 스크립트
  templates/             # 신규 프로젝트 context 초기 파일
scripts/
  init-antigravity.sh    # 신규 프로젝트에 .agents/ 템플릿 초기화
docs/superpowers/        # 설계 문서, 플랜, pre-mortem
```

---

## Claude Code 서브에이전트

`.claude/agents/`에 정의된 에이전트. Claude Code 세션 내에서 자동 위임.

| 에이전트 | 설명 |
|---|---|
| `blog-writer` | PAAR 구조 기술 블로그 → Tistory + GitHub + Obsidian |
| `weekly-report` | 연구실 주간보고서 → 로컬 + Notion |
| `schedule-briefer` | 일간 브리핑 (캘린더, Notion, Gmail, Slack, 학교 공지) |
| `project-notes` | 개발 마일스톤 기록 → `~/Notes/Projects/<ProjectName>/` |
| `pr-writer` | PR 작성 및 `gh pr create` |
| `pr-reviewer` | PR 멀티 페르소나 리뷰 + 재리뷰 |

---

## Antigravity — 멀티 에이전트 개발 루프

### 개요

**Antigravity**는 `@pm / @engineer / @reviewer / @qa` 에이전트가 협업하는 개발 루프 시스템. 두 가지 모드로 실행 가능:

| 모드 | 방식 | 적합한 상황 |
|------|------|------------|
| **Claude Code 세션** | `/dev-loop <기능명>` 슬래시 커맨드 | 대화형, 단계마다 승인 |
| **멀티 터미널** | `bash .agents/scripts/start-dev-loop.sh` | 자동화, 각 에이전트가 독립 터미널에서 실행 |

---

### 신규 프로젝트에 설치

```bash
# my-ai-agents 클론
git clone https://github.com/<you>/my-ai-agents ~/src/repos/my-ai-agents

# 대상 프로젝트에 .agents/ 초기화
cd ~/src/repos/my-project
bash ~/src/repos/my-ai-agents/scripts/init-antigravity.sh

# 프로젝트 컨텍스트 채우기 (필수)
# .agents/context/project.yaml   — 프로젝트 개요, 기술 스택
# .agents/context/domain-rules.md — 도메인 용어, 비즈니스 규칙
# .agents/context/error-codes.yaml — 에러 코드 목록
```

---

### 멀티 터미널 dev loop 실행 가이드

#### 사전 조건

```bash
brew install tmux          # 터미널 분할
brew install claude        # Claude Code CLI
claude login               # 로그인
```

#### 실행

```bash
# 프로젝트 루트에서 실행
cd ~/src/repos/my-project
bash .agents/scripts/start-dev-loop.sh "로그인 기능 구현"
```

실행 즉시 tmux 세션이 열리며 4개 터미널로 분할됩니다:

```
┌────────────────────┬────────────────────┐
│  🔵  PM            │  🟡  Engineer      │
│                    │                    │
│  스펙 작성 중...   │  대기 중...        │
├────────────────────┼────────────────────┤
│  🟢  Reviewer      │  ⚙️  Orchestrator   │
│                    │                    │
│  대기 중...        │  [1/3] PM 실행 중  │
└────────────────────┴────────────────────┘
```

#### 자동 실행 순서

```
1. PM       → 태스크 분석 → artifacts/issue.md (수용 기준, 범위 밖 항목)
2. Engineer → 스펙 읽고 구현 → artifacts/impl.md (코드, 테스트, 커밋 목록)
3. Reviewer → 구현 리뷰 → artifacts/review.md
              ├── APPROVED → 완료
              └── REJECTED → Engineer 재작업 (최대 3회)
```

#### 산출물

루프 완료 후 `.agents/artifacts/`에 저장됩니다:

| 파일 | 작성자 | 내용 |
|------|--------|------|
| `issue.md` | PM | 이슈 제목, 배경, 수용 기준, 범위 밖 항목 |
| `impl.md` | Engineer | 테스트 모드, 변경 파일, 커밋 목록, 핵심 코드 |
| `review.md` | Reviewer | 스펙 커버리지, 항목별 피드백, 최종 판정 |

> `artifacts/`는 `.gitignore`에 자동 등록됩니다.

#### tmux 단축키

| 키 | 동작 |
|----|------|
| `Ctrl-b` + 화살표 | pane 이동 |
| `Ctrl-b` + `z` | 현재 pane 전체화면 전환 |
| `Ctrl-b` + `d` | 세션 detach (백그라운드 유지) |
| `tmux attach -t dev-loop` | detach 후 재접속 |

---

### Claude Code 세션에서 슬래시 커맨드

`.agents/`가 초기화된 프로젝트에서 Claude Code를 열면 사용 가능:

```
/dev-loop <기능명>    전체 개발 루프 (위험 검토 → 스펙 → 구현 → 리뷰 → QA → PR)
/pr-review <PR번호>   PR 멀티 페르소나 리뷰
```

---

### 에이전트 페르소나 요약

`.agents/agents.md`에 상세 정의. 각 에이전트는 다음 역할을 맡습니다:

| 에이전트 | 역할 | 산출물 |
|---------|------|--------|
| `@pm` | 요구사항 분석, 수용 기준 정의, 범위 크리프 방지 | `artifacts/issue.md` |
| `@engineer` | 최소한의 코드로 스펙 구현, TDD/Test-after 선택 | 구현 코드 + 커밋 |
| `@reviewer` | 스펙 커버리지 확인, 코드 품질·보안 리뷰 | `artifacts/review.md` |
| `@qa` | 엣지 케이스 발굴, 테스트 계획 수립 | `artifacts/test-plan.md` |
