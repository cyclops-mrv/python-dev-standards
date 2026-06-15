#!/usr/bin/env bash
set -euo pipefail

# Tests the routing logic from deploy-prefect-flow.yml against all scenarios
# defined in ci-cd-routing.csv. Run locally with: bash tests/test-deploy-routing.sh

PASS=0
FAIL=0

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
# Skips pull_request:synchronize when head is dev — push to dev handles deploy.
# Args: test_name event_name action head_ref want_runs("true"|"false")
assert_deploy_runs() {
  local name="$1" event_name="$2" action="$3" head_ref="$4" want_runs="$5"

  local RUNS="true"
  if [ "${action}" = "closed" ]; then
    RUNS="false"
  elif [ "${event_name}" = "pull_request" ] && [ "${head_ref}" = "dev" ] && [ "${action}" = "synchronize" ]; then
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
# Args: test_name event_name branch_name
#       expected_target_env expected_suffix expected_image_tag_suffix
assert_routing() {
  local name="$1"
  local event_name="$2"   # "push" or "pull_request"
  local branch_name="$3"  # pushed branch (push) or PR head branch (pull_request)
  local want_env="$4"
  local want_suffix="$5"  # expected DEPLOYMENT_NAME_SUFFIX value

  # ── routing logic (mirrors deploy-prefect-flow.yml) ──────────────────────
  local BRANCH_SLUG TARGET_ENV DEPLOYMENT_NAME_SUFFIX

  BRANCH_SLUG="$(echo "${branch_name}" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
    | cut -c1-40)"
  [ -z "${BRANCH_SLUG}" ] && BRANCH_SLUG="branch"

  if [ "${event_name}" != "pull_request" ]; then
    [ "${branch_name}" = "main" ] && TARGET_ENV="prod" || TARGET_ENV="staging"
    DEPLOYMENT_NAME_SUFFIX=""
  elif [ "${branch_name}" = "dev" ]; then
    TARGET_ENV="staging"
    DEPLOYMENT_NAME_SUFFIX=""
  else
    TARGET_ENV="staging"
    DEPLOYMENT_NAME_SUFFIX="-${BRANCH_SLUG}"
  fi
  # ── end routing logic ─────────────────────────────────────────────────────

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
echo "CSV scenarios:"

# Row 1  — PR: feature → dev
assert_routing "PR: feature→dev"      pull_request "feature/my-feature"  staging "-feature-my-feature"

# Row 2  — Merged PR: feature → dev  (appears as push to dev)
assert_routing "Merged: feature→dev"  push         "dev"                  staging ""

# Row 5  — PR: dev → main
assert_routing "PR: dev→main"         pull_request "dev"                  staging ""

# Row 7  — Merged PR: dev → main  (appears as push to main)
assert_routing "Merged: dev→main"     push         "main"                 prod    ""

# Row 9  — PR: feature → main
assert_routing "PR: feature→main"     pull_request "feature/my-feature"  staging "-feature-my-feature"

# Row 12 — Merged PR: feature → main  (appears as push to main)
assert_routing "Merged: feature→main" push         "main"                 prod    ""

echo ""
echo "Edge cases:"

# Branch slug normalisation
assert_routing "PR: Feature/ABC-123→dev (slug normalisation)" pull_request "Feature/ABC-123" staging "-feature-abc-123"

# Direct push to dev (not via PR)
assert_routing "Direct push to dev"   push         "dev"                  staging ""

echo ""
echo "Double-fire guard (dev→main PR updated: push+synchronize must route identically so cancel-in-progress is safe):"

# When dev is pushed while a dev→main PR is open, GitHub fires BOTH a push to dev
# AND a pull_request:synchronize. Both must produce identical routing so that
# whichever the concurrency group cancels, the surviving run is correct.
assert_routing "push to dev (side of double-fire)"             push         "dev" staging ""
assert_routing "pull_request:synchronize dev→main (other side)" pull_request "dev" staging ""

echo ""
echo "Deploy job skip (dev→main double-fire — synchronize skipped, push deploys):"

assert_deploy_runs "push to dev runs deploy"                          push         push          dev                  true
assert_deploy_runs "pull_request:synchronize dev→main skipped"        pull_request synchronize   dev                  false
assert_deploy_runs "pull_request:opened dev→main runs deploy"         pull_request opened        dev                  true
assert_deploy_runs "pull_request feature branch runs deploy"          pull_request synchronize   feature/my-feature   true

echo ""
echo ""
echo "=== cleanup-prefect-branch-deployments teardown tests ==="
echo ""
echo "CSV scenarios (PR closed, whether merged or not):"

# Row 1 / Row 2 — feature→dev: ephemeral deployment must be removed on PR close
assert_cleanup "PR feature→dev closed"  "feature/my-feature" "dev"  "true"

# Row 5 / Row 7 — dev→main: dev branch deployment is persistent, must NOT be removed
assert_cleanup "PR dev→main closed"     "dev"                "main" "false"

# Row 9 / Row 12 — feature→main: ephemeral deployment must be removed on PR close
assert_cleanup "PR feature→main closed" "feature/my-feature" "main" "true"

echo ""
echo "Out-of-scope PRs (trigger branches filter must block these):"

# PR targeting a non-tracked branch: trigger must not fire (no ephemeral deployment exists)
assert_cleanup "PR feature→feature closed" "feature/x" "feature/y" "false"
assert_cleanup "PR feature→hotfix closed"  "feature/x" "hotfix/z"  "false"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
