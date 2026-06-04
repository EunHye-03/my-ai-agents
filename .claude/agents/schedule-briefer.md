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
