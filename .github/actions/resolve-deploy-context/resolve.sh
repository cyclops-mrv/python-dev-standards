#!/usr/bin/env bash
set -euo pipefail

# Computes Prefect deploy routing context.
#
# Execute directly (composite action): reads EVENT_NAME, BRANCH_NAME, and
# IMAGE_NAME from the environment and writes outputs to GITHUB_OUTPUT.
#
# Source from tests: call resolve_deploy_context and read the exported variables.

resolve_deploy_context() {
  local event_name="$1"
  local branch_name="$2"
  local image_name="$3"
  local commit_hash="${4:-}"

  if [ -z "${commit_hash}" ]; then
    commit_hash="$(git rev-parse --short HEAD 2>/dev/null || true)"
  fi
  [ -n "${commit_hash}" ] || commit_hash="deadbeef"

  BRANCH_SLUG="$(echo "${branch_name}" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
    | cut -c1-40)"
  [ -n "${BRANCH_SLUG}" ] || BRANCH_SLUG="branch"

  # Rule 1 — prod on push to main (includes merged-PR routing, which passes event push).
  if [ "${event_name}" != "pull_request" ] && [ "${branch_name}" = "main" ]; then
    TARGET_ENV="prod"
  else
    TARGET_ENV="staging"
  fi

  # Rule 2 — ephemeral suffix on feature branches for PRs and manual dispatch.
  if [ "${branch_name}" != "dev" ] && [ "${branch_name}" != "main" ] \
      && { [ "${event_name}" = "pull_request" ] || [ "${event_name}" = "workflow_dispatch" ]; }; then
    DEPLOYMENT_NAME_SUFFIX="-${BRANCH_SLUG}"
  else
    DEPLOYMENT_NAME_SUFFIX=""
  fi

  if [ -n "${DEPLOYMENT_NAME_SUFFIX}" ]; then
    IMAGE_TAG="${image_name}:${commit_hash}-${BRANCH_SLUG}"
  else
    IMAGE_TAG="${image_name}:${commit_hash}"
  fi

  BRANCH_NAME="${branch_name}"
  COMMIT_HASH="${commit_hash}"
  IMAGE_NAME="${image_name}"
  PREFECT_PULL_BRANCH="${branch_name}"

  export BRANCH_NAME BRANCH_SLUG COMMIT_HASH TARGET_ENV DEPLOYMENT_NAME_SUFFIX
  export IMAGE_NAME IMAGE_TAG PREFECT_PULL_BRANCH
}

write_resolve_outputs() {
  {
    echo "branch_name=${BRANCH_NAME}"
    echo "branch_slug=${BRANCH_SLUG}"
    echo "commit_hash=${COMMIT_HASH}"
    echo "target_env=${TARGET_ENV}"
    echo "deployment_name_suffix=${DEPLOYMENT_NAME_SUFFIX}"
    echo "prefect_pull_branch=${PREFECT_PULL_BRANCH}"
    echo "image_tag=${IMAGE_TAG}"
  } >> "${GITHUB_OUTPUT}"

  {
    echo "docker_tags<<EOF"
    echo "${IMAGE_TAG}"
    [ "${TARGET_ENV}" = "prod" ] && echo "${IMAGE_NAME}:latest"
    echo "EOF"
  } >> "${GITHUB_OUTPUT}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  resolve_deploy_context "${EVENT_NAME}" "${BRANCH_NAME}" "${IMAGE_NAME}"
  write_resolve_outputs
fi
