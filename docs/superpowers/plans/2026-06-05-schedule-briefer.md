# schedule-briefer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `.claude/agents/schedule-briefer.md` 파일 하나를 작성해, 9개 소스에서 데이터를 수집하고 Slack DM 또는 터미널로 일간 브리핑을 전달하는 Claude Code 서브에이전트를 만든다.

**Architecture:** 단일 에이전트 파일(마크다운 시스템 프롬프트). 각 소스는 독립적으로 수집되며, 실패해도 나머지 섹션은 계속 진행된다. args에 `--slack`이 포함되면 Slack DM 전송, 없으면 터미널 출력.

**Tech Stack:** Claude Code agents, icalBuddy CLI, Notion MCP, Gmail MCP, Slack MCP, WebFetch, Bash, Read

**Spec:** `docs/superpowers/specs/2026-06-05-schedule-briefer-design.md`

---

## File Structure

```
.claude/agents/schedule-briefer.md    ← 생성 (유일한 파일)
```

---

## Task 1: 기본 파일 구조 + 캘린더 섹션

**Files:**
- Create: `.claude/agents/schedule-briefer.md`

- [ ] **Step 1: 에이전트 파일 생성 (frontmatter + 뼈대)**

`.claude/agents/schedule-briefer.md` 파일을 아래 내용으로 생성:

```markdown
---
name: schedule-briefer
description: 하루 브리핑을 생성하는 에이전트. "브리핑해줘", "오늘 브리핑", "브리핑" 등으로 트리거. args에 --slack 포함 시 Slack DM으로 전송, 없으면 터미널 출력.
---

# schedule-briefer

여러 소스에서 정보를 수집해 오늘 하루 브리핑을 생성한다.

**Announce at start:** "schedule-briefer로 오늘 브리핑을 수집하겠습니다."

## 실행 원칙

- 각 소스는 독립적으로 수집한다. 하나 실패해도 나머지는 계속 진행한다.
- 소스 수집 실패 시 해당 섹션에 `⚠️ [소스명] 데이터 수집 실패` 를 출력한다.
- 모든 섹션 수집 완료 후 브리핑을 조립해 출력한다.
- args에 `--slack` 이 포함되면 Slack DM으로 전송, 없으면 터미널에 출력한다.

---

## 1단계: 날짜 확인

오늘 날짜와 요일을 확인한다.

```bash
date '+%Y-%m-%d (%a)'
```

결과를 `TODAY` 변수로 기억한다.

---

## 2단계: Apple Calendar 수집

icalBuddy를 절대 경로로 실행한다. PATH 문제를 방지하기 위해 반드시 절대 경로 사용.

```bash
/opt/homebrew/bin/icalBuddy -n -b "•" -df "%H:%M" eventsToday+1
```

- 출력이 비어있으면: `📅 일정\n- (없음)`
- 명령 실패(파일 없음, 권한 오류 등)이면: `📅 일정\n⚠️ icalBuddy 실행 실패 (Calendar 권한 확인 필요)`
- 성공 시 오늘/내일 일정을 `📅 일정` 섹션으로 포맷
```

- [ ] **Step 2: 에이전트 호출해서 캘린더 섹션 확인**

Claude Code에서 실행:
```
/schedule-briefer
```

Expected: `📅 일정` 섹션이 나타남. 일정이 있으면 목록, 없으면 `(없음)`.

icalBuddy가 없으면: `⚠️ icalBuddy 실행 실패` 메시지 확인.

- [ ] **Step 3: icalBuddy 없는 경우 에러 처리 확인**

터미널에서:
```bash
/opt/homebrew/bin/icalBuddy -n -b "•" -df "%H:%M" eventsToday+1
```

- 정상 출력되면 OK
- `command not found` 이면: `brew install icalbuddy` 로 설치 후 재확인

- [ ] **Step 4: 커밋**

```bash
git add .claude/agents/schedule-briefer.md
git commit -m "feat: add schedule-briefer agent with calendar section"
```

---

## Task 2: Notion 할 일 섹션 (P0/P1/P2 + 마감 추출)

**Files:**
- Modify: `.claude/agents/schedule-briefer.md`

- [ ] **Step 1: Notion 섹션 추가**

`## 2단계: Apple Calendar 수집` 블록 다음에 아래 내용 추가:

```markdown
---

## 3단계: Notion 할 일 수집

Notion MCP로 할 일 페이지를 조회한다.

페이지 ID: `002a894f-a829-83e9-b954-014816e6fa18`

`notion-fetch` 툴로 해당 페이지를 가져온 뒤 미완료(체크박스 unchecked) 항목을 추출한다.

**우선순위 분류 (이모지 기반):**
- ‼️ 포함 항목 → P0
- ❗️ 포함 항목 → P1
- ❕ 포함 항목 → P2
- 이모지 없는 항목 → P1 (기본값)

**마감 추출:** 항목명에 `(MM/DD)`, `(YYYY-MM-DD)`, `~MM/DD` 형태가 있으면 마감일로 추출.

수집 결과를 NOTION_TASKS 변수로 저장:
- P0 목록, P1 목록, P2 목록 (각각 항목명 + 마감일)
- 이 데이터는 위험도 계산과 "지금 가장 중요한 한 가지" 섹션에 사용됨

- MCP 호출 실패 시: NOTION_TASKS = 에러 상태로 기록
- 응답은 왔으나 미완료 항목이 0건이면: NOTION_TASKS = 0건 상태로 기록 (경고 출력)
- 성공 시: P0/P1/P2로 분류된 항목 목록
```

- [ ] **Step 2: 에이전트 호출해서 Notion 섹션 확인**

```
/schedule-briefer
```

Expected:
- Notion에 미완료 항목이 있으면 P0/P1/P2로 분류돼 출력됨
- 항목이 없으면 `⚠️ 할 일 0건 (Notion 직접 확인 권장)` 출력
- MCP 연결 불가 시 `⚠️ Notion 데이터 수집 실패` 출력

- [ ] **Step 3: 커밋**

```bash
git add .claude/agents/schedule-briefer.md
git commit -m "feat: add Notion todos section with P0/P1/P2 priority to schedule-briefer"
```

---

## Task 3: Gmail 섹션

**Files:**
- Modify: `.claude/agents/schedule-briefer.md`

- [ ] **Step 1: Gmail 섹션 추가**

Notion 섹션 다음에 추가:

```markdown
---

## 4단계: Gmail 수집

Gmail MCP로 오늘 미읽음 메일을 조회한다.

`search_threads` 툴을 사용. 쿼리: `is:unread newer_than:1d`

**주의:** `label:important` 쿼리는 사용하지 않는다. Gmail의 "중요" 레이블은 ML 기반으로 신뢰할 수 없다.

- MCP 호출 실패 시: `📬 이메일\n⚠️ Gmail 데이터 수집 실패`
- 결과가 없으면: `📬 이메일\n- (미읽음 없음)`
- 결과가 있으면: 건수와 함께 발신자·제목 목록 출력 (최대 5건)

포맷:
```
📬 이메일 (미읽음 N건)
- 발신자: 제목 요약
- 발신자: 제목 요약
```
```

- [ ] **Step 2: 에이전트 호출해서 Gmail 섹션 확인**

```
/schedule-briefer
```

Expected: `📬 이메일` 섹션이 나타남. 미읽음 메일 목록 또는 `(미읽음 없음)`.

- [ ] **Step 3: 커밋**

```bash
git add .claude/agents/schedule-briefer.md
git commit -m "feat: add Gmail section to schedule-briefer"
```

---

## Task 4: Slack 섹션

**Files:**
- Modify: `.claude/agents/schedule-briefer.md`

- [ ] **Step 1: Slack 섹션 추가**

Gmail 섹션 다음에 추가:

```markdown
---

## 5단계: Slack 수집

Slack MCP로 미읽음 메시지를 조회한다.

`slack_search_public_and_private` 툴을 사용. 쿼리: `is:unread`

- MCP 호출 실패 시: `💬 Slack\n⚠️ Slack 데이터 수집 실패`
- 결과가 없으면: `💬 Slack\n- (미읽음 없음)`
- 결과가 있으면: 채널별로 최신 메시지 요약 출력 (최대 5건)

포맷:
```
💬 Slack
- #채널명: 메시지 요약
- @DM발신자: 메시지 요약
```
```

- [ ] **Step 2: 에이전트 호출해서 Slack 섹션 확인**

```
/schedule-briefer
```

Expected: `💬 Slack` 섹션이 나타남.

- [ ] **Step 3: 커밋**

```bash
git add .claude/agents/schedule-briefer.md
git commit -m "feat: add Slack section to schedule-briefer"
```

---

## Task 5: KNU 학교 공지 섹션

**Files:**
- Modify: `.claude/agents/schedule-briefer.md`

- [ ] **Step 1: KNU 공지 섹션 추가**

Slack 섹션 다음에 추가:

```markdown
---

## 6단계: 학교 공지 수집

세 URL을 순서대로 WebFetch로 수집한다. 각각 독립적으로 실행해 하나 실패해도 나머지는 진행한다.

### CSE 학과 공지
URL: `https://cse.knu.ac.kr/index.php`
커뮤니티 섹션의 최신 공지 5건을 추출한다.
- HTTP 비정상 응답(404, 리다이렉트, 에러 페이지) 시: `⚠️ CSE 학과 사이트 접근 불가`
- 공지 파싱 실패 시: `⚠️ CSE 공지 파싱 실패`
- 성공 시: 공지 제목 목록

### 소프트웨어교육원 공지
URL: `https://swedu.knu.ac.kr/05_sub/01_sub.html`
최신 공지 3건을 추출한다.
- 실패 시: `⚠️ SW교육원 사이트 접근 불가`

### 경북대 국제처 공지
URL: `https://international.knu.ac.kr/HOME/global/index.htm`
최신 공지 3건을 추출한다.
- 실패 시: `⚠️ 국제처 사이트 접근 불가`

포맷:
```
🏫 학교 공지
- [CSE] 공지 제목
- [SW교육원] 공지 제목
- [국제처] 공지 제목
```

세 소스 모두 실패하면:
```
🏫 학교 공지
⚠️ 학교 사이트 전체 접근 불가 (네트워크 또는 URL 변경 확인)
```
```

- [ ] **Step 2: 에이전트 호출해서 학교 공지 섹션 확인**

```
/schedule-briefer
```

Expected: `🏫 학교 공지` 섹션에 각 기관별 공지 목록 또는 접근 불가 메시지.

- [ ] **Step 3: URL 유효성 직접 확인**

```bash
curl -o /dev/null -s -w "%{http_code}" https://cse.knu.ac.kr/index.php
curl -o /dev/null -s -w "%{http_code}" https://swedu.knu.ac.kr/05_sub/01_sub.html
curl -o /dev/null -s -w "%{http_code}" https://international.knu.ac.kr/HOME/global/index.htm
```

Expected: 세 URL 모두 `200`. 다른 코드면 URL 재확인 필요.

- [ ] **Step 4: 커밋**

```bash
git add .claude/agents/schedule-briefer.md
git commit -m "feat: add KNU notices section to schedule-briefer"
```

---

## Task 6: 프로젝트 현황 섹션

**Files:**
- Modify: `.claude/agents/schedule-briefer.md`

- [ ] **Step 1: 프로젝트 현황 섹션 추가**

학교 공지 섹션 다음에 추가:

```markdown
---

## 7단계: 프로젝트 현황 수집

`~/src/repos/` 하위 디렉토리 중 최근 30일 내 커밋이 있는 레포만 수집한다. 최대 10개 상한.

```bash
# 최근 30일 내 커밋 있는 레포 목록 (최대 10개)
for dir in ~/src/repos/*/; do
  if [ -d "$dir/.git" ]; then
    count=$(git -C "$dir" log --since="30 days ago" --oneline 2>/dev/null | wc -l)
    if [ "$count" -gt 0 ]; then
      echo "$dir"
    fi
  fi
done | head -10
```

각 레포에서 수집:
1. 현재 브랜치: `git -C <path> branch --show-current`
2. 최근 커밋 5개: `git -C <path> log --oneline -5`
3. 미커밋 변경: `git -C <path> status --short`
4. NOTES.md 최근 항목: `<path>/NOTES.md` 파일이 있으면 마지막 `## ` 섹션 내용 읽기

- git 명령 실패 시 해당 레포 건너뜀
- NOTES.md 없으면 NOTES 항목 생략

포맷:
```
💻 프로젝트 현황
- [레포명] branch: 브랜치명
  최근 커밋: 커밋 요약 (N개)
  미커밋: 있음 / 없음
  NOTES: 최근 항목 요약
```

활성 레포가 없으면: `💻 프로젝트 현황\n- (최근 30일 내 활동 없음)`
```

- [ ] **Step 2: 에이전트 호출해서 프로젝트 섹션 확인**

```
/schedule-briefer
```

Expected: `💻 프로젝트 현황`에 최근 활동 레포 목록. `my-ai-agents`는 반드시 포함돼야 함 (방금 커밋했으므로).

- [ ] **Step 3: 커밋**

```bash
git add .claude/agents/schedule-briefer.md
git commit -m "feat: add project status section to schedule-briefer"
```

---

## Task 7: AI 컨텍스트 섹션

**Files:**
- Modify: `.claude/agents/schedule-briefer.md`

- [ ] **Step 1: AI 컨텍스트 섹션 추가**

프로젝트 현황 섹션 다음에 추가:

```markdown
---

## 8단계: AI 컨텍스트 수집

`~/.claude/projects/` 하위에서 최근 수정된 `MEMORY.md` 파일을 최대 3개 읽는다.

```bash
# 최근 수정된 MEMORY.md 파일 3개
ls -t ~/.claude/projects/*/memory/MEMORY.md 2>/dev/null | head -3
```

각 파일을 Read 툴로 읽어 내용을 요약한다.

- 파일이 없으면: `🤖 AI 컨텍스트\n- (메모리 파일 없음)`
- 파일 읽기 실패 시: `🤖 AI 컨텍스트\n⚠️ 메모리 파일 읽기 실패`
- 성공 시: 각 파일의 핵심 항목을 3줄 이내로 요약

포맷:
```
🤖 AI 컨텍스트
- 최근 작업 요약 항목 1
- 최근 작업 요약 항목 2
```
```

- [ ] **Step 2: 에이전트 호출해서 AI 컨텍스트 섹션 확인**

```
/schedule-briefer
```

Expected: `🤖 AI 컨텍스트` 섹션에 현재 대화 세션의 메모리 내용 요약.

- [ ] **Step 3: 메모리 파일 경로 실제 확인**

```bash
ls -t ~/.claude/projects/*/memory/MEMORY.md 2>/dev/null | head -5
```

파일이 없거나 경로가 다르면 에이전트 내 glob 패턴 수정.

- [ ] **Step 4: 커밋**

```bash
git add .claude/agents/schedule-briefer.md
git commit -m "feat: add AI context section to schedule-briefer"
```

---

## Task 8: 브리핑 조립 + 출력 라우팅

**Files:**
- Modify: `.claude/agents/schedule-briefer.md`

- [ ] **Step 1: 위험도 계산 + 브리핑 조립 + 출력 라우팅 섹션 추가**

AI 컨텍스트 섹션 다음에 추가:

```markdown
---

## 9단계: 위험도 계산 및 브리핑 조립

### 위험도 계산

NOTION_TASKS에서 다음 기준으로 위험도를 판정한다:
- 🔴 HIGH: P0 항목이 있고 마감이 오늘이거나 지난 경우; 또는 마감일 없는 P0 항목이 2개 이상
- 🟡 MED: P0 항목이 있고 마감이 내일 이후; 또는 P1 항목 중 마감이 오늘인 경우
- 🟢 LOW: P0 없고 긴급 마감 없음

### 공휴일 확인

오늘 날짜를 대한민국 법정 공휴일 목록과 비교한다. 공휴일이면 HOLIDAY_NAME에 공휴일명을 저장.

### 지금 가장 중요한 한 가지

NOTION_TASKS에서 다음 우선순위로 선택:
1. P0 항목 중 마감이 가장 가까운 것
2. P0가 없으면 P1 중 마감이 가장 가까운 것
3. 마감 정보 없으면 P0 중 첫 번째 항목

### 이번 주 놓치면 안 되는 것

오늘~7일 이내 마감인 항목을 수집:
- NOTION_TASKS 중 마감일이 오늘~7일 이내인 것
- KNU 공지 중 마감 언급이 있는 것

### 추천 행동 생성

수집한 전체 데이터 기반으로 2-3개 행동 생성:
- Gmail 미읽음이 많으면: "미읽음 이메일 N건 — 빠른 확인 필요"
- P0 마감이 오늘이면: "P0 마감 항목 오전 중 처리 권장"
- 미커밋 변경이 있는 레포가 있으면: "미커밋 변경 있음 — 커밋 권장"
- 학교 공지에 마감 언급이 있으면: "학교 공지 마감 확인 필요"

### 브리핑 조립

아래 순서로 조립:

```
🗓️ {TODAY} 브리핑
{HOLIDAY_NAME이 있으면: 🎌 오늘은 {HOLIDAY_NAME}입니다}

{위험도} 현재 위험도: HIGH/MED/LOW
{위험도 이유 한 줄}

🎯 지금 가장 중요한 한 가지
- {작업명} (예상 Xh | 마감까지 D일 / 오늘 마감)

✅ 오늘 할 일
**P0 — 지금 해야 함**
{P0 항목 목록 또는 없으면 생략}

**P1 — 오늘 안에**
{P1 항목 목록}

**P2 — 여유 있으면**
{P2 항목 목록 또는 없으면 생략}

👀 이번 주 놓치면 안 되는 것
{이번 주 마감 항목}

📅 일정
{Calendar 섹션}

📬 이메일 (미읽음 N건)
{Gmail 섹션}

💬 Slack
{Slack 섹션}

🏫 학교 공지
{KNU 섹션}

💻 프로젝트 현황
{Project 섹션}

🤖 AI 컨텍스트
{Memory 섹션}

💡 추천 행동
{추천 행동 목록}
```

### 출력 라우팅

args에 `--slack` 이 포함되어 있으면:
- `slack_send_message` 툴로 나 자신의 DM에 전송
- 전송 후 응답의 `ok` 필드를 확인한다
  - `ok: true` 이면: "✅ Slack 브리핑 전송 완료"를 터미널에 출력
  - `ok: false` 또는 오류 시: "⚠️ Slack 전송 실패 — 브리핑을 터미널에 출력합니다" 출력 후 브리핑을 터미널에 출력

args에 `--slack` 이 없으면:
- 브리핑을 터미널에 직접 출력한다
```

- [ ] **Step 2: 전체 브리핑 수동 테스트 (터미널 출력)**

```
/schedule-briefer
```

Expected: 위험도, 가장 중요한 한 가지, P0/P1/P2 할 일, 이번 주 체크 항목, 일정, 이메일, Slack, 학교 공지, 프로젝트 현황, AI 컨텍스트, 추천 행동이 순서대로 출력됨.

- [ ] **Step 3: Slack 전송 테스트**

```
/schedule-briefer --slack
```

Expected:
- Slack DM에 브리핑 도착
- 터미널에 "✅ Slack 브리핑 전송 완료" 출력

- [ ] **Step 4: 커밋**

```bash
git add .claude/agents/schedule-briefer.md
git commit -m "feat: add briefing assembly with risk level and priority to schedule-briefer"
```

---

## Task 9: /schedule 동작 검증 및 README 업데이트

**Files:**
- Modify: `README.md`

- [ ] **Step 1: /schedule 실행 방식 확인**

`/schedule` 스킬을 실행해 동작 방식 파악:

```
/schedule
```

다음을 확인:
- 원격 실행(Anthropic 서버)인지, 로컬 실행(현재 세션)인지
- 노트북이 꺼져있을 때도 실행되는지

- [ ] **Step 2: 확인 결과에 따른 자동 실행 설정**

**원격 실행으로 확인된 경우:**
- `/schedule`로 매일 아침 8시 `schedule-briefer --slack` 등록
- 단, icalBuddy(로컬 CLI)는 원격에서 실행 불가 → 캘린더 섹션에 `⚠️ 원격 실행 환경에서 icalBuddy 사용 불가` 안내 추가

**로컬 실행으로 확인된 경우:**
- 노트북이 켜져 있어야 동작함을 README에 명시
- `/schedule`로 등록하거나, 수동 실행 방식 안내

- [ ] **Step 3: README.md 업데이트**

`README.md`의 Structure 섹션에 `schedule-briefer` 항목 추가:

```markdown
- `.claude/agents/`
  - schedule-briefer: 일간 브리핑 (캘린더, 할 일, 이메일, Slack, 학교 공지, 프로젝트 현황)
  - blog-writer: 기술 블로그 작성 및 발행
  - weekly-report: 연구실 주간보고서 작성
```

- [ ] **Step 4: 최종 커밋**

```bash
git add .claude/agents/schedule-briefer.md README.md
git commit -m "feat: complete schedule-briefer agent with auto-run setup"
```
