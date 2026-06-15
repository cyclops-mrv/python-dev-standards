#!/usr/bin/env bash
set -euo pipefail

# Tests .github/actions/parse-prefect-deployment-identifiers/parse.py
# Run locally with: bash tests/test-parse-prefect-deployment-identifiers.sh

PASS=0
FAIL=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${REPO_ROOT}/.github/actions/parse-prefect-deployment-identifiers/parse.py"
FIXTURE_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "${FIXTURE_ROOT}"
}
trap cleanup EXIT

mkdir -p "${FIXTURE_ROOT}/src/flows" "${FIXTURE_ROOT}/deployment"
cat > "${FIXTURE_ROOT}/src/flows/sample.py" << 'PY'
from prefect import flow

@flow(name="decorator-flow-name")
def my_flow():
    pass

@flow(log_prints=True)
def unnamed_flow():
    pass
PY

cat > "${FIXTURE_ROOT}/deployment/prefect.yaml" << 'YAML'
deployments:
  - name: my-deploy{{ $DEPLOYMENT_NAME_SUFFIX }}
    entrypoint: src/flows/sample.py:my_flow
  - name: other-deploy{{ DEPLOYMENT_NAME_SUFFIX }}
    entrypoint: src/flows/sample.py:unnamed_flow
YAML

assert_output() {
  local name="$1" want="$2"
  local got
  got="$(cd "${FIXTURE_ROOT}" && uv run --with prefect --with pyyaml python "${SCRIPT}" deployment/prefect.yaml 2>/dev/null || true)"

  if [ "${got}" = "${want}" ]; then
    echo "  PASS  ${name}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  ${name}"
    echo "        want:"
    echo "${want}" | sed 's/^/          /'
    echo "        got:"
    echo "${got}" | sed 's/^/          /'
    FAIL=$((FAIL + 1))
  fi
}

if ! command -v uv >/dev/null 2>&1; then
  echo "Skipping: uv not installed."
  exit 0
fi

echo "=== parse-prefect-deployment-identifiers tests ==="
echo ""

assert_output "uses @flow(name=...) over yaml flow_name" \
  $'decorator-flow-name\tmy-deploy\nunnamed-flow\tother-deploy'

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
