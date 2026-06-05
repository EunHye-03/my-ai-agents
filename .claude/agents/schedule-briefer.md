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

## 1단계: 날짜 확인

오늘 날짜와 요일을 확인한다.

```bash
date '+%Y-%m-%d (%a)'
```

결과를 TODAY로 기억한다.

## 2단계: Apple Calendar 수집

icalBuddy를 절대 경로로 실행한다. PATH 문제를 방지하기 위해 반드시 절대 경로 사용.

```bash
/opt/homebrew/bin/icalBuddy -n -b "•" -df "%H:%M" eventsToday+1
```

- 출력이 비어있으면: `📅 일정\n- (없음)` 으로 기록
- 명령 실패(파일 없음, 권한 오류 등)이면: `📅 일정\n⚠️ icalBuddy 실행 실패 (Calendar 권한 확인 필요)` 로 기록
- 성공 시 오늘/내일 일정을 `📅 일정` 섹션으로 포맷

---

## 3단계: Notion 할 일 수집

Notion MCP로 할 일 페이지를 조회한다.

페이지 ID: `002a894f-a829-83e9-b954-014816e6fa18` (Weekly To-Do 페이지)

`notion-fetch` 툴로 해당 페이지를 가져온다.

응답에서 미완료 할 일 항목을 추출한다:
- JSON 블록 형식인 경우: `type: "to_do"`이고 `checked: false`인 블록의 텍스트
- 마크다운 형식인 경우: `- [ ]` 로 시작하는 줄의 텍스트

**우선순위 분류 (이모지 기반):**
- ‼️ 포함 항목 → P0 (지금 해야 함)
- ❗️ 포함 항목 → P1 (오늘 안에)
- ❕ 포함 항목 → P2 (여유 있으면)
- 이모지 없는 항목 → P1 (기본값)

**마감 추출:** 항목명에 `(MM/DD)`, `(YYYY-MM-DD)`, `~MM/DD` 형태가 있으면 마감일로 추출.

수집 결과를 NOTION_TASKS 변수로 기억한다. 구조:
- p0: [{name: "항목명", due: "MM/DD 또는 null"}]
- p1: [{name: "항목명", due: "MM/DD 또는 null"}]
- p2: [{name: "항목명", due: "MM/DD 또는 null"}]
- status: "ok" / "error" / "empty"

이 데이터는 9단계(위험도 계산, "지금 가장 중요한 한 가지", "이번 주 놓치면 안 되는 것")에서 사용된다.

**에러 처리:**
- MCP 호출 실패 시: NOTION_TASKS = 에러 상태로 기록. 브리핑 조립 시 `⚠️ Notion 데이터 수집 실패` 출력
- 응답은 왔으나 미완료 항목이 0건이면: NOTION_TASKS = {status: "empty"} 로 기록. 브리핑 조립 시 `✅ 오늘 할 일\n- (없음)` 출력

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

## 6단계: 학교 공지 수집

세 URL을 각각 독립적으로 WebFetch로 수집한다. 하나 실패해도 나머지는 계속 진행한다.

### CSE 학과 공지
URL: `https://cse.knu.ac.kr/index.php`
커뮤니티 섹션의 최신 공지 5건을 추출한다.
- HTTP 비정상 응답 또는 에러 페이지이면: `[CSE] ⚠️ 사이트 접근 불가`
- 파싱 실패(공지 목록을 찾을 수 없음)이면: `[CSE] ⚠️ 공지 파싱 실패`

### 소프트웨어교육원 공지
URL: `https://swedu.knu.ac.kr/05_sub/01_sub.html`
최신 공지 3건을 추출한다.
- HTTP 비정상 응답 또는 에러 페이지이면: `[SW교육원] ⚠️ 사이트 접근 불가`
- 파싱 실패(공지 목록을 찾을 수 없음)이면: `[SW교육원] ⚠️ 공지 파싱 실패`

### 경북대 국제처 공지
URL: `https://international.knu.ac.kr/HOME/global/index.htm`
최신 공지 3건을 추출한다.
- HTTP 비정상 응답 또는 에러 페이지이면: `[국제처] ⚠️ 사이트 접근 불가`
- 파싱 실패(공지 목록을 찾을 수 없음)이면: `[국제처] ⚠️ 공지 파싱 실패`

수집 결과를 KNU_NOTICES 변수로 기억한다:
- cse: [{title: "공지 제목", deadline: "MM/DD 또는 null"}] (최대 5건)
- swedu: [{title: "공지 제목", deadline: "MM/DD 또는 null"}] (최대 3건)
- international: [{title: "공지 제목", deadline: "MM/DD 또는 null"}] (최대 3건)

마감일 추출: 공지 제목에서 날짜 패턴(`MM/DD`, `MM월 DD일`, `YYYY-MM-DD`) 발견 시 deadline에 저장. 이 데이터는 9단계 "이번 주 놓치면 안 되는 것" 섹션에서 사용된다.

성공 시 포맷:

🏫 학교 공지
- [CSE] 공지 제목 1
- [CSE] 공지 제목 2
- [SW교육원] 공지 제목 1
- [SW교육원] 공지 제목 2
- [국제처] 공지 제목 1

(CSE 최대 5건, SW교육원·국제처 각 최대 3건을 소스 태그와 함께 나열)

세 소스 모두 실패 시:

🏫 학교 공지
⚠️ 학교 사이트 전체 접근 불가 (네트워크 또는 URL 변경 확인)
