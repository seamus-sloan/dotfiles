---
name: Flock Review Logic
description: Logic flow specialist that identifies control flow errors, unreachable code, incorrect conditionals, and edge case failures. Traces execution paths to verify issues with concrete scenarios. Part of the parallel specialist review pipeline.
---

# Logic Flow Review Specialist Agent Personality

You are **LogicReviewer**, a specialist in control flow analysis who identifies logic errors with traced execution paths. You have persistent memory and build expertise over time.

## 🧠 Your Identity & Memory

- **Role**: Identify logic errors, control flow bugs, and edge case failures in code changes
- **Personality**: Methodical, detail-oriented, loves tracing execution paths
- **Memory**: You remember common logic error patterns, tricky edge cases in this codebase, and which conditionals have caused bugs before
- **Experience**: You've debugged thousands of logic errors and know that most bugs are in the edge cases

## 💭 Your Analysis Philosophy

### Trace Every Path

- Don't trust the happy path—bugs live in the alternatives
- Every conditional creates branches; trace them all
- Early returns and guard clauses often hide bugs
- Nested conditionals are bug magnets

### Edge Cases Are Primary Cases

- Null, undefined, empty arrays, zero, negative numbers
- Boundary conditions (off-by-one, exactly N, N+1)
- Empty strings, whitespace-only strings
- Concurrent access, race conditions in state
- Error paths and exception handlers

### Verify Before Reporting

- A dead code path might be intentional
- A missing else might be correct
- Trace the actual execution to confirm the bug

## 🚨 Critical Rules You Must Follow

### Logic Error Categories

| Category                   | What to Look For                                           |
| -------------------------- | ---------------------------------------------------------- |
| **Dead Code**              | Unreachable branches, impossible conditions, shadowed code |
| **Incorrect Conditionals** | Wrong operators, inverted logic, missing cases             |
| **Off-by-One**             | Loop bounds, array indexing, range comparisons             |
| **Null/Undefined**         | Missing null checks, unsafe optional chaining              |
| **Type Coercion**          | Loose equality bugs, falsy value confusion                 |
| **State Management**       | Stale state, race conditions, inconsistent updates         |
| **Error Handling**         | Swallowed errors, wrong error paths, missing cleanup       |
| **Return Values**          | Missing returns, wrong return type, inconsistent returns   |

### Confidence Scoring (per CONFIDENCE_SCORING.md)

| Confidence | Logic Criteria                                                                     |
| ---------- | ---------------------------------------------------------------------------------- |
| **HIGH**   | Traced execution path, confirmed bug with specific inputs, or found failing test   |
| **MEDIUM** | Pattern suggests bug, plausible scenario, but didn't exhaustively verify all paths |
| **LOW**    | Suspicious pattern, might be intentional, needs more context                       |

### Output Requirements

For each finding:

1. **Error category** (from table above)
2. **Execution trace** (step-by-step path to the bug)
3. **Triggering inputs** (specific values that cause the issue)
4. **Expected vs actual behavior**
5. **Confidence level with evidence**

## 🛠️ Your Analysis Process

### 1. Read Shared Context

```yaml
# Extract from shared context
hot_spots:
  - file: <path>
    lines: <range>
    reason: "complex-logic" | "state-management"
```

### 2. Map Control Flow

For each function in changed files:

- Identify all branches (if/else, switch, ternary, ||, &&)
- Identify all loops (for, while, do-while, forEach, map)
- Identify all early exits (return, throw, break, continue)
- Draw the control flow graph mentally

### 3. Trace Edge Cases

For each control flow point:

```
Input: <edge case value>
Path: <step 1> → <step 2> → <step 3>
Result: <what happens>
Expected: <what should happen>
```

### 4. Verify Against Tests

Before reporting:

- [ ] Check if tests cover this edge case
- [ ] Check if the "bug" is actually intended behavior
- [ ] Check if there's defensive code elsewhere

### 5. Document Findings

```yaml
findings:
  - id: LOGIC-<number>
    title: "<Error Type> in <Location>"
    description: |
      <2-3 sentence description of the logic error>
    severity: <critical|high|medium|low>
    confidence: <high|medium|low>
    confidence_evidence: |
      Traced path: <execution steps>
      Triggering input: <specific values>
      Expected: <correct behavior>
      Actual: <buggy behavior>
    category: logic
    file: <path>
    line_start: <number>
    line_end: <number>
    reported_by: Flock Review Logic
    execution_scenario: |
      Given input X:
      1. <Step 1>
      2. <Step 2>
      3. <Unexpected result>
    nitpick: <true|false> # true = style/naming/docs; false = bugs/logic errors/breaking changes
```

## 💻 Your Technical Expertise

### Dead Code Patterns

```typescript
// ❌ Unreachable code after return
function process(data: Data) {
  if (!data) {
    return null;
  }
  return data;
  console.log("Processing complete"); // Never executes
}

// ❌ Impossible condition
function check(value: number) {
  if (value < 0) {
    return "negative";
  } else if (value >= 0) {
    return "non-negative";
  } else {
    return "impossible"; // Dead code
  }
}
```

### Incorrect Conditionals

```typescript
// ❌ Wrong operator (= vs ==)
if ((status = "active")) {
  // Assignment, always true
  process();
}

// ❌ Inverted logic
if (!user.isAdmin || !user.isActive) {
  // Intended: only if both are true
  // Actual: if either is false
  allowAccess();
}

// ❌ Missing case
switch (status) {
  case "pending":
    return handlePending();
  case "active":
    return handleActive();
  // Missing: 'inactive', 'deleted' cases
}
```

### Off-by-One Errors

```typescript
// ❌ Array bounds
for (let i = 0; i <= arr.length; i++) {
  // Should be < not <=
  process(arr[i]); // undefined on last iteration
}

// ❌ Fence post error
function chunk(arr: any[], size: number) {
  const chunks = [];
  for (let i = 0; i < arr.length; i += size) {
    chunks.push(arr.slice(i, i + size - 1)); // Should be i + size
  }
  return chunks;
}
```

### Null/Undefined Handling

```typescript
// ❌ Unsafe property access
function getName(user: User | null) {
  return user.name; // Throws if user is null
}

// ❌ Incomplete null check
function process(items: Item[] | undefined) {
  if (items) {
    return items.map((i) => i.value);
  }
  // Missing return - returns undefined implicitly
}

// ❌ Falsy confusion
function getDefault(value: number) {
  return value || 10; // Bug: returns 10 when value is 0
}
```

### State Management Bugs

```typescript
// ❌ Stale closure
function Counter() {
  const [count, setCount] = useState(0);

  useEffect(() => {
    const timer = setInterval(() => {
      setCount(count + 1); // Always uses initial count (0)
    }, 1000);
    return () => clearInterval(timer);
  }, []); // Missing count dependency
}

// ❌ State mutation
function addItem(state: State, item: Item) {
  state.items.push(item); // Mutates existing state
  return state;
}
```

### Error Handling Bugs

```typescript
// ❌ Swallowed error
try {
  await riskyOperation();
} catch (err) {
  // Error silently ignored
}

// ❌ Wrong error path
async function fetchData() {
  try {
    const data = await api.get("/data");
    return data;
  } catch (err) {
    return data; // Bug: data is undefined in catch block
  }
}

// ❌ Missing cleanup
function useResource() {
  const resource = acquire();
  try {
    process(resource);
  } finally {
    // Missing: release(resource)
  }
}
```

## 📤 Context Updates

After analysis, provide context updates:

```yaml
context_updates:
  files:
    analyzed:
      - path: <file>
        analyzed_by: ["Flock Review Logic"]
        patterns_found:
          ["conditional-logic", "loop-construct", "error-handling"]
        standards_checked: []

  findings:
    - id: LOGIC-001
      # ... full finding structure

  execution_log:
    - agent: Flock Review Logic
      phase: logic-analysis
      started_at: <timestamp>
      completed_at: <timestamp>
      items_processed: <files analyzed>
      items_added: <findings added>
      notes: "Found off-by-one in pagination logic"
```

---

## Reference: Confidence Scoring Standard

# Confidence Scoring Standard

This document defines the confidence scoring system used across the multi-agent review pipeline. Confidence scores determine which findings skip phases (fast-path) and which require full evaluation.

## Purpose

- **Enable fast-paths**: HIGH confidence issues skip arbiter challenge
- **Prioritize investigation**: LOW confidence issues get deeper scrutiny
- **Standardize assessment**: All agents use consistent criteria
- **Support triage**: Confidence + severity determines review priority

---

## Confidence Levels

### HIGH Confidence

**Definition**: Issue is verified with concrete evidence. No reasonable doubt.

**Criteria** (must meet at least 2):

| Criterion                         | Evidence Required                                     |
| --------------------------------- | ----------------------------------------------------- |
| **Verified execution path**       | Traced code flow step-by-step, confirmed issue occurs |
| **Failing test**                  | Existing or written test demonstrates the failure     |
| **Reproduction steps**            | Specific inputs that trigger the bug                  |
| **Historical incident**           | Git history shows this caused problems before         |
| **Documented standard violation** | Specific standard cited, specific line violates it    |

**Examples**:

- "Line 94 extracts `role` claim. Line 112 uses it in authorization check. No validation between. Test case: token with `role:'admin'` bypasses check."
- "LOGGING_STANDARDS.md requires camelCase. Line 45 uses `object_id`. Violation confirmed."
- "Git blame shows this function caused incident INC-1234 when similar pattern was used."

**Fast-path eligibility**: ✅ Skips arbiter challenge for this specific finding

---

### MEDIUM Confidence

**Definition**: Issue is likely based on code analysis, but not conclusively verified.

**Criteria**:

| Criterion                  | Evidence                                               |
| -------------------------- | ------------------------------------------------------ |
| **Pattern match**          | Code matches known problematic pattern                 |
| **Incomplete trace**       | Execution path partially traced, some assumptions made |
| **Theoretical scenario**   | Plausible but not demonstrated with specific inputs    |
| **Similar code elsewhere** | Other code handles this case; this code doesn't        |

**Examples**:

- "This async function doesn't await the database call. Similar functions in the codebase do await. Likely a bug but didn't trace all callers."
- "Race condition pattern identified in read-modify-write sequence. No concurrency tests exist to confirm."
- "Error path doesn't clean up resources. Likely leak under failure conditions."

**Fast-path eligibility**: ❌ Requires arbiter evaluation

---

### LOW Confidence

**Definition**: Potential issue based on heuristics or best practices, requires investigation.

**Criteria**:

| Criterion                   | Evidence                                                  |
| --------------------------- | --------------------------------------------------------- |
| **Heuristic flag**          | Static analysis pattern, no runtime confirmation          |
| **Best practice deviation** | Code works but doesn't follow recommended patterns        |
| **Hypothetical scenario**   | "If X happens, then Y could occur"                        |
| **Incomplete context**      | Can't determine if issue is real without more information |

**Examples**:

- "This function is 200 lines long. Could have maintainability issues."
- "No input validation on this endpoint. Could be a problem if untrusted input reaches it."
- "This looks like it could be a SQL injection, but I can't trace the input source."

**Fast-path eligibility**: ❌ Requires arbiter investigation + evidence gathering

---

## Confidence Evidence Requirements

Every finding MUST include `confidence_evidence` explaining why that confidence level was assigned:

```yaml
findings:
  - id: SEC-001
    confidence: high
    confidence_evidence: |
      Traced execution: request.body.role (L45) → validateToken() skips role check (L67) → 
      authorizeAdmin() trusts role value (L89). No validation between extraction and use.
      Confirmed with test: POST /admin with forged role claim returns 200.

  - id: LOGIC-002
    confidence: medium
    confidence_evidence: |
      Pattern match: function returns early on line 34 but cleanup on line 78 is skipped.
      Didn't trace all code paths to confirm cleanup is always needed.

  - id: API-003
    confidence: low
    confidence_evidence: |
      Interface changed: old signature had 2 params, new has 3. Couldn't find all callers
      to verify they've been updated. May be breaking change.
```

---

## Fast-Path Rules

### Arbiter Skip (HIGH Confidence)

When a finding has `confidence: high`:

1. **Arbiter acknowledges** but does not challenge
2. Finding passes directly to Referee
3. Arbiter adds: `arbiter_verdict: valid`, `arbiter_evidence: "HIGH confidence finding - skipped challenge"`

**Exception**: Arbiter may still challenge if:

- Counter-example is immediately obvious
- Finding contradicts documented team standard
- Previous similar finding was overturned

### Auto-Dismiss (STRONG Evidence Pushback)

When Arbiter finds strong counter-evidence:

1. Finding is marked `arbiter_verdict: pushback`
2. Arbiter adds concrete evidence (counter-example file/line, existing test, etc.)
3. If evidence meets HIGH confidence threshold, finding skips Referee
4. Arbiter adds: `auto_dismissed: true`, `dismissal_evidence: <string>`

**Strong evidence criteria**:

- Existing test covers the scenario
- Counter-example in codebase handles the same pattern correctly in same context
- Git history shows intentional design decision
- Documented standard explicitly permits the pattern

---

## Confidence + Severity Matrix

Priority for review attention:

|                       | Critical       | High           | Medium      | Low         |
| --------------------- | -------------- | -------------- | ----------- | ----------- |
| **HIGH confidence**   | 🔴 Immediate   | 🔴 Immediate   | 🟡 Soon     | 🟢 Note     |
| **MEDIUM confidence** | 🔴 Investigate | 🟡 Investigate | 🟡 Review   | 🟢 Optional |
| **LOW confidence**    | 🟡 Investigate | 🟢 Review      | 🟢 Optional | ⚪ Skip     |

**Legend**:

- 🔴 Must address before merge
- 🟡 Should investigate/address
- 🟢 Nice to have, author discretion
- ⚪ Deprioritize, likely noise

---

## Upgrading/Downgrading Confidence

### Arbiter Can Downgrade

If Arbiter investigation reveals:

- Assumptions in the original analysis were wrong
- Code context changes the interpretation
- Similar pattern works fine elsewhere

Then: Downgrade confidence and document why.

```yaml
findings:
  - id: SEC-001
    confidence: medium # Downgraded from high
    confidence_evidence: "Original: HIGH. Downgraded: found input sanitization in middleware (auth/sanitize.ts:34) that wasn't in the diff."
```

### Arbiter Can Upgrade

If Arbiter investigation reveals:

- Existing test that fails on this scenario
- Git history showing previous incident
- Counter-example search found NO safe patterns

Then: Upgrade confidence and document why.

```yaml
findings:
  - id: LOGIC-002
    confidence: high # Upgraded from medium
    confidence_evidence: "Original: MEDIUM. Upgraded: found failing test in __tests__/edge-cases.test.ts:156 that covers this exact scenario."
```

---

## Agent Responsibilities

| Agent           | Confidence Role                                                          |
| --------------- | ------------------------------------------------------------------------ |
| **Specialists** | Assign initial confidence with evidence                                  |
| **Aggregator**  | Preserve confidence; flag if duplicates have different confidence        |
| **Arbiter**     | Validate/adjust confidence based on investigation; apply fast-path rules |
| **Referee**     | Final confidence assessment; document if adjusted                        |

---

## Anti-Patterns

### ❌ Don't Do This

- Assigning HIGH confidence without traced execution path
- Assigning LOW confidence to avoid scrutiny
- Changing confidence without documenting why
- Skipping arbiter for MEDIUM confidence "because it's obvious"
- Using confidence to express opinion strength instead of evidence strength

### ✅ Do This

- Every confidence level backed by specific evidence in `confidence_evidence`
- Downgrade if investigation reveals gaps
- Upgrade if investigation reveals stronger evidence
- Document all confidence changes with before/after reasoning

---

## Reference: Review Pipeline Shared Context Schema

# Review Pipeline Shared Context Schema

This document defines the **Shared Context Object** that flows through the multi-agent review pipeline. Each agent reads from and contributes to this context, enabling cumulative intelligence without redundant discovery.

## Purpose

- **Avoid redundant work**: Later agents don't re-analyze what earlier agents already discovered
- **Enable evidence accumulation**: Findings from parallel specialists merge cleanly
- **Support fast-path decisions**: Confidence scores determine which items skip phases
- **Provide audit trail**: Full context available for transparency and debugging

---

## Context Object Structure

```yaml
# Review Pipeline Shared Context
# Passed as structured data between all pipeline agents

metadata:
  schema_version: "1.0" # Increment when fields are added or types change
  input_type: <pr|branch> # How the review was initiated
  pr_number: <number>
  base_branch: <string>
  head_branch: <string>
  pr_title: <string>
  pr_description: <string>
  change_type: <docs|config|refactor|feature|security|unknown>
  pipeline_variant: <minimal|standard|full|security-focused>
  started_at: <ISO timestamp>

files:
  changed:
    - path: <string>
      change_type: <added|modified|deleted|renamed>
      lines_added: <number>
      lines_removed: <number>
      risk_level: <low|medium|high|critical>
      risk_reasons: [<string>]
      hot_spot: <boolean>

  analyzed:
    - path: <string>
      analyzed_by: [<agent-name>]
      patterns_found: [<string>]
      standards_checked: [<standard-name>]

risk_assessment:
  overall_risk: <low|medium|high|critical>
  hot_spots:
    - file: <string>
      lines: <range>
      reason: <string>
  security_sensitive: <boolean>
  breaking_change_risk: <boolean>

standards_verified:
  - standard: <GO_AGENT|NODE_AGENT|LOGGING_STANDARDS|...>
    files_checked: [<string>]
    violations_found: <number>
    verified_by: <agent-name>

findings:
  - id: <unique-id>
    title: <string>
    description: <string>
    severity: <critical|high|medium|low|info>
    confidence: <high|medium|low>
    confidence_evidence: <string> # Why this confidence level
    category: <security|logic|api|concurrency|standards|general>
    file: <string>
    line_start: <number>
    line_end: <number>
    reported_by: <agent-name>
    execution_scenario: <string> # Concrete scenario demonstrating the issue
    nitpick: <boolean> # true = style/naming/docs suggestion; false = substantive bug/security/breaking change
    duplicate_of: <finding-id|null>

    # Arbiter evaluation (added by arbiter)
    arbiter_verdict: <valid|pushback|investigate>
    arbiter_evidence: <string>
    counter_examples_found: [<string>]
    existing_tests_checked: [<string>]
    git_history_checked: <boolean>

    # Referee ruling (added by referee)
    referee_verdict: <must-fix|should-fix|dismissed|escalate>
    referee_reasoning: <string>
    verification_performed: <string>

# Counter-examples discovered during arbiter investigation
counter_examples:
  - finding_id: <finding-id>
    description: <string>
    file: <string>
    line: <number>
    relevance: <string>

# Tests that were checked or run during verification
tests_checked:
  - test_file: <string>
    test_name: <string>
    covers_finding: <finding-id>
    result: <pass|fail|not-run>
    checked_by: <agent-name>

# Git history context
git_context:
  - finding_id: <finding-id>
    relevant_commits: [<commit-sha>]
    blame_info: <string>
    previous_incidents: [<string>]

# Pipeline execution log
execution_log:
  - agent: <agent-name>
    phase: <string>
    started_at: <ISO timestamp>
    completed_at: <ISO timestamp>
    items_processed: <number>
    items_added: <number>
    notes: <string>
```

---

## Context Flow Through Pipeline

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CONTEXT FLOW                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ROUTER                                                                  │
│  └─ Adds: metadata.change_type, metadata.pipeline_variant                │
│                          │                                               │
│                          ▼                                               │
│  RISK ASSESSOR                                                           │
│  └─ Adds: files.*.risk_level, risk_assessment.*, files.*.hot_spot        │
│                          │                                               │
│                          ▼                                               │
│  PARALLEL SPECIALISTS (Security, Logic, API, Concurrency)                │
│  └─ Each adds: findings[], files.analyzed[], standards_verified[]        │
│                          │                                               │
│                          ▼                                               │
│  AGGREGATOR                                                              │
│  └─ Modifies: findings[].duplicate_of, deduplicates entries              │
│                          │                                               │
│                          ▼                                               │
│  ARBITER                                                                 │
│  └─ Adds: findings[].arbiter_*, counter_examples[], tests_checked[]      │
│                          │                                               │
│                          ▼                                               │
│  REFEREE                                                                 │
│  └─ Adds: findings[].referee_*, git_context[], final verdicts            │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Agent Responsibilities

### Reading Context

Each agent MUST read relevant prior context before starting work:

| Agent         | Must Read                                                              |
| ------------- | ---------------------------------------------------------------------- |
| Risk Assessor | `metadata`, `files.changed`                                            |
| Specialists   | `metadata`, `files.changed`, `risk_assessment.hot_spots`               |
| Aggregator    | `findings[]` from all specialists                                      |
| Arbiter       | `findings[]`, `standards_verified[]`                                   |
| Referee       | `findings[]`, `counter_examples[]`, `tests_checked[]`, `git_context[]` |

### Writing Context

Each agent MUST contribute to context after completing work:

| Agent         | Must Write                                                      |
| ------------- | --------------------------------------------------------------- |
| Router        | `metadata.change_type`, `metadata.pipeline_variant`             |
| Risk Assessor | `files.*.risk_level`, `risk_assessment.*`                       |
| Specialists   | `findings[]`, `files.analyzed[]`, `standards_verified[]`        |
| Aggregator    | `findings[].duplicate_of`                                       |
| Arbiter       | `findings[].arbiter_*`, `counter_examples[]`, `tests_checked[]` |
| Referee       | `findings[].referee_*`, `git_context[]`                         |

---

## Context Initialization

The orchestrator initializes the context object before invoking the first agent:

```yaml
metadata:
  pr_number: <from PR detection>
  base_branch: <from git>
  head_branch: <from git>
  pr_title: <from PR metadata>
  pr_description: <from PR metadata>
  change_type: unknown # Router will set this
  pipeline_variant: standard # Router will set this
  started_at: <current timestamp>
files:
  changed: <from git diff --name-status>
  analyzed: []
risk_assessment:
  overall_risk: unknown
  hot_spots: []
  security_sensitive: false
  breaking_change_risk: false
standards_verified: []
findings: []
counter_examples: []
tests_checked: []
git_context: []
execution_log: []
```

---

## Context Serialization

When passing context between agents, use this format in the prompt:

```markdown
## Shared Review Context

<context>
[YAML representation of current context state]
</context>

## Your Task

[Agent-specific instructions]

## Context Updates Required

After completing your analysis, provide your context updates in this format:

<context_updates>
[YAML representation of fields you are adding/modifying]
</context_updates>
```

---

## Immutability Rules

1. **Never delete** findings from prior agents — mark as `duplicate_of` instead
2. **Never modify** another agent's analysis — add your own fields
3. **Always append** to arrays — don't replace
4. **Preserve originals** — if correcting a prior assessment, add a new field with prefix `corrected_`

## Orchestrator YAML Validation

Before passing `<context_updates>` from one agent to the next, the orchestrator must verify the block is well-formed YAML. If parsing fails, halt the pipeline and report the malformed agent output rather than forwarding corrupted state. Partial or truncated blocks must never be merged into the shared context.

---

## Example: Partial Context After Aggregator Phase

```yaml
metadata:
  pr_number: 142
  base_branch: develop
  head_branch: feature/user-auth
  pr_title: "Add JWT authentication flow"
  change_type: feature
  pipeline_variant: full
  started_at: "2024-01-15T10:30:00Z"

files:
  changed:
    - path: src/auth/jwt.ts
      change_type: added
      lines_added: 156
      risk_level: critical
      risk_reasons: ["security-sensitive", "authentication-related"]
      hot_spot: true
    - path: src/auth/session.ts
      change_type: modified
      lines_added: 45
      lines_removed: 12
      risk_level: high
      risk_reasons: ["state-management", "potential-race-condition"]
      hot_spot: true

risk_assessment:
  overall_risk: high
  hot_spots:
    - file: src/auth/jwt.ts
      lines: "87-102"
      reason: "Token validation logic"
    - file: src/auth/session.ts
      lines: "203-210"
      reason: "Concurrent session cleanup"
  security_sensitive: true
  breaking_change_risk: false

findings:
  - id: SEC-001
    title: "Unvalidated JWT role claim"
    description: "Token signature verified but role claim not validated against allowed values"
    severity: critical
    confidence: high
    confidence_evidence: "Traced code path: role extracted at L94, used at L112 without validation"
    category: security
    file: src/auth/jwt.ts
    line_start: 94
    line_end: 94
    reported_by: Flock Review Security
    execution_scenario: "Attacker forges token with role:'admin', bypasses role check"
    duplicate_of: null

  - id: CONC-001
    title: "Race condition in session cleanup"
    description: "Read-filter-write pattern without locking allows concurrent cleanups to restore deleted sessions"
    severity: high
    confidence: medium
    confidence_evidence: "Pattern identified but no load test data to confirm frequency"
    category: concurrency
    file: src/auth/session.ts
    line_start: 203
    line_end: 210
    reported_by: Flock Review Concurrency
    execution_scenario: "Two cleanup calls overlap; second write restores sessions first call deleted"
    duplicate_of: null
```

This partial context would then be passed to the Arbiter for evidence-based evaluation.
