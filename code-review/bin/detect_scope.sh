#!/usr/bin/env bash
set -euo pipefail

# Usage: detect_scope.sh <base_branch>
# Reads: /tmp/code-review/changed_files.txt, diff_total.txt
# Writes: /tmp/code-review/context.json, review_plan.json
# Prints: scope flags and review plan summary

BASE="${1:?BASE_BRANCH required}"
OUTDIR="/tmp/code-review"

CHANGED_FILES=$(cat "$OUTDIR/changed_files.txt")
DIFF_TOTAL=$(cat "$OUTDIR/diff_total.txt")

# Stack detection
STACK=""
[ -f Gemfile ]                                         && STACK="${STACK}ruby "
[ -f package.json ]                                    && STACK="${STACK}node "
{ [ -f requirements.txt ] || [ -f pyproject.toml ]; } && STACK="${STACK}python "
[ -f go.mod ]                                          && STACK="${STACK}go "
[ -f Cargo.toml ]                                      && STACK="${STACK}rust "
{ [ -f pom.xml ] || [ -f build.gradle ]; }             && STACK="${STACK}java "

# Scope flags
sc() { echo "$CHANGED_FILES" | grep -qiE "$1" && echo 1 || echo 0; }

SCOPE_AUTH=$(sc        '(auth|login|session|token|permission|role|oauth|jwt)')
SCOPE_MIGRATIONS=$(sc  '(migration|schema\.rb|\.sql|alembic|flyway|db/migrate)')
SCOPE_API=$(sc         '(controller|route|endpoint|serializer|openapi|swagger|graphql|api)')
SCOPE_FRONTEND=$(sc    '(\.(jsx|tsx|vue|svelte|html|css|scss)|frontend|client|ui/)')
SCOPE_BACKEND=$(sc     '(\.(rb|py|go|java|ts|rs)|service|model|job|worker|handler)')
SCOPE_PERSISTENCE=$(sc '(repo|repository|model|dao|query|sql|db/|persistence|store)')
SCOPE_CONCURRENCY=$(sc '(job|worker|queue|lock|mutex|transaction|state|transition|retry)')
SCOPE_CICD=$(sc        '(\.github/workflows|dockerfile|docker-compose|helm|k8s|terraform|atlantis|ci|cd|release|deploy)')
SCOPE_LLM_BOUNDARY=$(sc '(llm|prompt|agent|openai|anthropic|tool|mcp|vector|rag)')
SCOPE_SHELL_EXEC=$(sc  '(subprocess|shell|exec|command|bash|sh|terminal)')
SCOPE_CONTRACT=$(sc    '(serializer|dto|openapi|swagger|graphql|api|contract|schema)')

# Hot path signal (for performance gating)
HOT_PATH=$(sc '(route|controller|view|serializer|query|service)')

# Risk level
RISK="LOW"

LLM_HIGH=0
if [ "$SCOPE_LLM_BOUNDARY" = "1" ] && { [ "$SCOPE_AUTH" = "1" ] || [ "$SCOPE_PERSISTENCE" = "1" ] || [ "$SCOPE_SHELL_EXEC" = "1" ] || [ "$DIFF_TOTAL" -gt 20 ]; }; then
  LLM_HIGH=1
fi

if [ "$SCOPE_AUTH" = "1" ] || \
   [ "$SCOPE_MIGRATIONS" = "1" ] || \
   [ "$SCOPE_CICD" = "1" ] || \
   [ "$SCOPE_SHELL_EXEC" = "1" ] || \
   [ "$LLM_HIGH" = "1" ]; then
  RISK="HIGH"
elif [ "$SCOPE_BACKEND" = "1" ] || \
     [ "$SCOPE_API" = "1" ] || \
     [ "$SCOPE_PERSISTENCE" = "1" ] || \
     [ "$SCOPE_CONCURRENCY" = "1" ] || \
     [ "$SCOPE_CONTRACT" = "1" ] || \
     [ "$SCOPE_FRONTEND" = "1" ] || \
     [ "$SCOPE_LLM_BOUNDARY" = "1" ]; then
  RISK="MEDIUM"
fi

# Very tiny rule
VERY_TINY=0
if [ "$DIFF_TOTAL" -lt 15 ] && \
   [ "$SCOPE_AUTH" = "0" ] && \
   [ "$SCOPE_PERSISTENCE" = "0" ] && \
   [ "$SCOPE_MIGRATIONS" = "0" ] && \
   [ "$SCOPE_CICD" = "0" ] && \
   [ "$SCOPE_SHELL_EXEC" = "0" ] && \
   [ "$SCOPE_CONTRACT" = "0" ] && \
   [ "$SCOPE_LLM_BOUNDARY" = "0" ]; then
  VERY_TINY=1
fi

# MEDIUM_SHARP
MEDIUM_SHARP=0
if [ "$RISK" = "MEDIUM" ]; then
  if [ "$SCOPE_AUTH" = "1" ] || \
     [ "$SCOPE_PERSISTENCE" = "1" ] || \
     [ "$SCOPE_CONCURRENCY" = "1" ] || \
     [ "$SCOPE_CONTRACT" = "1" ] || \
     [ "$SCOPE_LLM_BOUNDARY" = "1" ] || \
     [ "$SCOPE_SHELL_EXEC" = "1" ] || \
     [ "$SCOPE_MIGRATIONS" = "1" ] || \
     [ "$DIFF_TOTAL" -ge 120 ]; then
    MEDIUM_SHARP=1
  fi
fi

# Specialist selection
SPECIALISTS=()

if [ "$VERY_TINY" = "0" ]; then
  # testing
  if [ "$SCOPE_BACKEND" = "1" ] || \
     [ "$SCOPE_FRONTEND" = "1" ] || \
     [ "$SCOPE_AUTH" = "1" ] || \
     [ "$SCOPE_CONTRACT" = "1" ] || \
     [ "$SCOPE_PERSISTENCE" = "1" ] || \
     [ "$SCOPE_CONCURRENCY" = "1" ]; then
    TESTS_TOUCHED=$(echo "$CHANGED_FILES" | grep -qiE '(test|spec|_test\.|\.test\.)' && echo 1 || echo 0)
    if [ "$SCOPE_AUTH" = "1" ] || \
       [ "$SCOPE_PERSISTENCE" = "1" ] || \
       [ "$SCOPE_CONTRACT" = "1" ] || \
       [ "$SCOPE_CONCURRENCY" = "1" ] || \
       [ "$TESTS_TOUCHED" = "1" ]; then
      SPECIALISTS+=("testing")
    fi
  fi

  # maintainability
  [ "$DIFF_TOTAL" -ge 80 ] && SPECIALISTS+=("maintainability")

  # security
  if [ "$SCOPE_AUTH" = "1" ] || \
     [ "$SCOPE_LLM_BOUNDARY" = "1" ] || \
     [ "$SCOPE_SHELL_EXEC" = "1" ] || \
     { [ "$SCOPE_BACKEND" = "1" ] && [ "$DIFF_TOTAL" -gt 100 ]; }; then
    SPECIALISTS+=("security")
  fi

  # performance
  if { [ "$SCOPE_BACKEND" = "1" ] || [ "$SCOPE_FRONTEND" = "1" ]; } && \
     [ "$DIFF_TOTAL" -ge 80 ] && \
     [ "$HOT_PATH" = "1" ]; then
    SPECIALISTS+=("performance")
  fi

  [ "$SCOPE_MIGRATIONS" = "1" ] && SPECIALISTS+=("data-migration")
  { [ "$SCOPE_API" = "1" ] || [ "$SCOPE_CONTRACT" = "1" ]; } && SPECIALISTS+=("api-contract")
fi

# Red team
RUN_RED_TEAM=0
if [ "$RISK" = "HIGH" ] || [ "$MEDIUM_SHARP" = "1" ]; then
  RUN_RED_TEAM=1
elif [ "$RISK" = "MEDIUM" ] && [ "$VERY_TINY" = "0" ]; then
  if [ "$SCOPE_BACKEND" = "1" ] || [ "$SCOPE_FRONTEND" = "1" ]; then
    RUN_RED_TEAM=1
  fi
fi

# Second opinion
RUN_SECOND_OPINION=0
RUN_SECOND_OPINION_ADVERSARIAL=0
SECOND_OPINION_MODE="none"
SECOND_OPINION_TOOL_REQUIRED=0

if [ "$RISK" = "HIGH" ]; then
  RUN_SECOND_OPINION=1
  RUN_SECOND_OPINION_ADVERSARIAL=1
  SECOND_OPINION_MODE="structured+adversarial"
  SECOND_OPINION_TOOL_REQUIRED=1
elif [ "$MEDIUM_SHARP" = "1" ]; then
  RUN_SECOND_OPINION=1
  SECOND_OPINION_MODE="structured"
  SECOND_OPINION_TOOL_REQUIRED=1
elif [ "$RISK" = "MEDIUM" ]; then
  SECOND_OPINION_MODE="offer-if-findings"
fi

# Build specialists JSON array
SPEC_JSON="["
for i in "${!SPECIALISTS[@]}"; do
  [ $i -gt 0 ] && SPEC_JSON+=","
  SPEC_JSON+="\"${SPECIALISTS[$i]}\""
done
SPEC_JSON+="]"

# Write context.json
cat > "$OUTDIR/context.json" <<EOF
{
  "base_branch": "$BASE",
  "stack": "${STACK:-unknown}",
  "diff_total": $DIFF_TOTAL,
  "risk": "$RISK",
  "medium_sharp": $([ "$MEDIUM_SHARP" = "1" ] && echo true || echo false),
  "very_tiny": $([ "$VERY_TINY" = "1" ] && echo true || echo false),
  "scope": {
    "auth": $SCOPE_AUTH,
    "migrations": $SCOPE_MIGRATIONS,
    "api": $SCOPE_API,
    "frontend": $SCOPE_FRONTEND,
    "backend": $SCOPE_BACKEND,
    "persistence": $SCOPE_PERSISTENCE,
    "concurrency": $SCOPE_CONCURRENCY,
    "cicd": $SCOPE_CICD,
    "llm_boundary": $SCOPE_LLM_BOUNDARY,
    "shell_exec": $SCOPE_SHELL_EXEC,
    "contract": $SCOPE_CONTRACT
  }
}
EOF

# Write review_plan.json
cat > "$OUTDIR/review_plan.json" <<EOF
{
  "risk": "$RISK",
  "medium_sharp": $([ "$MEDIUM_SHARP" = "1" ] && echo true || echo false),
  "very_tiny": $([ "$VERY_TINY" = "1" ] && echo true || echo false),
  "run_specialists": $SPEC_JSON,
  "run_red_team": $([ "$RUN_RED_TEAM" = "1" ] && echo true || echo false),
  "run_second_opinion": $([ "$RUN_SECOND_OPINION" = "1" ] && echo true || echo false),
  "run_second_opinion_adversarial": $([ "$RUN_SECOND_OPINION_ADVERSARIAL" = "1" ] && echo true || echo false),
  "second_opinion_mode": "$SECOND_OPINION_MODE",
  "second_opinion_tool_required": $([ "$SECOND_OPINION_TOOL_REQUIRED" = "1" ] && echo true || echo false)
}
EOF

# Debug to stderr only
>&2 echo "STACK: ${STACK:-unknown}"
>&2 echo "SCOPE: AUTH=$SCOPE_AUTH MIGRATIONS=$SCOPE_MIGRATIONS API=$SCOPE_API FRONTEND=$SCOPE_FRONTEND BACKEND=$SCOPE_BACKEND PERSISTENCE=$SCOPE_PERSISTENCE CONCURRENCY=$SCOPE_CONCURRENCY CICD=$SCOPE_CICD LLM_BOUNDARY=$SCOPE_LLM_BOUNDARY SHELL_EXEC=$SCOPE_SHELL_EXEC CONTRACT=$SCOPE_CONTRACT"
>&2 echo "DIFF_TOTAL: $DIFF_TOTAL"

# Eval-safe exports on stdout
echo "RISK=$RISK"
echo "MEDIUM_SHARP=$MEDIUM_SHARP"
echo "VERY_TINY=$VERY_TINY"
echo "SPECIALISTS=\"${SPECIALISTS[*]:-none}\""
echo "RUN_RED_TEAM=$RUN_RED_TEAM"
echo "SECOND_OPINION_MODE=$SECOND_OPINION_MODE"
echo "SECOND_OPINION_TOOL_REQUIRED=$SECOND_OPINION_TOOL_REQUIRED"
echo "REVIEW_PLAN=$OUTDIR/review_plan.json"