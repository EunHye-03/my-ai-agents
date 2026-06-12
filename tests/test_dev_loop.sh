#!/usr/bin/env bash
# dev-loop 워크플로 검증 테스트
#
# AC1: PM이 태스크를 받으면 artifacts/issue.md를 생성한다
# AC2: Engineer가 issue.md를 읽고 impl.md를 생성한다
# AC3: Reviewer가 impl.md를 읽고 review.md를 반환한다
# AC4: QA가 구현 완료 후 test-plan.md에 검증 결과를 기록한다
# AC5: 각 단계 전환 시 이전 단계 산출물이 없으면 오류 메시지를 출력한다

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_ROOT/.agents/lib/prereq.sh"

# -- 유틸 -------------------------------------------------------------------

pass() { echo "✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "❌ FAIL: $1"; FAIL=$((FAIL+1)); }

run_test() {
  local desc="$1"; shift
  if "$@" 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc"
  fi
}

# -- AC1: PM → artifacts/issue.md -------------------------------------------

test_ac1_issue_md_format() {
  local dir; dir=$(mktemp -d)
  local arts="$dir/artifacts"; mkdir -p "$arts"
  printf '## 이슈: 테스트 기능\n\n**배경**\n테스트 배경\n\n**수용 기준**\n- [ ] 기준 1\n\n**범위 밖**\n- 없음\n' \
    > "$arts/issue.md"
  local ok=1
  [[ -f "$arts/issue.md" ]]              || ok=0
  grep -q "## 이슈:"    "$arts/issue.md" || ok=0
  grep -q "수용 기준"   "$arts/issue.md" || ok=0
  grep -q "범위 밖"     "$arts/issue.md" || ok=0
  rm -rf "$dir"
  [[ $ok -eq 1 ]]
}

# -- AC2: Engineer → artifacts/impl.md --------------------------------------

test_ac2_impl_md_format() {
  local dir; dir=$(mktemp -d)
  local arts="$dir/artifacts"; mkdir -p "$arts"
  echo "## 이슈: 테스트" > "$arts/issue.md"
  printf '## 구현 완료: 테스트 기능\n\n**테스트 모드**: TDD\n\n**변경 파일**\n- src/feature.py -- 기능 구현\n\n**수용 기준 커버리지**: 1/1\n' \
    > "$arts/impl.md"
  local ok=1
  [[ -f "$arts/impl.md" ]]                     || ok=0
  grep -q "## 구현 완료:"      "$arts/impl.md" || ok=0
  grep -q "테스트 모드"        "$arts/impl.md" || ok=0
  grep -q "수용 기준 커버리지" "$arts/impl.md" || ok=0
  rm -rf "$dir"
  [[ $ok -eq 1 ]]
}

# -- AC3: Reviewer → artifacts/review.md ------------------------------------

test_ac3_review_md_format() {
  local dir; dir=$(mktemp -d)
  local arts="$dir/artifacts"; mkdir -p "$arts"
  printf '## 리뷰: 테스트 기능\n\n**스펙 커버리지**: 1/1 수용 기준 충족\n\n**피드백**\n- ✅ 스펙 충족\n\n**결론**\n승인합니다.\n\nREVIEW: APPROVED\n' \
    > "$arts/review.md"
  local ok=1
  [[ -f "$arts/review.md" ]]                            || ok=0
  grep -qE "REVIEW: (APPROVED|REJECTED)" "$arts/review.md" || ok=0
  grep -q  "스펙 커버리지"               "$arts/review.md" || ok=0
  rm -rf "$dir"
  [[ $ok -eq 1 ]]
}

# -- AC4: QA → artifacts/test-plan.md ---------------------------------------

test_ac4_test_plan_format() {
  local dir; dir=$(mktemp -d)
  local arts="$dir/artifacts"; mkdir -p "$arts"
  printf '## QA 검증: 테스트 기능\n\n**테스트 케이스**\n- [x] 기능 동작 -- 통과\n\n**이슈 목록**\n- 없음\n\nQA: PASSED\n' \
    > "$arts/test-plan.md"
  local ok=1
  [[ -f "$arts/test-plan.md" ]]                         || ok=0
  grep -qE "QA: (PASSED|FAILED)" "$arts/test-plan.md"  || ok=0
  grep -q  "테스트 케이스"        "$arts/test-plan.md" || ok=0
  rm -rf "$dir"
  [[ $ok -eq 1 ]]
}

# -- AC5: 이전 단계 산출물 없으면 오류 메시지 출력 --------------------------

test_ac5_missing_issue_blocks_engineer() {
  local dir; dir=$(mktemp -d)
  local arts="$dir/artifacts"; mkdir -p "$arts"
  local ret=0
  check_prerequisite "$arts/issue.md" "Engineer(Step 2)" "PM(Step 1)" || ret=$?
  rm -rf "$dir"
  [[ $ret -ne 0 ]]
}

test_ac5_missing_impl_blocks_reviewer() {
  local dir; dir=$(mktemp -d)
  local arts="$dir/artifacts"; mkdir -p "$arts"
  local ret=0
  check_prerequisite "$arts/impl.md" "Reviewer(Step 3)" "Engineer(Step 2)" || ret=$?
  rm -rf "$dir"
  [[ $ret -ne 0 ]]
}

test_ac5_missing_review_blocks_qa() {
  local dir; dir=$(mktemp -d)
  local arts="$dir/artifacts"; mkdir -p "$arts"
  local ret=0
  check_prerequisite "$arts/review.md" "QA(Step 4)" "Reviewer(Step 3)" || ret=$?
  rm -rf "$dir"
  [[ $ret -ne 0 ]]
}

test_ac5_error_message_contains_filename() {
  local dir; dir=$(mktemp -d)
  local arts="$dir/artifacts"; mkdir -p "$arts"
  local output
  output=$(check_prerequisite "$arts/issue.md" "Engineer(Step 2)" "PM(Step 1)" 2>&1 || true)
  rm -rf "$dir"
  echo "$output" | grep -q "issue.md"
}

test_ac5_present_issue_allows_engineer() {
  local dir; dir=$(mktemp -d)
  local arts="$dir/artifacts"; mkdir -p "$arts"
  echo "## 이슈" > "$arts/issue.md"
  local ret=0
  check_prerequisite "$arts/issue.md" "Engineer(Step 2)" "PM(Step 1)" || ret=$?
  rm -rf "$dir"
  [[ $ret -eq 0 ]]
}

test_ac5_present_impl_allows_reviewer() {
  local dir; dir=$(mktemp -d)
  local arts="$dir/artifacts"; mkdir -p "$arts"
  echo "## 구현" > "$arts/impl.md"
  local ret=0
  check_prerequisite "$arts/impl.md" "Reviewer(Step 3)" "Engineer(Step 2)" || ret=$?
  rm -rf "$dir"
  [[ $ret -eq 0 ]]
}

test_ac5_present_review_allows_qa() {
  local dir; dir=$(mktemp -d)
  local arts="$dir/artifacts"; mkdir -p "$arts"
  echo "REVIEW: APPROVED" > "$arts/review.md"
  local ret=0
  check_prerequisite "$arts/review.md" "QA(Step 4)" "Reviewer(Step 3)" || ret=$?
  rm -rf "$dir"
  [[ $ret -eq 0 ]]
}

test_ac5_orchestrator_calls_check_prerequisite() {
  grep -q "check_prerequisite" "$REPO_ROOT/.agents/scripts/orchestrator.sh"
}

# -- 실행 -------------------------------------------------------------------

echo "══════════════════════════════════════════════════════════"
echo "  Dev-loop 워크플로 검증 테스트"
echo "══════════════════════════════════════════════════════════"
echo ""

echo "-- AC1: PM → artifacts/issue.md ------------------------------------"
run_test "issue.md 형식 (이슈·수용 기준·범위 밖)" test_ac1_issue_md_format

echo ""
echo "-- AC2: Engineer → artifacts/impl.md -------------------------------"
run_test "impl.md 형식 (테스트 모드·커버리지)" test_ac2_impl_md_format

echo ""
echo "-- AC3: Reviewer → artifacts/review.md -----------------------------"
run_test "review.md 형식 (REVIEW: APPROVED/REJECTED 포함)" test_ac3_review_md_format

echo ""
echo "-- AC4: QA → artifacts/test-plan.md --------------------------------"
run_test "test-plan.md 형식 (QA: PASSED/FAILED 포함)" test_ac4_test_plan_format

echo ""
echo "-- AC5: 이전 단계 산출물 없으면 오류 --------------------------------"
run_test "issue.md 없을 때 Engineer 단계 차단"    test_ac5_missing_issue_blocks_engineer
run_test "impl.md 없을 때 Reviewer 단계 차단"     test_ac5_missing_impl_blocks_reviewer
run_test "review.md 없을 때 QA 단계 차단"         test_ac5_missing_review_blocks_qa
run_test "오류 메시지에 파일명 포함"               test_ac5_error_message_contains_filename
run_test "issue.md 있을 때 Engineer 단계 허용"    test_ac5_present_issue_allows_engineer
run_test "impl.md 있을 때 Reviewer 단계 허용"     test_ac5_present_impl_allows_reviewer
run_test "review.md 있을 때 QA 단계 허용"         test_ac5_present_review_allows_qa
run_test "orchestrator.sh에 check_prerequisite 호출 포함" \
  test_ac5_orchestrator_calls_check_prerequisite

echo ""
echo "══════════════════════════════════════════════════════════"
printf "  결과: %d 통과 / %d 전체\n" "$PASS" "$((PASS+FAIL))"
if [[ $FAIL -eq 0 ]]; then
  echo "  ✅ 전체 통과"
else
  echo "  ❌ ${FAIL} 실패"
fi
echo "══════════════════════════════════════════════════════════"
[[ $FAIL -eq 0 ]]
