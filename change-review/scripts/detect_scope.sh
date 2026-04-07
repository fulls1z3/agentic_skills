#!/usr/bin/env bash
set -euo pipefail

# detect_scope.sh <base_branch>
# Reads: $ARTEFACTS_DIR/{changed_files.txt,diff_total.txt}
# Writes: $ARTEFACTS_DIR/review_plan.yaml — Emits: RISK, MEDIUM_SHARP

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "ERROR: Not inside a git repository" >&2; exit 1
}
cd "$REPO_ROOT"

BASE="${1:?BASE_BRANCH required}"
OUTDIR="${ARTEFACTS_DIR:?ARTEFACTS_DIR not set}"
[ -d "$OUTDIR" ] || { echo "ERROR: $OUTDIR does not exist" >&2; exit 1; }

REVIEW_MODE="${REVIEW_MODE:-full}"

CHANGED_FILES=$(cat "$OUTDIR/changed_files.txt")
DIFF_TOTAL=$(cat "$OUTDIR/diff_total.txt")
[[ "$DIFF_TOTAL" =~ ^[0-9]+$ ]] || { echo "ERROR: invalid DIFF_TOTAL" >&2; exit 1; }
FILE_COUNT=$(wc -l < "$OUTDIR/changed_files.txt" | tr -d ' ')
[[ "$FILE_COUNT" =~ ^[0-9]+$ ]] || FILE_COUNT=0

if [ "$REVIEW_MODE" = "incremental" ] && [ -s "$OUTDIR/incremental_changed_files.txt" ]; then
  SPECIALIST_FILES=$(cat "$OUTDIR/incremental_changed_files.txt")
else
  SPECIALIST_FILES="$CHANGED_FILES"
fi

sc()     { echo "$CHANGED_FILES"    | grep -qiE "$1" && echo 1 || echo 0; }
inc_sc() { echo "$SPECIALIST_FILES" | grep -qiE "$1" && echo 1 || echo 0; }

SCOPE_AUTH=$(sc        '(auth|login|session|token|permission|role|oauth|jwt)')
SCOPE_MIGRATIONS=$(sc  '(db/migrate|/migrations/|_migration\.|schema\.(rb|sql)|\.sql$|alembic|flyway|liquibase)')
SCOPE_API=$(sc         '(controller|route|endpoint|serializer|openapi|swagger|graphql|api)')
SCOPE_FRONTEND=$(sc    '(\.(jsx|tsx|vue|svelte|html|css|scss)|frontend|client|ui/)')
SCOPE_BACKEND=$(sc     '(\.(rb|py|go|java|ts|rs)|service|model|job|worker|handler)')
SCOPE_PERSISTENCE=$(sc '(repo|repository|model|dao|query|sql|db/|persistence|store)')
SCOPE_CONCURRENCY=$(sc '(job|worker|queue|lock|mutex|transaction|state|transition|retry)')
SCOPE_CICD=$(sc        '(\.github/workflows|\.circleci|\.gitlab-ci|\.travis\.yml|azure-pipelines|dockerfile|docker-compose|helm/|k8s/|kubernetes/|terraform|atlantis|release\.yml|deploy\.yml|pipeline\.yml)')
SCOPE_LLM_BOUNDARY=$(sc '(llm|prompt|agent|openai|anthropic|tool|mcp|vector|rag)')
SCOPE_SHELL_EXEC=$(sc  '(subprocess|shell|exec|command|bash|terminal)')
SCOPE_CONTRACT=$(sc    '(serializer|dto|openapi|swagger|graphql|api|contract|schema)')
SCOPE_API_SURFACE=$(sc '(openapi|swagger|graphql|\.proto$|/proto/|/api/v[0-9])')

RISK="LOW"
LLM_HIGH=0
if [ "$SCOPE_LLM_BOUNDARY" = "1" ] && { [ "$SCOPE_AUTH" = "1" ] || [ "$SCOPE_PERSISTENCE" = "1" ] || [ "$SCOPE_SHELL_EXEC" = "1" ] || [ "$DIFF_TOTAL" -gt 20 ]; }; then
  LLM_HIGH=1
fi

if [ "$SCOPE_AUTH" = "1" ] || [ "$SCOPE_MIGRATIONS" = "1" ] || [ "$SCOPE_CICD" = "1" ] || \
   [ "$SCOPE_SHELL_EXEC" = "1" ] || [ "$LLM_HIGH" = "1" ]; then
  RISK="HIGH"
elif [ "$SCOPE_BACKEND" = "1" ] || [ "$SCOPE_API" = "1" ] || [ "$SCOPE_PERSISTENCE" = "1" ] || \
     [ "$SCOPE_CONCURRENCY" = "1" ] || [ "$SCOPE_CONTRACT" = "1" ] || [ "$SCOPE_FRONTEND" = "1" ] || \
     [ "$SCOPE_LLM_BOUNDARY" = "1" ]; then
  RISK="MEDIUM"
fi

VERY_TINY=0
if [ "$DIFF_TOTAL" -lt 15 ] && [ "$SCOPE_AUTH" = "0" ] && [ "$SCOPE_PERSISTENCE" = "0" ] && \
   [ "$SCOPE_MIGRATIONS" = "0" ] && [ "$SCOPE_CICD" = "0" ] && [ "$SCOPE_SHELL_EXEC" = "0" ] && \
   [ "$SCOPE_CONTRACT" = "0" ] && [ "$SCOPE_LLM_BOUNDARY" = "0" ]; then
  VERY_TINY=1
fi

LARGE_PR=0
ORCHESTRATION_MODE="normal"
if [ "$DIFF_TOTAL" -ge 4000 ] || [ "$FILE_COUNT" -ge 40 ]; then
  LARGE_PR=1; ORCHESTRATION_MODE="large-pr"
fi

MEDIUM_SHARP=0
if [ "$RISK" = "MEDIUM" ]; then
  if [ "$SCOPE_AUTH" = "1" ] || [ "$SCOPE_PERSISTENCE" = "1" ] || [ "$SCOPE_CONCURRENCY" = "1" ] || \
     [ "$SCOPE_CONTRACT" = "1" ] || [ "$SCOPE_LLM_BOUNDARY" = "1" ] || [ "$SCOPE_SHELL_EXEC" = "1" ] || \
     [ "$SCOPE_MIGRATIONS" = "1" ] || [ "$DIFF_TOTAL" -ge 120 ]; then
    MEDIUM_SHARP=1
  fi
fi

_ISC_AUTH=$(inc_sc     '(auth|login|session|token|permission|role|oauth|jwt)')
_ISC_PERSIST=$(inc_sc  '(repo|repository|model|dao|query|sql|db/|persistence|store)')
_ISC_CONCUR=$(inc_sc   '(job|worker|queue|lock|mutex|transaction|state|transition|retry)')
_ISC_CONTRACT=$(inc_sc '(serializer|dto|openapi|swagger|graphql|api|contract|schema)')
_ISC_LLM=$(inc_sc      '(llm|prompt|agent|openai|anthropic|tool|mcp|vector|rag)')
_ISC_SHELL=$(inc_sc    '(subprocess|shell|exec|command|bash|terminal)')
_ISC_BACKEND=$(inc_sc  '(\.(rb|py|go|java|ts|rs)|service|model|job|worker|handler)')
_ISC_HOT=$(inc_sc      '(route|controller|view|serializer|query|service)')
_ISC_FRONTEND=$(inc_sc '(\.(jsx|tsx|vue|svelte|html|css|scss)|frontend|client|ui/)')
_ISC_MIGRATE=$(inc_sc  '(db/migrate|/migrations/|_migration\.|schema\.(rb|sql)|\.sql$|alembic|flyway|liquibase)')
_ISC_APISURFACE=$(inc_sc '(openapi|swagger|graphql|\.proto$|/proto/|/api/v[0-9])')
_ISC_ROUTE=$(inc_sc    '(controller|route|endpoint|serializer|openapi|swagger|graphql|api)')
_ISC_CICD=$(inc_sc     '(\.github/workflows|\.circleci|\.gitlab-ci|\.travis\.yml|azure-pipelines|dockerfile|docker-compose|helm/|k8s/|kubernetes/|terraform|atlantis|release\.yml|deploy\.yml|pipeline\.yml)')

SPECIALISTS=()

if [ "$VERY_TINY" = "0" ]; then
  if [ "$_ISC_AUTH" = "1" ] || [ "$_ISC_PERSIST" = "1" ] || [ "$_ISC_CONCUR" = "1" ] || [ "$_ISC_CONTRACT" = "1" ]; then
    SPECIALISTS+=("testing")
  fi
  if [ "$_ISC_AUTH" = "1" ] || [ "$_ISC_LLM" = "1" ] || [ "$_ISC_SHELL" = "1" ] || \
     { [ "$_ISC_BACKEND" = "1" ] && [ "$DIFF_TOTAL" -gt 100 ]; }; then
    SPECIALISTS+=("security")
  fi
  if { [ "$_ISC_BACKEND" = "1" ] || [ "$_ISC_FRONTEND" = "1" ]; } && \
     [ "$DIFF_TOTAL" -ge 100 ] && [ "$_ISC_HOT" = "1" ]; then
    SPECIALISTS+=("performance")
  fi
  [ "$_ISC_MIGRATE" = "1" ] && SPECIALISTS+=("data-migration")
  if [ "$_ISC_APISURFACE" = "1" ] || \
     { [ "$_ISC_CONTRACT" = "1" ] && [ "$_ISC_ROUTE" = "1" ] && [ "$DIFF_TOTAL" -ge 40 ]; }; then
    SPECIALISTS+=("api-contract")
  fi
  [ "$LARGE_PR" = "0" ] && [ "$DIFF_TOTAL" -ge 200 ] && SPECIALISTS+=("maintainability")
fi

# Cheap-lane testing fallback: non-trivial diff with no specialist signal
if [ "${#SPECIALISTS[@]}" -eq 0 ] && [ "$VERY_TINY" = "0" ] && \
   { [ "$_ISC_BACKEND" = "1" ] || [ "$_ISC_FRONTEND" = "1" ]; }; then
  SPECIALISTS+=("testing")
fi

if [ "$LARGE_PR" = "1" ]; then
  FILTERED=()
  for _s in ${SPECIALISTS[@]+"${SPECIALISTS[@]}"}; do
    case "$_s" in
      data-migration)  [ "$SCOPE_MIGRATIONS" = "1" ]  && FILTERED+=("$_s") || true ;;
      api-contract)    [ "$SCOPE_API_SURFACE" = "1" ] && FILTERED+=("$_s") || true ;;
      maintainability) true ;;
      *) FILTERED+=("$_s") ;;
    esac
  done
  SPECIALISTS=()
  [ "${#FILTERED[@]}" -gt 0 ] && SPECIALISTS=("${FILTERED[@]}")
fi

if [ "$LARGE_PR" = "1" ]; then
  [ "$RISK" = "HIGH" ] && SPECIALIST_CAP=2 || SPECIALIST_CAP=1
elif [ "$REVIEW_MODE" = "incremental" ]; then
  if [ "$RISK" = "HIGH" ]; then SPECIALIST_CAP=3
  elif [ "$MEDIUM_SHARP" = "1" ]; then SPECIALIST_CAP=2
  else SPECIALIST_CAP=1; fi
else
  if [ "$RISK" = "HIGH" ]; then SPECIALIST_CAP=5
  elif [ "$MEDIUM_SHARP" = "1" ]; then SPECIALIST_CAP=4
  else SPECIALIST_CAP=1; fi
fi

# Cheap lane (cap≤1) prefers testing; escalated prefers security
if [ "$SPECIALIST_CAP" -le 1 ]; then
  PRIORITY_ORDER=("testing" "security" "data-migration" "api-contract" "performance" "maintainability")
else
  PRIORITY_ORDER=("security" "testing" "data-migration" "api-contract" "performance" "maintainability")
fi

SPECIALISTS_CAPPED=()
for p in "${PRIORITY_ORDER[@]}"; do
  [ "${#SPECIALISTS_CAPPED[@]}" -ge "$SPECIALIST_CAP" ] && break
  for s in ${SPECIALISTS[@]+"${SPECIALISTS[@]}"}; do
    [ "$s" = "$p" ] && { SPECIALISTS_CAPPED+=("$s"); break; }
  done
done
SPECIALISTS=()
[ "${#SPECIALISTS_CAPPED[@]}" -gt 0 ] && SPECIALISTS=("${SPECIALISTS_CAPPED[@]}")

_RED_TEAM_SIGNAL=0
if [ "$_ISC_AUTH" = "1" ] || [ "$_ISC_MIGRATE" = "1" ] || [ "$_ISC_SHELL" = "1" ] || [ "$_ISC_CICD" = "1" ]; then
  _RED_TEAM_SIGNAL=1
fi

RUN_RED_TEAM=0
if [ "$REVIEW_MODE" = "incremental" ]; then
  if [ "$RISK" = "HIGH" ] && [ "$_RED_TEAM_SIGNAL" = "1" ]; then
    RUN_RED_TEAM=1
  fi
else
  if [ "$RISK" = "HIGH" ]; then RUN_RED_TEAM=1
  elif [ "$MEDIUM_SHARP" = "1" ] && [ "$_RED_TEAM_SIGNAL" = "1" ]; then RUN_RED_TEAM=1; fi
fi

RUN_CROSS_REVIEW=0
if [ "$RISK" = "HIGH" ] || [ "$MEDIUM_SHARP" = "1" ]; then
  RUN_CROSS_REVIEW=1
fi

{
  printf 'risk: %s\n'                "$RISK"
  printf 'medium_sharp: %s\n'       "$([ "$MEDIUM_SHARP" = "1" ] && echo true || echo false)"
  printf 'orchestration_mode: %s\n' "$ORCHESTRATION_MODE"
  if [ "${#SPECIALISTS[@]}" -gt 0 ]; then
    printf 'run_specialists:\n'
    for s in "${SPECIALISTS[@]}"; do printf '  - %s\n' "$s"; done
  else
    printf 'run_specialists: []\n'
  fi
  printf 'run_red_team: %s\n'       "$([ "$RUN_RED_TEAM" = "1" ] && echo true || echo false)"
  printf 'run_cross_review: %s\n' "$([ "$RUN_CROSS_REVIEW" = "1" ] && echo true || echo false)"
} > "$OUTDIR/review_plan.yaml"

echo "RISK=$RISK"
echo "MEDIUM_SHARP=$MEDIUM_SHARP"
