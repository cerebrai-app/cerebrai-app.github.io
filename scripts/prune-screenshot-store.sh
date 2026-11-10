#!/usr/bin/env bash
# Deletes PR screenshots from the screenshot branch (see pr-screenshot.yml).
#
#   prune-screenshot-store.sh --pr <number>         delete one PR's screenshots
#   prune-screenshot-store.sh --older-than <days>   delete screenshots captured more than <days> ago
#
# The branch is replaced with a single fresh commit holding what is left, so the
# deleted images drop out of its history instead of lingering in old commits.
#
# Environment: SCREENSHOT_BRANCH, plus either REMOTE_URL or GH_TOKEN and GITHUB_REPOSITORY.
set -euo pipefail

usage() {
  sed -n '2,5p' "$0" >&2
  exit 2
}

mode="${1:-}"
value="${2:-}"
[[ "$mode" == "--pr" || "$mode" == "--older-than" ]] || usage
[[ "$value" =~ ^[0-9]+$ ]] || usage

branch="${SCREENSHOT_BRANCH:?SCREENSHOT_BRANCH is required}"
remote="${REMOTE_URL:-https://x-access-token:${GH_TOKEN:?}@github.com/${GITHUB_REPOSITORY:?}.git}"
store="$(mktemp -d)"
trap 'rm -rf "$store"' EXIT

commit() {
  git -C "$store" \
    -c user.name="github-actions[bot]" \
    -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
    commit --quiet "$@"
}

for attempt in 1 2 3 4 5; do
  if ! git ls-remote --exit-code --heads "$remote" "$branch" > /dev/null; then
    echo "Branch $branch does not exist; nothing to clean up."
    exit 0
  fi

  rm -rf "$store"
  git clone --quiet --depth 1 --branch "$branch" "$remote" "$store"
  tip="$(git -C "$store" rev-parse HEAD)"
  tip_time="$(git -C "$store" log -1 --format=%ct)"

  removed=()
  if [[ "$mode" == "--pr" ]]; then
    if [[ -d "$store/pr-$value" ]]; then
      removed+=("pr-$value")
    fi
  else
    cutoff=$(($(date +%s) - value * 86400))
    for dir in "$store"/pr-*/; do
      [[ -d "$dir" ]] || continue
      # Directories without a timestamp fall back to the branch's last commit.
      captured="$(cat "$dir/.captured-at" 2> /dev/null || echo "$tip_time")"
      [[ "$captured" =~ ^[0-9]+$ ]] || captured="$tip_time"
      if ((captured < cutoff)); then
        removed+=("$(basename "$dir")")
      fi
    done
  fi

  if ((${#removed[@]} == 0)); then
    echo "Nothing to delete."
    exit 0
  fi

  for name in "${removed[@]}"; do
    rm -rf "${store:?}/$name"
  done

  if compgen -G "$store/pr-*" > /dev/null; then
    git -C "$store" checkout --quiet --orphan pruned
    git -C "$store" add --all
    commit -m "Prune screenshots: ${removed[*]}"
    target="pruned:$branch"
  else
    # No screenshots left: drop the branch. The next PR recreates it.
    target=":$branch"
  fi

  # The lease makes the push fail, rather than discard work, if a PR published meanwhile.
  if git -C "$store" push --quiet --force-with-lease="$branch:$tip" origin "$target"; then
    echo "Deleted: ${removed[*]}"
    exit 0
  fi
  echo "Push failed (attempt $attempt), retrying..."
  sleep $((attempt * 3))
done

echo "Could not update $branch." >&2
exit 1
