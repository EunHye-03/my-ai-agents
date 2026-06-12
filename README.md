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
              ├── APPROVED → Step 4
              └── REJECTED → Engineer 재작업 (최대 3회)
4. QA       → 테스트 케이스·엣지 케이스 검증 → artifacts/test-plan.md
              ├── PASSED  → 완료
              └── FAILED  → Engineer 재작업 → Reviewer 재실행 → QA 재검증 (최대 2회)
```

중단된 작업은 동일한 태스크로 재실행하면 마지막 완료 스텝부터 자동 재개됩니다 (`artifacts/state.md` 기반).

#### 산출물

루프 완료 후 `.agents/artifacts/`에 저장됩니다:

| 파일 | 작성자 | 내용 |
|------|--------|------|
| `issue.md` | PM | 이슈 제목, 배경, 수용 기준, 범위 밖 항목 |
| `impl.md` | Engineer | 테스트 모드, 변경 파일, 커밋 목록, 핵심 코드 |
| `review.md` | Reviewer | 스펙 커버리지, 항목별 피드백, 최종 판정 |
| `test-plan.md` | QA | 테스트 케이스, 엣지 케이스, 이슈 목록, 최종 판정 |
| `state.md` | Orchestrator | 현재 진행 스텝, 타임스탬프, 상태 (재개 지원용) |

> `artifacts/`는 `.gitignore`에 자동 등록됩니다.

#### tmux 조작

**pane 이동 및 뷰**

| 키 | 동작 |
|----|------|
| `Ctrl-b` + 화살표 | pane 이동 |
| `Ctrl-b` + `z` | 현재 pane 전체화면 전환 (다시 누르면 복귀) |
| `Ctrl-b` + `[` | 스크롤 모드 — PgUp/PgDn으로 이전 출력 확인, `q`로 종료 |
| `Ctrl-b` + `d` | 세션 detach (백그라운드 유지) |
| `tmux attach -t dev-loop` | detach 후 재접속 |

**실행 중 개입**

각 pane은 독립된 셸이라 이동 후 직접 타이핑할 수 있습니다.

| 상황 | 방법 |
|------|------|
| 에이전트 출력 자세히 보기 | 해당 pane으로 이동 → `Ctrl-b z` 확대 |
| 실행 중인 에이전트 중단 | 해당 pane으로 이동 → `Ctrl-c` |
| 프롬프트 수정 후 단계 재실행 | `/tmp/<role>-prompt.txt` 편집 후 해당 pane에서 `bash /tmp/agent-step-N.sh` |

**blocked 상태 수동 재개**

Orchestrator가 `❌ 수동 개입 필요`를 출력하면:

```bash
# 1. 실패 원인 확인
cat .agents/artifacts/review.md      # 리뷰 반려 내용
cat .agents/artifacts/test-plan.md   # QA 실패 내용

# 2. 필요하면 코드 직접 수정

# 3. 동일 태스크명으로 재실행 → state.md 읽어 마지막 완료 스텝부터 재개
bash .agents/scripts/start-dev-loop.sh "같은 기능명"
```

---

### 동작 원리

멀티 터미널 루프는 세 가지 메커니즘의 조합으로 작동합니다.

#### 1. tmux pane = 에이전트 터미널

`start-dev-loop.sh`가 tmux 세션을 만들고 4분할합니다. 각 pane은 독립적인 셸이고, Orchestrator가 다른 pane에 명령을 원격 전송합니다.

```
pane 0 → PM
pane 1 → Engineer
pane 2 → Reviewer / QA  ← QA 단계에서 Reviewer pane 재사용
pane 3 → Orchestrator   ← orchestrator.sh 실행 위치
```

`tmux send-keys -t dev-loop:0.1 "bash /tmp/agent-step-1.sh" Enter`
— Orchestrator가 Engineer pane에 스크립트 실행을 주입하는 방식입니다.

#### 2. claude -p = 비대화형 단발 호출

각 에이전트는 `claude -p "<프롬프트>"`로 실행됩니다. 대화 없이 즉시 응답을 stdout으로 반환하는 모드입니다.

```bash
# agent-step-N.sh 내부 구조
claude -p "$(cat /tmp/engineer-prompt.txt)" | tee .agents/artifacts/impl.md
_exit=${PIPESTATUS[0]}   # 파이프라인에서 claude의 exit code만 추출
```

`PIPESTATUS[0]`을 쓰는 이유: `| tee`가 항상 0을 반환하므로, claude 자체의 성공/실패를 알려면 파이프라인 앞쪽 exit code를 따로 캡처해야 합니다.

#### 3. 마커 파일 폴링 = 에이전트 간 동기화

에이전트끼리 직접 통신하지 않습니다. Orchestrator가 완료 여부를 파일로 감지합니다.

```
에이전트 성공 → touch .agents/artifacts/.eng-done
에이전트 실패 → touch .agents/artifacts/.eng-done.error

Orchestrator: while [[ ! -f .done && ! -f .error ]]; do sleep 2; done
```

타임아웃은 10분. 실패 마커가 생기면 해당 pane 출력을 직접 확인해야 합니다.

#### 4. 프롬프트 조립

각 에이전트의 프롬프트는 세 부분을 합쳐 `/tmp/<role>-prompt.txt`에 씁니다:

```
[페르소나]     agents.md에서 @tag 섹션을 awk로 추출
    +
[이전 산출물]  cat artifacts/issue.md, impl.md, review.md ...
    +
[출력 형식]    마크다운 템플릿 + 마지막 줄 판정문 강제
```

판정문(`REVIEW: APPROVED / REJECTED`, `QA: PASSED / FAILED`)은 `grep -q`로 감지합니다. 이 한 줄이 루프의 분기 조건입니다.

#### 5. 재개 흐름 (state.md)

```
state.md 없음       → 처음부터 실행
status=in_progress  → saved_step + 1 부터 재개
status=blocked      → saved_step 부터 재시도 (수동 개입 후 재실행)
status=done         → 새 태스크로 초기화
```

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
