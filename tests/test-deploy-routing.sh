#!/usr/bin/env bash
set -euo pipefail

# Tests deploy routing via .github/actions/resolve-deploy-context/resolve.sh
# and deploy job gates in deploy-prefect-flow.yml (PR-only model).
# Run locally with: bash tests/test-deploy-routing.sh

PASS=0
FAIL=0

RESOLVE_SCRIPT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/.github/actions/resolve-deploy-context/resolve.sh"
# shellcheck source=.github/actions/resolve-deploy-context/resolve.sh
source "${RESOLVE_SCRIPT}"
TEST_IMAGE_NAME="cyclopsai/test-image"
TEST_COMMIT_HASH="abc1234"

# Models whether the cleanup workflow actually runs for a given PR close event.
# Gate 1 — trigger branches filter (branches: [main, dev] on pull_request:closed).
# Gate 2 — job if condition: head_ref != main && head_ref != dev.
# Args: test_name head_ref base_ref want_runs("true"|"false")
assert_cleanup() {
  local name="$1" head_ref="$2" base_ref="$3" want_runs="$4"

  local TRIGGER RUNS
  if [ "${base_ref}" = "main" ] || [ "${base_ref}" = "dev" ]; then
    TRIGGER="true"
  else
    TRIGGER="false"
  fi

  if [ "${TRIGGER}" = "true" ] && [ "${head_ref}" != "main" ] && [ "${head_ref}" != "dev" ]; then
    RUNS="true"
  else
    RUNS="false"
  fi

  if [ "${RUNS}" = "${want_runs}" ]; then
    echo "  PASS  ${name}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  ${name} — cleanup runs: got '${RUNS}', want '${want_runs}'"
    FAIL=$((FAIL + 1))
  fi
}

# Models whether the deploy job in deploy-prefect-flow.yml runs (not skipped).
# PR-only model: push skipped; closed runs only when merged; feature PRs need flag.
# Args: test_name event_name action head_ref want_runs("true"|"false")
#       [deploy_feature_branches("true"|"false"), default false]
#       [merged("true"|"false"), default false — for pull_request closed events]
assert_deploy_runs() {
  local name="$1" event_name="$2" action="$3" head_ref="$4" want_runs="$5"
  local deploy_feature_branches="${6:-false}"
  local merged="${7:-false}"

  local RUNS="true"

  if [ "${event_name}" = "push" ]; then
    RUNS="false"
  elif [ "${event_name}" = "pull_request" ] && [ "${action}" = "closed" ]; then
    [ "${merged}" = "true" ] && RUNS="true" || RUNS="false"
  elif [ "${deploy_feature_branches}" != "true" ] \
      && [ "${event_name}" = "pull_request" ] \
      && [ "${head_ref}" != "dev" ]; then
    RUNS="false"
  fi

  if [ "${RUNS}" = "${want_runs}" ]; then
    echo "  PASS  ${name}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  ${name} — deploy runs: got '${RUNS}', want '${want_runs}'"
    FAIL=$((FAIL + 1))
  fi
}

# Runs the routing logic and asserts expected outputs.
# Args: test_name event_name branch_name expected_target_env expected_suffix
assert_routing() {
  local name="$1"
  local event_name="$2"
  local branch_name="$3"
  local want_env="$4"
  local want_suffix="$5"

  resolve_deploy_context "${event_name}" "${branch_name}" "${TEST_IMAGE_NAME}" "${TEST_COMMIT_HASH}"

  local ok=true msg=""
  [ "${TARGET_ENV}"           != "${want_env}"    ] && { msg+=" env: got '${TARGET_ENV}', want '${want_env}';";       ok=false; }
  [ "${DEPLOYMENT_NAME_SUFFIX}" != "${want_suffix}" ] && { msg+=" suffix: got '${DEPLOYMENT_NAME_SUFFIX}', want '${want_suffix}';"; ok=false; }

  if [ "${ok}" = "true" ]; then
    echo "  PASS  ${name}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  ${name} —${msg}"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== deploy-prefect-flow routing tests ==="
echo ""
echo "CSV scenarios (resolve routing):"

# Row 1  — PR: feature → dev
assert_routing "PR: feature→dev"      pull_request "feature/my-feature"  staging "-feature-my-feature"

# Row 2  — Merged PR: feature → dev (resolve uses push + base dev)
assert_routing "Merged: feature→dev"  push         "dev"                  staging ""

# Row 5  — PR: dev → main
assert_routing "PR: dev→main"         pull_request "dev"                  staging ""

# Row 7  — Merged PR: dev → main (resolve uses push + base main)
assert_routing "Merged: dev→main"     push         "main"                 prod    ""

# Row 9  — PR: feature → main
assert_routing "PR: feature→main"     pull_request "feature/my-feature"  staging "-feature-my-feature"

# Row 12 — Merged PR: feature → main (resolve uses push + base main)
assert_routing "Merged: feature→main" push         "main"                 prod    ""

echo ""
echo "Edge cases:"

assert_routing "PR: Feature/ABC-123→dev (slug normalisation)" pull_request "Feature/ABC-123" staging "-feature-abc-123"

echo ""
echo "Manual dispatch (workflow_dispatch):"

assert_routing "dispatch on feature branch" workflow_dispatch "feature/my-feature" staging "-feature-my-feature"
assert_routing "dispatch on dev"            workflow_dispatch "dev"                  staging ""
assert_routing "dispatch on main"           workflow_dispatch "main"                 prod    ""

echo ""
echo "Deploy job gates (PR-only model):"

assert_deploy_runs "push to dev skipped"                              push         push          dev                  false
assert_deploy_runs "push to main skipped"                             push         push          main                 false
assert_deploy_runs "PR closed unmerged skipped"                       pull_request closed        feature/my-feature   false
assert_deploy_runs "merged feature→dev deploys"                       pull_request closed        feature/my-feature   true   false true
assert_deploy_runs "merged dev→main deploys"                          pull_request closed        dev                  true   false true
assert_deploy_runs "merged feature→main deploys"                    pull_request closed        feature/my-feature   true   false true
assert_deploy_runs "dev→main PR opened deploys"                       pull_request opened        dev                  true
assert_deploy_runs "dev→main PR synchronize deploys"                  pull_request synchronize   dev                  true
assert_deploy_runs "feature PR skipped (deploy_feature_branches off)" pull_request synchronize   feature/my-feature   false
assert_deploy_runs "workflow_dispatch runs"                           workflow_dispatch dispatch feature/my-feature   true

echo ""
echo "deploy_feature_branches enabled (ephemeral feature PR deploys):"

assert_deploy_runs "feature PR runs when enabled"                     pull_request synchronize   feature/my-feature   true  true
assert_deploy_runs "dev→main still runs when enabled"                 pull_request opened        dev                  true  true
assert_deploy_runs "merged feature→dev still deploys when enabled"    pull_request closed        feature/my-feature   true  true  true

echo ""
echo ""
echo "=== cleanup-prefect-branch-deployments teardown tests ==="
echo ""
echo "CSV scenarios (PR closed, whether merged or not):"

assert_cleanup "PR feature→dev closed"  "feature/my-feature" "dev"  "true"
assert_cleanup "PR dev→main closed"     "dev"                "main" "false"
assert_cleanup "PR feature→main closed" "feature/my-feature" "main" "true"

echo ""
echo "Out-of-scope PRs (trigger branches filter must block these):"

assert_cleanup "PR feature→feature closed" "feature/x" "feature/y" "false"
assert_cleanup "PR feature→hotfix closed"  "feature/x" "hotfix/z"  "false"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
