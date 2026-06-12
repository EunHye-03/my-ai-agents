#!/bin/bash
# 멀티 에이전트 개발 루프 오케스트레이터
# PM → Engineer → Reviewer → QA (반려/실패 시 재작업, state.md 기반 재개 지원)
set -euo pipefail

TASK="${1:-}"
SESSION="dev-loop"
REPO_ROOT="$(pwd)"
ARTIFACTS=".agents/artifacts"
AGENTS_MD=".agents/agents.md"
MAX_REVIEW_RETRY=3
MAX_QA_RETRY=2

if [[ -z "$TASK" ]]; then
  echo "사용법: bash .agents/scripts/orchestrator.sh \"<기능 설명>\""
  exit 1
fi

# ── 유틸 ────────────────────────────────────────────────────────────────────

log() { echo "[$(date '+%H:%M:%S')] $*"; }

extract_persona() {
  local tag="$1"
  awk -v t="$tag" '
    /^## / { if (found) exit; if ($0 ~ t) { found=1 }; next }
    found && /^---/ { exit }
    found { print }
  ' "$AGENTS_MD"
}

run_agent() {
  local pane="$1" label="$2" prompt_file="$3" output_file="$4" done_marker="$5"
  rm -f "$done_marker" "$output_file"

  local error_marker="${done_marker}.error"
  rm -f "$error_marker"

  cat > "/tmp/agent-step-${pane}.sh" << SCRIPT
#!/bin/bash
cd '${REPO_ROOT}' || { echo "[ERROR] cd 실패: ${REPO_ROOT}"; exit 1; }
echo ""
echo "--- ${label} 시작 ---"
echo ""
claude -p "\$(cat '${prompt_file}')" | tee '${output_file}'
_exit=\${PIPESTATUS[0]}
if [[ \$_exit -eq 0 ]]; then
  echo ""
  echo "--- ${label} 완료 ---"
  touch '${done_marker}'
else
  echo ""
  echo "[ERROR] ${label} 실패 (claude exit: \$_exit)"
  touch '${error_marker}'
fi
SCRIPT

  tmux send-keys -t "$SESSION:0.$pane" "bash /tmp/agent-step-${pane}.sh" Enter

  local waited=0
  while [[ ! -f "$done_marker" && ! -f "$error_marker" ]]; do
    sleep 2
    waited=$((waited + 2))
    if [[ $waited -ge 600 ]]; then
      log "타임아웃: ${label} 10분 초과"
      exit 1
    fi
  done

  if [[ -f "$error_marker" ]]; then
    log "[ERROR] ${label} 실패 — pane $pane 출력 확인 필요"
    exit 1
  fi
}

save_state() {
  local step="$1" next_action="$2" status="${3:-in_progress}"
  printf '## Workflow State\n- workflow: dev-loop\n- feature: %s\n- current_step: %s\n- last_completed: Step %s (%s)\n- next_action: %s\n- status: %s\n' \
    "${TASK}" "${step}" "${step}" "$(date '+%Y-%m-%d %H:%M')" "${next_action}" "${status}" \
    > "$ARTIFACTS/state.md"
}

# ── 에이전트 실행 함수 ───────────────────────────────────────────────────────
# 전역 변수: ENG_PERSONA, REVIEW_PERSONA, QA_PERSONA, REVIEW_FEEDBACK, review_retry

run_engineer() {
  local label="Engineer"
  local feedback_section=""

  if [[ -n "$REVIEW_FEEDBACK" ]]; then
    label="Engineer (수정 ${review_retry}회)"
    feedback_section="${REVIEW_FEEDBACK}"
  fi

  {
    printf '%s\n\n%s\n\n---\n\n' '당신은 다음 역할을 맡은 AI 에이전트입니다:' "${ENG_PERSONA}"
    if [[ -n "${feedback_section}" ]]; then
      printf '다음 피드백을 반영해서 구현을 수정해주세요:\n\n%s\n\n' "${feedback_section}"
    fi
    printf '스펙:\n'
    cat "$ARTIFACTS/issue.md"
    printf '\n'
    cat << '__OUTPUT_FMT__'
구현 결과를 다음 형식으로 출력해주세요:

## 구현 완료: <기능명>

**테스트 모드**: <TDD / Test-after / No-test>

**변경 파일**
- <파일명> — <변경 내용>

**커밋 목록**
1. `<type>(<scope>): <설명>`

**구현 코드 요약**
```<언어>
<핵심 코드>
```

**수용 기준 커버리지**: <N>/<전체>
__OUTPUT_FMT__
  } > /tmp/engineer-prompt.txt

  run_agent 1 "$label" "/tmp/engineer-prompt.txt" \
    "$ARTIFACTS/impl.md" "$ARTIFACTS/.eng-done"
}

run_reviewer() {
  {
    printf '%s\n\n%s\n\n---\n\n' '당신은 다음 역할을 맡은 AI 에이전트입니다:' "${REVIEW_PERSONA}"
    printf '스펙:\n'
    cat "$ARTIFACTS/issue.md"
    printf '\n구현:\n'
    cat "$ARTIFACTS/impl.md"
    printf '\n'
    cat << '__OUTPUT_FMT__'
위 구현을 리뷰해주세요. 다음 형식으로 출력해주세요:

## 리뷰: <기능명>

**스펙 커버리지**: <N>/<전체> 수용 기준 충족

**피드백**
- ✅ <잘된 점>
- ⚠️ <개선 권장>
- ❌ <반드시 수정 필요>

**결론**
<종합 의견>

마지막 줄은 반드시 다음 중 하나만 적어주세요 (다른 텍스트 없이):
REVIEW: APPROVED
REVIEW: REJECTED
__OUTPUT_FMT__
  } > /tmp/reviewer-prompt.txt

  run_agent 2 "Reviewer" "/tmp/reviewer-prompt.txt" \
    "$ARTIFACTS/review.md" "$ARTIFACTS/.review-done"
}

# Engineer → Reviewer 루프 (review_retry, REVIEW_FEEDBACK 공유)
# $1=true 이면 첫 Engineer 실행 생략 (재개 시 Reviewer부터)
engineer_reviewer_loop() {
  local skip_first_engineer="${1:-false}"

  if [[ "$skip_first_engineer" != "true" ]]; then
    log "[2/4] Engineer → 구현"
    run_engineer
    save_state 2 "Reviewer 리뷰 대기"
    log "[2/4] ✓ 구현 완료 → $ARTIFACTS/impl.md"
    echo ""
  fi

  while [[ $review_retry -lt $MAX_REVIEW_RETRY ]]; do
    log "[3/4] Reviewer → 리뷰 (시도 $((review_retry + 1))/$MAX_REVIEW_RETRY)"
    run_reviewer

    if grep -q "REVIEW: APPROVED" "$ARTIFACTS/review.md"; then
      save_state 3 "QA 검증 대기"
      log "[3/4] ✓ 리뷰 승인"
      echo ""
      return 0
    fi

    review_retry=$((review_retry + 1))
    if [[ $review_retry -ge $MAX_REVIEW_RETRY ]]; then
      log "❌ 리뷰 ${MAX_REVIEW_RETRY}회 반려. 수동 개입 필요."
      log "   피드백: $ARTIFACTS/review.md"
      save_state 2 "수동 개입 필요 — 리뷰 ${MAX_REVIEW_RETRY}회 반려" "blocked"
      exit 1
    fi

    log "[3/4] ✗ 반려 ($review_retry/$MAX_REVIEW_RETRY) → Engineer 재작업"
    REVIEW_FEEDBACK=$(cat "$ARTIFACTS/review.md")
    rm -f "$ARTIFACTS/.eng-done" "$ARTIFACTS/.review-done"
    run_engineer
    save_state 2 "Reviewer 리뷰 대기"
    echo ""
  done
}

# ── 초기화 + 재개 확인 ─────────────────────────────────────────────────────

mkdir -p "$ARTIFACTS"
START_STEP=1

if [[ -f "$ARTIFACTS/state.md" ]]; then
  saved_task=$(grep "^- feature:" "$ARTIFACTS/state.md" | sed 's/^- feature: //')
  saved_status=$(grep "^- status:" "$ARTIFACTS/state.md" | awk '{print $NF}')
  saved_step=$(grep "^- current_step:" "$ARTIFACTS/state.md" | awk '{print $NF}')

  if [[ "$saved_status" == "in_progress" && "$saved_task" == "$TASK" ]]; then
    START_STEP=$((saved_step + 1))
    log "이전 작업 재개: Step ${saved_step} 완료 → Step ${START_STEP}부터 시작"
  elif [[ "$saved_status" == "blocked" && "$saved_task" == "$TASK" ]]; then
    # blocked 상태에서 재실행 시 마지막 완료 스텝부터 재시도
    START_STEP=$saved_step
    log "blocked 상태 재시도: Step ${START_STEP}부터"
    save_state "$START_STEP" "재시도 중"
  else
    log "새 작업 시작 (이전 상태 초기화)"
    rm -f "$ARTIFACTS"/*.md "$ARTIFACTS"/.*.done 2>/dev/null || true
  fi
else
  rm -f "$ARTIFACTS"/.*.done 2>/dev/null || true
fi

log "🚀 태스크: $TASK"
echo ""

# ── Step 1: PM 스펙 작성 ─────────────────────────────────────────────────────

if [[ $START_STEP -le 1 ]]; then
  log "[1/4] PM → 스펙 작성"
  PM_PERSONA=$(extract_persona "@pm")

  {
    printf '%s\n\n%s\n\n---\n\n' '당신은 다음 역할을 맡은 AI 에이전트입니다:' "${PM_PERSONA}"
    printf '태스크: %s\n\n' "${TASK}"
    cat << '__OUTPUT_FMT__'
위 태스크에 대해 PM 역할에 따라 스펙을 작성해주세요.
다음 형식을 따라주세요:

## 이슈: <제목>

**배경**
<왜 이 기능이 필요한지>

**수용 기준**
- [ ] <기준 1>
- [ ] <기준 2>
...

**범위 밖**
- <포함하지 않을 것들>
__OUTPUT_FMT__
  } > /tmp/pm-prompt.txt

  run_agent 0 "PM" "/tmp/pm-prompt.txt" "$ARTIFACTS/issue.md" "$ARTIFACTS/.pm-done"
  save_state 1 "Engineer 구현 대기"
  log "[1/4] ✓ 스펙 완료 → $ARTIFACTS/issue.md"
  echo ""
else
  log "[1/4] ✓ PM 스펙 재개 (skip) → $ARTIFACTS/issue.md"
fi

# ── Steps 2-3: Engineer + Reviewer 루프 ──────────────────────────────────────

ENG_PERSONA=$(extract_persona "@engineer")
REVIEW_PERSONA=$(extract_persona "@reviewer")
REVIEW_FEEDBACK=""
review_retry=0

if [[ $START_STEP -le 2 ]]; then
  engineer_reviewer_loop "false"
elif [[ $START_STEP -le 3 ]]; then
  log "[2/4] ✓ Engineer 재개 (skip)"
  engineer_reviewer_loop "true"   # Reviewer부터 재개
else
  log "[2/4] ✓ Engineer 재개 (skip)"
  log "[3/4] ✓ Reviewer 재개 (skip)"
  echo ""
fi

# ── Step 4: QA 검증 ──────────────────────────────────────────────────────────

QA_PERSONA=$(extract_persona "@qa")
qa_retry=0

if [[ $START_STEP -le 4 ]]; then
  # Reviewer pane(2)을 QA로 재사용
  tmux send-keys -t "$SESSION:0.2" \
    "printf '\n\033[36m┌───────────────────┐\n│  🔷  QA           │\n└───────────────────┘\033[0m\n'" Enter

  while [[ $qa_retry -le $MAX_QA_RETRY ]]; do
    log "[4/4] QA → 검증 (시도 $((qa_retry + 1)))"

    {
      printf '%s\n\n%s\n\n---\n\n' '당신은 다음 역할을 맡은 AI 에이전트입니다:' "${QA_PERSONA}"
      if [[ $qa_retry -gt 0 && -f "$ARTIFACTS/test-plan.md" ]]; then
        printf '이전 QA 결과:\n'
        cat "$ARTIFACTS/test-plan.md"
        printf '\n\n'
      fi
      printf '스펙:\n'
      cat "$ARTIFACTS/issue.md"
      printf '\n구현:\n'
      cat "$ARTIFACTS/impl.md"
      printf '\n리뷰:\n'
      cat "$ARTIFACTS/review.md"
      printf '\n'
      cat << '__OUTPUT_FMT__'
QA 검증을 수행해주세요. 다음 형식으로 출력해주세요:

## QA 검증: <기능명>

**테스트 케이스**
- [ ] <케이스 1> — <기대 결과>
- [ ] <케이스 2> — <기대 결과>

**엣지 케이스**
- <발견한 엣지 케이스>

**이슈 목록**
- <발견된 이슈, 없으면 "없음">

마지막 줄은 반드시 다음 중 하나만 적어주세요 (다른 텍스트 없이):
QA: PASSED
QA: FAILED
__OUTPUT_FMT__
    } > /tmp/qa-prompt.txt

    run_agent 2 "QA" "/tmp/qa-prompt.txt" \
      "$ARTIFACTS/test-plan.md" "$ARTIFACTS/.qa-done"

    if grep -q "QA: PASSED" "$ARTIFACTS/test-plan.md"; then
      save_state 4 "완료" "done"
      log "[4/4] ✓ QA 통과"
      break
    fi

    qa_retry=$((qa_retry + 1))
    if [[ $qa_retry -gt $MAX_QA_RETRY ]]; then
      log "❌ QA ${MAX_QA_RETRY}회 실패. 수동 개입 필요."
      log "   결과: $ARTIFACTS/test-plan.md"
      save_state 3 "수동 개입 필요 — QA ${MAX_QA_RETRY}회 실패" "blocked"
      exit 1
    fi

    log "[4/4] ✗ QA 실패 ($qa_retry/$MAX_QA_RETRY) → Engineer 재작업 후 리뷰 재실행"
    REVIEW_FEEDBACK="QA 실패 피드백:
$(cat "$ARTIFACTS/test-plan.md")"
    review_retry=0
    rm -f "$ARTIFACTS/.eng-done" "$ARTIFACTS/.review-done" "$ARTIFACTS/.qa-done"

    engineer_reviewer_loop "false"
  done
else
  log "[4/4] ✓ QA 재개 (skip)"
fi

# ── 완료 ─────────────────────────────────────────────────────────────────────

echo ""
log "🎉 개발 루프 완료!"
echo ""
echo "  📋 스펙       : $ARTIFACTS/issue.md"
echo "  💻 구현       : $ARTIFACTS/impl.md"
echo "  ✅ 리뷰       : $ARTIFACTS/review.md"
echo "  🔷 QA 결과    : $ARTIFACTS/test-plan.md"
echo "  📊 상태       : $ARTIFACTS/state.md"
echo ""
echo "  다음 단계: /pr-review 또는 직접 PR 생성"
