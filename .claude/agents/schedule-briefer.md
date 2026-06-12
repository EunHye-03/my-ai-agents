---
name: schedule-briefer
description: 하루 브리핑을 생성하는 에이전트. "브리핑해줘", "오늘 브리핑", "브리핑" 등으로 트리거. args에 --discord 포함 시 Discord #briefing 채널로 전송, 없으면 터미널 출력.
---

# schedule-briefer

여러 소스에서 정보를 수집해 오늘 하루 브리핑을 생성한다.

**Announce at start:** "schedule-briefer로 오늘 브리핑을 수집하겠습니다."

## Local Configuration

실행 전에 `${AGENT_RULES_CONFIG:-$HOME/.config/agent-rules/local-values.env}`의 값을 사용한다. 실제 토큰과 비밀번호는 이 파일에도 저장하지 않고 Keychain 또는 도구 인증을 사용한다. 파일이 없거나 값이 비어 있는 소스는 실패로 처리하지 않고 건너뛴다.

```bash
CONFIG_FILE="${AGENT_RULES_CONFIG:-$HOME/.config/agent-rules/local-values.env}"
[ -f "$CONFIG_FILE" ] && set -a && . "$CONFIG_FILE" && set +a
```

## 실행 원칙

- 각 소스는 독립적으로 수집한다. 하나 실패해도 나머지는 계속 진행한다.
- 소스 수집 실패 시 해당 섹션에 `⚠️ [소스명] 데이터 수집 실패` 를 출력한다.
- 모든 섹션 수집 완료 후 브리핑을 조립해 출력한다.
- args에 `--discord` 이 포함되면 Discord #briefing 채널로 전송, 없으면 터미널에 출력한다.

## 1단계: 날짜 확인

오늘 날짜와 요일을 확인한다.

```bash
date '+%Y-%m-%d (%a)'
```

결과를 TODAY로 기억한다.

## 2단계: Apple Calendar 수집

AppleScript로 오늘~6일 후(7일치) 일정을 가져온다. Calendar 앱을 직접 열지 않아도 동작한다.
중복 제거: 동일한 (날짜, 제목) 조합은 한 번만 출력 (Gmail 캘린더와 로컬 캘린더 중복 방지).

```bash
osascript << 'APPLESCRIPT'
tell application "Calendar"
    -- startOfToday를 초 단위 덧셈으로 계산해 AppleScript date 참조 버그 회피
    set startOfToday to current date
    set hours of startOfToday to 0
    set minutes of startOfToday to 0
    set seconds of startOfToday to 0

    set skipCals to {"생일", "대한민국의 휴일", "Holidays in South Korea", "대한민국 공휴일", "Siri 제안", "예정된 미리 알림"}
    set seen to {}
    set output to ""

    repeat with dayOffset from 0 to 6
        set dayStart to startOfToday + (dayOffset * 24 * 3600)
        set dayEnd to dayStart + (23 * 3600 + 59 * 60 + 59)

        -- 날짜 레이블 결정
        if dayOffset = 0 then
            set dayLabel to "오늘"
        else if dayOffset = 1 then
            set dayLabel to "내일"
        else
            set wd to weekday of dayStart
            if wd = Monday then
                set dayLabel to "월"
            else if wd = Tuesday then
                set dayLabel to "화"
            else if wd = Wednesday then
                set dayLabel to "수"
            else if wd = Thursday then
                set dayLabel to "목"
            else if wd = Friday then
                set dayLabel to "금"
            else if wd = Saturday then
                set dayLabel to "토"
            else
                set dayLabel to "일"
            end if
        end if

        repeat with cal in calendars
            set calName to name of cal
            set skip to false
            repeat with sc in skipCals
                if calName is sc then set skip to true
            end repeat
            if not skip then
                try
                    set dayEvents to (every event of cal whose start date >= dayStart and start date <= dayEnd)
                    repeat with ev in dayEvents
                        set evTitle to summary of ev
                        set dedupKey to (dayOffset as string) & ":" & evTitle
                        if dedupKey is not in seen then
                            set end of seen to dedupKey
                            set evStart to start date of ev
                            set hh to hours of evStart
                            set mm to minutes of evStart
                            if hh = 0 and mm = 0 then
                                set output to output & "[" & dayLabel & "] 종일  " & evTitle & "
"
                            else
                                set output to output & "[" & dayLabel & "] " & (hh as string) & ":" & text -2 thru -1 of ("0" & (mm as string)) & "  " & evTitle & "
"
                            end if
                        end if
                    end repeat
                end try
            end if
        end repeat
    end repeat

    if output is "" then return "(일정 없음)"
    return output
end tell
APPLESCRIPT
```

- 출력이 `(일정 없음)` 이면: `📅 일정\n_일정 없음_` 으로 기록
- 종일 이벤트(HH:MM = 00:00)는 시간 대신 "종일"로 표시
- osascript 실패 시: `📅 일정\n⚠️ Calendar 접근 실패` 로 기록
- 성공 시 `[오늘]`/`[내일]`/`[월~일]` 레이블 + `HH:MM 일정명` 형식으로 포맷 (7일치)

---

## 3단계: Notion 할 일 수집

Notion 개인 통합 API로 Weekly To-Do 페이지를 조회한다. (MCP 아닌 직접 API 호출)

**페이지 구조:**
- `heading_2`: 주차 제목 (예: 📅 Weekly To-do 2026-06-01)
- `bulleted_list_item` (×N): 주간 카테고리별 목표
- `column_list`: 요일별 컬럼 (Monday~Sunday 중 해당 요일만 있음)
  - 각 column: `heading_3` (요일명) + `to_do` 항목들

**1. Keychain에서 토큰 읽기:**

```bash
NOTION_TOKEN=$(security find-generic-password -a "$USER" -s "$NOTION_KEYCHAIN_SERVICE" -w 2>/dev/null)
```

토큰 읽기 실패 시: NOTION_TASKS = {status: "error"} 로 기록 후 다음 단계로 진행.

**2. API 호출 (3단계):**

```bash
# Step 1: 페이지 최상위 블록 — 가장 최근 heading_2 다음의 bullet 목록과 column_list 찾기
curl -s "https://api.notion.com/v1/blocks/${NOTION_TASKS_BLOCK_ID}/children?page_size=50" \
  -H "Authorization: Bearer $NOTION_TOKEN" -H "Notion-Version: 2022-06-28"

# Step 2: column_list 하위 column ID 목록
curl -s "https://api.notion.com/v1/blocks/{column_list_id}/children" \
  -H "Authorization: Bearer $NOTION_TOKEN" -H "Notion-Version: 2022-06-28"

# Step 3: 각 column 하위 블록 (column마다 반복)
curl -s "https://api.notion.com/v1/blocks/{column_id}/children" \
  -H "Authorization: Bearer $NOTION_TOKEN" -H "Notion-Version: 2022-06-28"
```

**3. 파싱 알고리즘:**

```python
from datetime import datetime
import re

DAY_MAP = {
    'Monday': 0, 'Tuesday': 1, 'Wednesday': 2, 'Thursday': 3,
    'Friday': 4, 'Saturday': 5, 'Sunday': 6
}
TODAY_WD = datetime.today().weekday()  # 0=Mon, 6=Sun
TODAY_STR = datetime.today().strftime('%m/%d')

def get_priority(text):
    if '‼️' in text: return 'p0'
    if '❗️' in text or '❗' in text: return 'p1'
    if '🔜' in text: return 'deferred'   # 미룬 것
    if '❕' in text: return 'p2'
    return 'p1'  # 기본값

def clean(text):
    # 우선순위 이모지 제거 후 trim
    return re.sub(r'[‼️❗️❗🔜❕]', '', text).strip()

def extract_due(text):
    m = re.search(r'[~(](\d{1,2}/\d{1,2})[)]?', text)
    return m.group(1) if m else None

# Step 1 결과에서:
# - 첫 번째 heading_2 이후 bulleted_list_item들 → week_categories
# - 이후 첫 번째 column_list ID → 이번 주 컬럼

week_categories = []  # [{"category": "학업 및 과제", "items": ["네프 과제", ...]}, ...]
# heading_2 발견 후 column_list 전까지 bulleted_list_item 파싱:
# bullet text 예: "학업 및 과제: 네프 과제, 운체 과제, 기계론 기말"
# ": " 기준으로 split → category / items

# Step 3 결과에서 각 column:
day_name = heading_3 텍스트  # "Monday", "Tuesday" 등
day_wd = DAY_MAP[day_name]

tasks = {'day': day_name, 'p0': [], 'p1': [], 'p2': [], 'deferred': []}
for block in column_children:
    if block.type == 'to_do' and not block.to_do.checked:
        raw = ''.join(t.plain_text for t in block.to_do.rich_text)
        priority = get_priority(raw)
        name = clean(raw)
        due = extract_due(raw)
        tasks[priority].append({'name': name, 'due': due})

# 요일 기준 분류:
if day_wd == TODAY_WD:
    today_tasks = tasks        # 오늘
elif day_wd > TODAY_WD:
    upcoming.append(tasks)     # 이번 주 남은 날
else:
    if any tasks unchecked:
        overdue.append(tasks)  # 지난 날 미완료
```

**4. 수집 결과 NOTION_TASKS 구조:**

```
{
  "week_categories": [{"category": "학업 및 과제", "items": ["네프 과제", "기계론 기말"]}, ...],
  "today": {"day": "요일명", "p0": [...], "p1": [...], "p2": [...], "deferred": [...]},
  "upcoming": [{"day": "Tuesday", "p0": [], "p1": [...], "deferred": [...]}, ...],
  "overdue": [{"day": "Monday", "p0": [], "p1": [...], "deferred": [...]}],
  "status": "ok" / "error" / "empty"
}
```

각 태스크 항목: `{"name": "텍스트(이모지 제거)", "due": "MM/DD 또는 null"}`

**에러 처리:**
- curl 실패 또는 API 오류: NOTION_TASKS = {status: "error"} → 브리핑 조립 시 `⚠️ Notion 데이터 수집 실패` 출력
- 미완료 항목 0건: NOTION_TASKS = {status: "empty"} → _할 일 없음_ 출력

---

## 4단계: Gmail 수집

Gmail MCP로 오늘 미읽음 메일을 조회한다.

`search_threads` 툴을 사용. 쿼리: `is:unread newer_than:1d`

**주의:** `label:important` 쿼리는 사용하지 않는다. Gmail의 "중요" 레이블은 ML 기반으로 신뢰할 수 없다.

결과를 GMAIL_DATA 변수로 기억한다:
- unread_count: 미읽음 건수
- threads: [{from: "발신자", subject: "제목"}] (최대 5건)
- status: "ok" / "error" / "empty"

**에러 처리:**
- MCP 호출 실패 시: GMAIL_DATA = {status: "error"} 로 기록. 브리핑 조립 시 `⚠️ Gmail 데이터 수집 실패` 출력
- 결과가 없으면: GMAIL_DATA = {status: "empty"}. 브리핑 조립 시 `📬 이메일\n- (미읽음 없음)` 출력

성공 시 포맷:
```
📬 이메일 (미읽음 N건)
- 발신자: 제목 요약
- 발신자: 제목 요약
```
(최대 5건 표시. 5건 초과 시 마지막에 "외 N건" 추가)

---

## 5단계: Slack 수집

Slack MCP로 미읽음 메시지를 조회한다.

`slack_search_public_and_private` 툴을 사용. 쿼리: `is:unread`

결과를 SLACK_DATA 변수로 기억한다:
- channels: [{name: "#채널명 또는 @DM발신자", summary: "메시지 요약"}] (최대 5건)
- status: "ok" / "error" / "empty"

**에러 처리:**
- MCP 호출 실패 시: SLACK_DATA = {status: "error"}. 브리핑 조립 시 `⚠️ Slack 데이터 수집 실패` 출력
- 결과가 없으면: SLACK_DATA = {status: "empty"}. 브리핑 조립 시 `💬 Slack\n- (미읽음 없음)` 출력

성공 시 포맷:
```
💬 Slack
- #채널명: 메시지 요약
- @DM발신자: 메시지 요약
```
(최대 5건 표시. 초과 시 "외 N건" 추가)

---

## 6단계: 공지 소스 수집

`NOTICE_SOURCE_1_*`부터 `NOTICE_SOURCE_3_*`까지 설정된 URL을 각각 독립적으로 WebFetch한다. 값이 비어 있는 소스는 건너뛰며, 하나가 실패해도 나머지는 계속 진행한다.

각 소스는 다음 설정을 사용한다.

```text
NOTICE_SOURCE_N_LABEL
NOTICE_SOURCE_N_URL
NOTICE_SOURCE_N_LIMIT
```

수집 결과를 NOTICE_DATA 변수로 기억한다:
- sources: [{label: "소스명", items: [{title: "공지 제목", deadline: "MM/DD 또는 null"}]}]
- status: "ok" / "error" / "empty"

마감일 추출: 공지 제목에서 날짜 패턴(`MM/DD`, `MM월 DD일`, `YYYY-MM-DD`) 발견 시 deadline에 저장.
**날짜 필터링:** deadline이 오늘 이전인 공지는 제외한다 (이미 지난 공지 표시 금지).
이 데이터는 9단계 "이번 주 놓치면 안 되는 것" 섹션에서 사용된다.

성공 시 포맷:

🏫 공지
- [소스 1] 공지 제목 1
- [소스 1] 공지 제목 2
- [소스 2] 공지 제목 1

(각 소스의 `NOTICE_SOURCE_N_LIMIT`만큼 소스 태그와 함께 나열)

세 소스 모두 실패 시:

🏫 공지
⚠️ 공지 소스 전체 접근 불가 (네트워크 또는 URL 변경 확인)

---

## 7단계: 프로젝트 현황 수집

`${REPOS_DIR}` 하위 디렉토리 중 최근 30일 내 커밋이 있는 레포만 수집한다. 최대 10개 상한.

```bash
for dir in "$REPOS_DIR"/*/; do
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
3. 미커밋 변경: `git -C <path> status --short` (출력이 있으면 "있음", 없으면 "없음")
4. NOTES.md: `<path>/NOTES.md` 파일이 있으면 마지막 `## YYYY-MM-DD` 섹션의 첫 1-2줄 읽기

수집 결과를 PROJECT_STATUS 변수로 기억한다:
- repos: [{name: "레포명", branch: "브랜치명", recent_commits: ["커밋 메시지"], has_uncommitted: true/false, notes_snippet: "최근 NOTES 요약 또는 null"}]
- status: "ok" / "error"

**에러 처리:**
- git 명령 실패 시 해당 레포는 건너뛴다
- NOTES.md 없으면 notes_snippet = null
- 활성 레포가 없으면: `💻 프로젝트 현황\n- (최근 30일 내 활동 없음)` 출력

성공 시 포맷:

💻 프로젝트 현황
- [레포명] branch: 브랜치명
  최근 커밋: 커밋 요약 (N개)
  미커밋: 있음 / 없음
  NOTES: 최근 항목 요약

---

## 8단계: AI 컨텍스트 수집

네 가지 소스를 독립적으로 수집한다. 각각 실패해도 나머지는 계속 진행한다.

### 8-1: Claude Code / Claude CLI

**MEMORY.md (구조적 컨텍스트):**

```bash
ls -t "$CLAUDE_PROJECTS_DIR"/*/memory/MEMORY.md 2>/dev/null | head -3
```

각 파일을 Read 툴로 읽어 핵심 항목을 요약한다. 요약 기준:
- 현재 진행 중인 프로젝트나 작업
- 최근 중요한 결정 또는 피드백
- 다음 할 일로 이어지는 컨텍스트

**지난 24시간 활동 (history.jsonl):**

```bash
python3 - << 'EOF'
import json, time, sys

cutoff = time.time() * 1000 - 86400000  # 24시간 전 (ms)
items = []
try:
    with open('/Users/User/.claude/history.jsonl') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            obj = json.loads(line)
            if obj.get('timestamp', 0) > cutoff:
                display = obj.get('display', '').strip()
                if display:
                    items.append(display[:80])
    # 중복 제거 (순서 유지), 최신 10개
    seen, unique = set(), []
    for item in reversed(items):
        if item not in seen:
            seen.add(item)
            unique.insert(0, item)
    result = unique[:10]
    print(f"count:{len(items)}")
    for r in result:
        print(r)
except Exception as e:
    print(f"error:{e}", file=sys.stderr)
EOF
```

출력 첫 줄 `count:N` → 24시간 내 총 명령어 수로 기록.
이후 줄 → 대표 활동 목록으로 기록.

### 8-2: Gemini CLI

```bash
# 최근 7일 내 사용 프로젝트 (수정 시간 기준)
find ~/.gemini/history -maxdepth 1 -mindepth 1 -type d 2>/dev/null | while read dir; do
    mtime=$(stat -f "%m" "$dir" 2>/dev/null)
    now=$(date +%s)
    age=$(( (now - mtime) / 86400 ))
    if [ "$age" -le 7 ]; then
        name=$(basename "$dir")
        date_str=$(stat -f "%Sm" -t "%m/%d" "$dir" 2>/dev/null)
        root=$(cat "$dir/.project_root" 2>/dev/null | head -1)
        echo "- $name ($date_str) → $root"
    fi
done

# 최근 대화 DB에서 텍스트 추출 (best effort — 실패 허용)
DB=$(ls -t ~/.gemini/antigravity/conversations/*.db 2>/dev/null | head -1)
if [ -n "$DB" ]; then
    strings "$DB" 2>/dev/null \
    | grep -E "^[가-힣a-zA-Z0-9 ,.!?:()]{10,100}$" \
    | grep -vE "SQLite|System Prompt|Chat Messages|guidelines|Project structure|Listing project" \
    | tail -5
fi
```

7일 내 사용 프로젝트가 없으면: `(최근 7일 내 Gemini CLI 사용 없음)` 으로 기록.
DB 추출 실패 시: 프로젝트 목록만 기록.

### 8-3: ChatGPT

```bash
# 마지막 대화 파일 수정 날짜 확인 (내용은 암호화됨)
CHATGPT_DIR=~/Library/Application\ Support/com.openai.atlas/workspace-data
CONV_DIR=$(ls -d "$CHATGPT_DIR"/user-*/conversations-v3 2>/dev/null | head -1)
if [ -n "$CONV_DIR" ]; then
    last_date=$(ls -lt "$CONV_DIR"/*.data 2>/dev/null | head -1 | awk '{print $6, $7, $8}')
    echo "마지막 사용: $last_date (대화 내용 암호화 — 접근 불가)"
else
    echo "(ChatGPT 앱 데이터 없음)"
fi
```

수집 결과를 AI_CONTEXT 변수로 기억한다:
- claude_memory: ["MEMORY.md 요약 항목들"]
- claude_history: {count: N, items: ["최근 활동 1", ...]}
- gemini_projects: ["프로젝트명 (날짜)", ...]
- gemini_snippets: ["텍스트 조각 1", ...]  (best effort, 없어도 무방)
- chatgpt_last_used: "YYYY-MM-DD" 또는 null
- status: "ok" / "error" / "empty"

**에러 처리:**
- 각 소스 독립적으로 실패 허용. 실패한 소스는 해당 항목에 `⚠️ [소스명] 수집 실패` 표기.
- 모든 소스 실패 시: `🤖 AI 컨텍스트\n⚠️ 전체 수집 실패` 출력.
- Claude MEMORY.md 없으면: `(메모리 파일 없음)` 으로 기록.

성공 시 포맷:

```
🤖 AI 컨텍스트

**[Claude Code / CLI]**
메모리:
- 요약 항목 1
- 요약 항목 2

지난 24시간 (N개 명령어):
- 활동 1
- 활동 2

**[Gemini CLI]** 최근 프로젝트:
- 프로젝트명 (MM/DD)

**[ChatGPT]** 최근 사용: YYYY-MM-DD
```

---

## 9단계: 위험도 계산 및 브리핑 조립

### 공휴일 확인

TODAY 날짜를 대한민국 법정 공휴일 목록과 비교한다. 자신의 학습 데이터를 활용해 현재 연도의 공휴일 여부를 판단한다. 공휴일이면 HOLIDAY_NAME에 공휴일명을 저장 (예: "현충일", "추석", "광복절"). 공휴일이 아니면 HOLIDAY_NAME = null.

### 위험도 계산

NOTION_TASKS.status가 "error"이면: `🟡 MED — Notion 수집 실패로 위험도 불확실`

NOTION_TASKS.status가 "ok"이면 today + upcoming + overdue 전체 p0/p1에서 판단:
- 🔴 HIGH: p0 항목이 있고 due가 오늘이거나 이미 지난 것 / 또는 마감 없는 p0 항목이 2개 이상
- 🟡 MED: p0는 있으나 due가 내일 이후 / 또는 p0 없지만 p1 중 due가 오늘
- 🟢 LOW: p0 없고 오늘 마감 p1도 없음

NOTION_TASKS.status가 "empty"이면: `🟢 LOW — 할 일 없음`

위험도 이유 한 줄 예: "D-2 기계론 기말 (6/9)", "P0 항목 3개 처리 필요", "긴급 항목 없음"

### 지금 가장 중요한 한 가지 선택

우선순위 (deferred 항목은 후순위):
1. today.p0 중 due가 가장 가까운 것
2. upcoming p0 중 due가 가장 가까운 것
3. today.p1 중 due가 가장 가까운 것
4. upcoming p1 중 due가 가장 가까운 것
5. due 없으면 today.p0 첫 번째, 없으면 today.p1 첫 번째
6. NOTION_TASKS.status가 "error" / "empty"이면 이 섹션 생략

예상 소요시간: 작업명 기반으로 추정 ("기말 시험"→3h, "과제 제출"→2h, "이메일"→30m).
마감까지 남은 일수: due가 있으면 `D-N` 표기.

### 이번 주 놓치면 안 되는 것

오늘부터 7일 이내 마감인 항목:
1. NOTION_TASKS 전체(today/upcoming/overdue)에서 due가 오늘~7일 이내인 p0+p1+p2
2. NOTICE_DATA에서 deadline이 오늘~7일 이내인 것
3. Calendar 이벤트에서 오늘~7일 이내인 것 (시험, 과제 마감 등)

결과 없으면 이 섹션 전체 생략.

### 추천 행동 생성

2-3개 구체적 행동:
- GMAIL_DATA.unread_count >= 5 → "미읽음 이메일 N건 — 빠른 확인 필요"
- 위험도 HIGH이고 오늘 마감 p0 있음 → "오늘 마감 P0 항목 먼저 처리"
- PROJECT_STATUS에 has_uncommitted = true → "[레포명] 미커밋 변경 커밋 권장"
- NOTICE_DATA에 deadline 오늘~3일 → "공지 마감 임박 확인"
- 조건 없으면 → "특이사항 없음. 계획대로 진행"

### 브리핑 조립

```
# 🗓️ {TODAY} 브리핑
{HOLIDAY_NAME이 있으면: > 🎌 오늘은 {HOLIDAY_NAME}입니다}

---

## {위험도 이모지} 현재 위험도: {HIGH / MED / LOW}
> {위험도 이유 한 줄}

---

## 🎯 지금 가장 중요한 한 가지
**{작업명}** — 예상 {Xh/Xm} | {D-N / 오늘 마감}

---

## 📋 이번 주 목표
{NOTION_TASKS.week_categories를 카테고리별로:}
- **{카테고리}** — {항목1}, {항목2}, ...

---

## ✅ 오늘 할 일
{NOTION_TASKS.today 기준}

{p0 있으면:}
### 🔴 P0 — 지금 해야 함
- [ ] {항목명}

{p1 있으면:}
### 🟡 P1 — 오늘 안에
- [ ] {항목명}

{p2 있으면:}
### ⚪ P2 — 여유 있으면
- [ ] {항목명}

{today 컬럼 없거나 모두 완료: _오늘 할 일 없음_}

---

## 🔜 미룬 항목
{전체 날짜의 deferred 항목, 날 순서대로:}
- **[요일]** 항목명
{없으면 이 섹션 생략}

---

## 📅 이번 주 남은 일정 (Notion + Calendar)
{NOTION_TASKS.upcoming — 오늘 이후 날, 비어있지 않은 날만:}
**[요일]**
- [ ] 항목명

{overdue 중 deferred 아닌 것 있으면:}
**⚠️ 지난 날 미완료**
- [요일] 항목명

{Calendar 이번 주 이벤트 — 오늘 이후:}
- **내일 {HH:MM}** 이벤트명
- **{요일} 종일** 이벤트명

{모두 없으면 섹션 생략}

---

## 👀 이번 주 놓치면 안 되는 것
{표 형식: | 항목 | 마감 | D-N |}
{없으면 이 섹션 전체 생략}

---

## 📅 일정 (오늘)
{Calendar 오늘 이벤트 있으면:}
- **{HH:MM}** 이벤트명  (종일이면 "종일")
{없으면: _일정 없음_}

---

## 📬 이메일
{GMAIL_DATA.status가 ok이면: **미읽음 {N}건**}
{스레드 목록: `- **발신자** — 제목`}
{없으면: _미읽음 없음_}

---

## 💬 Slack
{채널/DM 목록: `- **#채널명** — 메시지 요약`}
{없으면: _미읽음 없음_}

---

## 🏫 공지
{설정된 소스 순서로 소스명을 bold로:}
**[소스명]**
- 공지 제목

---

## 💻 프로젝트 현황
{각 레포:}
### `{레포명}` — `{브랜치명}`
- 최근 커밋: {커밋 요약}
- 미커밋 변경: {있음 ⚠️ / 없음 ✅}
- NOTES: {최근 항목 또는 생략}

---

## 🤖 AI 컨텍스트

**[Claude Code / CLI]**
{claude_memory 항목을 bullet로}

지난 24시간 ({claude_history.count}개 명령어):
{claude_history.items를 bullet로}

**[Gemini CLI]** 최근 프로젝트:
{gemini_projects를 bullet로. 없으면 "(최근 사용 없음)"}

{gemini_snippets가 있으면:}
최근 작업 컨텍스트:
{gemini_snippets를 bullet로}

**[ChatGPT]** 최근 사용: {chatgpt_last_used 또는 "미확인"}

---

## 💡 추천 행동
{각 항목을 번호 리스트로: `1. **[대상]** 행동 내용`}
```

### 출력 라우팅

args에 `--discord`이 포함되어 있으면:

**1. Keychain에서 웹훅 URL 읽기:**

```bash
DISCORD_WEBHOOK=$(security find-generic-password -a "$USER" -s "discord-briefing-webhook" -w 2>/dev/null)
```

읽기 실패 시: "⚠️ Discord 웹훅 URL을 Keychain에서 찾을 수 없습니다 (키: discord-briefing-webhook)" 출력 후 터미널에 브리핑 출력.

**2. 브리핑을 2000자 단위로 청크 분할 후 순서대로 전송:**

```bash
# 브리핑 텍스트를 BRIEFING 변수에 저장한 뒤 청크 전송
python3 - << 'EOF'
import sys, os, json, urllib.request

briefing = os.environ.get("BRIEFING", "")
webhook = os.environ.get("DISCORD_WEBHOOK", "")
chunks = [briefing[i:i+2000] for i in range(0, len(briefing), 2000)]

for i, chunk in enumerate(chunks):
    payload = json.dumps({"content": chunk}).encode()
    req = urllib.request.Request(
        webhook,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "User-Agent": "DiscordBot (schedule-briefer, 1.0)",
        },
        method="POST"
    )
    try:
        with urllib.request.urlopen(req) as resp:
            if resp.status not in (200, 204):
                print(f"chunk {i+1} 전송 실패: HTTP {resp.status}", file=sys.stderr)
    except Exception as e:
        print(f"chunk {i+1} 전송 오류: {e}", file=sys.stderr)
        sys.exit(1)

print(f"✅ Discord #briefing 채널 전송 완료 ({len(chunks)}개 메시지)")
EOF
```

- 전송 성공 → "✅ Discord #briefing 채널 전송 완료 (N개 메시지)" 출력
- 전송 실패 → "⚠️ Discord 전송 실패 — 브리핑을 터미널에 출력합니다" 출력 후 브리핑을 터미널에 출력

args에 `--discord`이 없으면:
- 브리핑을 터미널에 직접 출력한다
