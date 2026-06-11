#!/bin/bash
# 멀티 에이전트 개발 루프 오케스트레이터
# PM → Engineer → Reviewer (반려 시 Engineer 재작업 최대 3회)
set -euo pipefail

TASK="${1:-}"
SESSION="dev-loop"
REPO_ROOT="$(pwd)"
ARTIFACTS=".agents/artifacts"
AGENTS_MD=".agents/agents.md"

if [ -z "$TASK" ]; then
  echo "사용법: bash .agents/scripts/orchestrator.sh \"<기능 설명>\""
  exit 1
fi

# ── 유틸 ────────────────────────────────────────────────────────────────────

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# agents.md 에서 특정 에이전트 섹션 추출
# $1 = 에이전트 태그 (예: "@pm", "@engineer")
extract_persona() {
  local tag="$1"
  awk -v t="$tag" '
    /^## / { if (found) exit; if ($0 ~ t) { found=1 }; next }
    found && /^---/ { exit }
    found { print }
  ' "$AGENTS_MD"
}

# 에이전트 실행: 해당 pane에서 claude -p 호출, 완료 시 done_marker 생성
# $1=pane번호  $2=레이블  $3=프롬프트파일  $4=출력파일  $5=완료마커
run_agent() {
  local pane="$1" label="$2" prompt_file="$3" output_file="$4" done_marker="$5"

  rm -f "$done_marker" "$output_file"

  local step_script="/tmp/agent-step-${pane}.sh"
  cat > "$step_script" << SCRIPT
#!/bin/bash
set -euo pipefail
cd '$REPO_ROOT'
echo ""
echo "--- ${label} 시작 ---"
echo ""
claude -p "\$(cat '$prompt_file')" | tee '$output_file'
echo ""
echo "--- ${label} 완료 ---"
touch '$done_marker'
SCRIPT

  tmux send-keys -t "$SESSION:0.$pane" "bash '$step_script'" Enter

  # 완료 대기 (최대 10분)
  local waited=0
  while [ ! -f "$done_marker" ]; do
    sleep 2
    waited=$((waited + 2))
    if [ $waited -ge 600 ]; then
      log "타임아웃: ${label} 10분 초과"
      exit 1
    fi
  done
}

# ── 초기화 ──────────────────────────────────────────────────────────────────

mkdir -p "$ARTIFACTS"
rm -f "$ARTIFACTS"/.pm-done "$ARTIFACTS"/.eng-done "$ARTIFACTS"/.review-done

log "🚀 태스크: $TASK"
log "에이전트 개발 루프 시작"
echo ""

# ── Step 1: PM 스펙 작성 ─────────────────────────────────────────────────────

log "[1/3] PM → 스펙 작성"

PM_PERSONA=$(extract_persona "@pm")

cat > /tmp/pm-prompt.txt << EOF
당신은 다음 역할을 맡은 AI 에이전트입니다:

${PM_PERSONA}

---

태스크: ${TASK}

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
EOF

run_agent 0 "PM" "/tmp/pm-prompt.txt" "$ARTIFACTS/issue.md" "$ARTIFACTS/.pm-done"
log "[1/3] ✓ 스펙 완료 → $ARTIFACTS/issue.md"
echo ""

# ── Step 2: Engineer 구현 ────────────────────────────────────────────────────

ENG_PERSONA=$(extract_persona "@engineer")
REVIEW_FEEDBACK=""
RETRY=0

run_engineer() {
  local spec
  spec=$(cat "$ARTIFACTS/issue.md")

  local prompt_intro
  if [ -z "$REVIEW_FEEDBACK" ]; then
    prompt_intro="다음 스펙을 구현해주세요:"
  else
    prompt_intro="리뷰 피드백을 반영해서 구현을 수정해주세요.\n\n이전 리뷰 피드백:\n${REVIEW_FEEDBACK}\n\n스펙:"
  fi

  cat > /tmp/engineer-prompt.txt << EOF
당신은 다음 역할을 맡은 AI 에이전트입니다:

${ENG_PERSONA}

---

${prompt_intro}

${spec}

구현 결과를 다음 형식으로 출력해주세요:

## 구현 완료: <기능명>

**테스트 모드**: <TDD / Test-after / No-test>

**변경 파일**
- <파일명> — <변경 내용>

**커밋 목록**
1. \`<type>(<scope>): <설명>\`

**구현 코드 요약**
\`\`\`<언어>
<핵심 코드>
\`\`\`

**수용 기준 커버리지**: <N>/<전체>
EOF

  run_agent 1 "Engineer${REVIEW_FEEDBACK:+ (수정 $RETRY회)}" \
    "/tmp/engineer-prompt.txt" "$ARTIFACTS/impl.md" "$ARTIFACTS/.eng-done"
}

log "[2/3] Engineer → 구현"
run_engineer
log "[2/3] ✓ 구현 완료 → $ARTIFACTS/impl.md"
echo ""

# ── Step 3: Reviewer + 반려 루프 ─────────────────────────────────────────────

REVIEW_PERSONA=$(extract_persona "@reviewer")
MAX_RETRY=3

while [ $RETRY -lt $MAX_RETRY ]; do
  log "[3/3] Reviewer → 리뷰 (시도 $((RETRY+1))/$MAX_RETRY)"

  local_spec=$(cat "$ARTIFACTS/issue.md")
  local_impl=$(cat "$ARTIFACTS/impl.md")

  cat > /tmp/reviewer-prompt.txt << EOF
당신은 다음 역할을 맡은 AI 에이전트입니다:

${REVIEW_PERSONA}

---

스펙:
${local_spec}

구현:
${local_impl}

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
EOF

  run_agent 2 "Reviewer" "/tmp/reviewer-prompt.txt" \
    "$ARTIFACTS/review.md" "$ARTIFACTS/.review-done"

  if grep -q "REVIEW: APPROVED" "$ARTIFACTS/review.md"; then
    log "[3/3] ✓ 리뷰 승인"
    break
  else
    RETRY=$((RETRY + 1))
    if [ $RETRY -ge $MAX_RETRY ]; then
      log "❌ 리뷰 ${MAX_RETRY}회 반려. 수동 개입 필요."
      log "   피드백: $ARTIFACTS/review.md"
      exit 1
    fi

    log "[3/3] ✗ 반려 (${RETRY}/${MAX_RETRY}) → Engineer 재작업"
    REVIEW_FEEDBACK=$(cat "$ARTIFACTS/review.md")
    rm -f "$ARTIFACTS/.eng-done"
    run_engineer
    log "[2/3] ✓ 재작업 완료 → $ARTIFACTS/impl.md"
    rm -f "$ARTIFACTS/.review-done"
  fi
done

# ── 완료 ────────────────────────────────────────────────────────────────────

echo ""
log "🎉 개발 루프 완료!"
echo ""
echo "  📋 스펙     : $ARTIFACTS/issue.md"
echo "  💻 구현     : $ARTIFACTS/impl.md"
echo "  ✅ 리뷰     : $ARTIFACTS/review.md"
echo ""
echo "  다음 단계: /pr-review 또는 직접 PR 생성"
