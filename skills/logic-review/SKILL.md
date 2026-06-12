---
name: logic-review
description: Use when reviewing a plan, design, proposal, or idea for logical soundness. Invoke to check internal consistency, surface hidden assumptions, find counter-arguments, and verify that context and conclusions actually align.
---

# Logic Review

A critical reasoning review focused on logical coherence. Not a style check — a structural audit. The goal is to find where the logic breaks before you commit.

## When to Use

- Before finalizing a design or architecture decision
- After writing a plan or proposal
- When something "feels off" but you can't name why
- When you want to stress-test your own reasoning

## Four Checks

### 1. Internal Consistency
Does every part of the plan agree with every other part?

- Do stated goals match proposed actions?
- Do constraints conflict with each other?
- If A requires B, is B actually provided?
- Are there any "and also" clauses that contradict each other?

**Output:** List each inconsistency as: `[Claim A] conflicts with [Claim B] because [reason]`

### 2. Assumption Audit
What is being taken for granted that hasn't been validated?

- What must be true for this plan to work?
- Which assumptions are load-bearing (plan fails if wrong)?
- Which assumptions have no evidence?
- What is conspicuously NOT mentioned?

**Output:** For each assumption: `[Assumption] — load-bearing? [yes/no] — evidence? [yes/no]`

### 3. Context-Logic Alignment
Does the reasoning fit the actual situation?

- Does the solution address the real problem, or a proxy?
- Are examples representative of the actual context?
- Are there conditions in the environment that make this logic invalid?
- Does the conclusion follow from the stated context, or from unstated background assumptions?

**Output:** Flag any place where the logic would only hold in a different context.

### 4. Counter-Argument Search
What is the strongest case against this?

- What would a skeptic say?
- Under what conditions does this approach fail?
- What evidence would falsify the main claim?
- What's the best competing approach, and why was it rejected?

**Output:** State the 2-3 strongest counter-arguments. Do not soften them.

## Review Format

```
## Logic Review

### Verdict
[SOUND / WEAK / BROKEN] — one sentence summary

### Inconsistencies
- [none] or list

### Unvalidated Assumptions
- [Assumption] | load-bearing: yes/no | evidence: yes/no

### Context Gaps
- [none] or list

### Counter-Arguments
1. [Strongest objection]
2. [Second objection]
3. [Third, if applicable]

### Recommendation

**Option A: [approach name]**
- What you gain: ...
- What you lose: ...

**Option B: [approach name]**
- What you gain: ...
- What you lose: ...

[If only one option makes sense, still list what you give up by choosing it.]
```

## Constraints

- Do not soften findings to be polite. The user asked for this review.
- If the logic is sound, say so clearly — don't invent problems.
- Prioritize load-bearing weaknesses over cosmetic ones.
- Always present options, not a single answer — even if one is clearly better.
- Every option MUST have its own trade-off (gain / lose). Never list an option without both sides.
