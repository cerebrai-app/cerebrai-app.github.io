#!/usr/bin/env bash
# Writes and deletes screenshot images on the main branch of the screenshots repository
# through the contents API. Shared by pr-screenshot.yml and pr-screenshot-cleanup.yml.
#
#   screenshot-store.sh put <repo-path> <local-file> <commit-message>
#   screenshot-store.sh delete <repo-path> <commit-message>
#
# Environment: GH_TOKEN (a token with Contents write on the repository) and
# SCREENSHOTS_REPO (owner/name).
set -euo pipefail

ATTEMPTS=5
# Seconds of back-off per attempt; screenshot-store.test.sh sets it to 0.
RETRY_DELAY="${SCREENSHOT_STORE_RETRY_DELAY:-2}"
repo="${SCREENSHOTS_REPO:?SCREENSHOTS_REPO is required}"

usage() {
  sed -n '2,8p' "$0" >&2
  exit 2
}

# Prints a file's current sha, or nothing if it does not exist. Only a 404 means "does not
# exist": any other error fails, so a rate limit or network error is never mistaken for a
# new or already deleted file.
read_sha() {
  local out
  if out="$(gh api "repos/${repo}/contents/$1?ref=main" --jq .sha 2>&1)"; then
    printf '%s' "$out"
  elif grep -q "HTTP 404" <<< "$out"; then
    return 0
  else
    echo "Could not read $1: $out" >&2
    return 1
  fi
}

# Waits before the next attempt. There is no next attempt after the last one, so no wait.
backoff() {
  if (($1 < ATTEMPTS)); then
    sleep $(($1 * RETRY_DELAY))
  fi
}

# Other pull requests commit to the same branch, so a write can fail because main moved.
# Each attempt therefore reads the sha again before writing.
put() {
  local path="$1" file="$2" message="$3" sha body attempt
  body="$(mktemp)"
  trap 'rm -f "$body"' RETURN
  for attempt in $(seq 1 "$ATTEMPTS"); do
    if sha="$(read_sha "$path")"; then
      # The image goes in a file: it is too large for a command-line argument.
      jq -n \
        --arg message "$message" \
        --arg branch main \
        --arg sha "$sha" \
        --rawfile content <(base64 --wrap=0 "$file") \
        '{message: $message, branch: $branch, content: $content} + (if $sha == "" then {} else {sha: $sha} end)' \
        > "$body"
      if gh api --method PUT "repos/${repo}/contents/${path}" --input "$body" > /dev/null; then
        return 0
      fi
      echo "Commit of $path failed (attempt $attempt), retrying..." >&2
    fi
    backoff "$attempt"
  done
  return 1
}

delete() {
  local path="$1" message="$2" sha attempt
  for attempt in $(seq 1 "$ATTEMPTS"); do
    if sha="$(read_sha "$path")"; then
      if [[ -z "$sha" ]]; then
        return 0 # already gone
      fi
      if gh api --method DELETE "repos/${repo}/contents/${path}" \
        -f message="$message" -f branch=main -f sha="$sha" > /dev/null; then
        return 0
      fi
      echo "Delete of $path failed (attempt $attempt), retrying..." >&2
    fi
    backoff "$attempt"
  done
  return 1
}

case "${1:-}" in
  put) [[ $# -eq 4 ]] || usage; put "$2" "$3" "$4" ;;
  delete) [[ $# -eq 3 ]] || usage; delete "$2" "$3" ;;
  *) usage ;;
esac
