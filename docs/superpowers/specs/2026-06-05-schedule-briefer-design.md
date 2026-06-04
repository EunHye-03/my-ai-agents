# schedule-briefer 설계 문서

**날짜:** 2026-06-05  
**상태:** 확정 (pre-mortem 반영 업데이트)

---

## 개요

매일 아침 또는 수동 호출 시, 여러 소스에서 정보를 수집해 하루 브리핑을 생성하는 Claude Code 서브에이전트.

---

## 파일 위치

```
my-ai-agents/.claude/agents/schedule-briefer.md
```

---

## 수집 소스

| 소스 | 방법 | 상세 |
|------|------|------|
| Apple Calendar | `icalBuddy` 절대 경로 | 오늘 + 내일 일정. `/opt/homebrew/bin/icalBuddy` 절대 경로 사용 (non-interactive shell PATH 문제 방지) |
| Notion 할 일 | Notion MCP | 페이지 ID `002a894f-a829-83e9-b954-014816e6fa18`, 미완료 항목 |
| Gmail | Gmail MCP | `is:unread newer_than:1d` 쿼리 명시. Gmail "중요" 레이블 의존 금지 |
| Slack | Slack MCP | 미읽음 메시지 |
| CSE 학과 공지 | WebFetch | `https://cse.knu.ac.kr/index.php` 커뮤니티 섹션 |
| 소프트웨어교육원 공지 | WebFetch | `https://swedu.knu.ac.kr/05_sub/01_sub.html` |
| 경북대 국제처 공지 | WebFetch | `https://international.knu.ac.kr/HOME/global/index.htm` |
| 프로젝트 현황 | 로컬 파일 + Bash | `~/src/repos/` 내 최근 30일 내 커밋 있는 레포만 |
| AI 작업 컨텍스트 | 파일 직접 읽기 | `~/.claude/projects/*/memory/MEMORY.md` |

### 프로젝트 현황 상세

각 레포에서 수집:
- 현재 브랜치 (`git branch --show-current`)
- 최근 커밋 5개 (`git log --oneline -5`)
- 미커밋 변경 여부 (`git status --short`)
- `NOTES.md` 최근 날짜 항목

조건: `git log --since="30 days ago"`로 커밋이 있는 레포만 포함. 최대 10개 상한.

`~/src/repos/` 직접 glob 사용. 설정 파일 없이 해당 디렉토리 전체 스캔.

---

## 브리핑 포맷

```
🗓️ YYYY-MM-DD (요일) 브리핑

✅ 오늘 할 일
- [ ] 항목 1
- [ ] 항목 2

📅 일정
- HH:MM 일정명
- 내일: 일정명

📬 이메일 (미읽음 N건)
- [중요] 발신자: 제목...

💬 Slack
- #채널명: 내용 요약...

🏫 학교 공지
- [CSE] 공지 제목...
- [SW교육원] 공지 제목...
- [국제처] 공지 제목...

💻 프로젝트 현황
- [레포명] branch: 브랜치명
  최근 커밋: 커밋 메시지 요약
  미커밋 변경: 있음/없음
  NOTES: 최근 항목 요약

🤖 AI 컨텍스트
- 메모리 파일 요약
```

---

## 트리거 & 출력

| 트리거 | 출력 대상 |
|--------|-----------|
| 매일 아침 자동 (`/schedule` 등록) | Slack DM |
| "브리핑해줘" 수동 호출 | 터미널 출력 |

자동/수동 구분: 에이전트 호출 시 args에 `--slack` 포함되면 Slack 전송, 없으면 터미널 출력.

**자동 실행 주의:** `/schedule`이 원격 실행인 경우 로컬 파일·icalBuddy 접근 불가. 로컬 실행인 경우 Claude Code 세션 활성 상태 필요 (노트북 잠자기 시 스킵). 구현 시 실제 동작 방식 검증 후 결정.

---

## 에러 핸들링 원칙 (pre-mortem 반영)

각 소스는 개별적으로 격리 실행. 하나 실패해도 나머지는 계속 진행.

- 실패 시 해당 섹션에 `⚠️ [소스명] 데이터 수집 실패` 명시
- Notion 응답이 빈 배열이면 `⚠️ 할 일 0건 (Notion 직접 확인 권장)` 경고
- WebFetch HTTP 비정상 응답 시 "공지 없음" 대신 `⚠️ [사이트명] 접근 불가` 출력
- Slack 전송 후 응답 검증. 실패 시 터미널에 경고 출력

---

## v2 예약 항목

- **KNU 러닝엑스**: Playwright 자동 로그인으로 과제 마감·공지 수집 (blog-writer Tistory 패턴 참고)
- **학과 Discord**: 봇 추가 가능해지면 Slack MCP 방식과 유사하게 붙이기
