#!/usr/bin/env bash
# Tests screenshot-store.sh against a fake `gh` that behaves like the contents API.
#
#   bash scripts/screenshot-store.test.sh
#
# Needs bash, jq and GNU base64, which the GitHub runners have.
set -euo pipefail

script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/screenshot-store.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/store"

# The fake API. Files live under $STUB_STORE.
#   STUB_GETFAIL=once|always  makes file reads fail with a 403 (the first time, or every time)
#   The first write or delete of a test fails with a 409, like a branch that moved.
cat > "$tmp/bin/gh" <<'STUB'
#!/usr/bin/env bash
store="$STUB_STORE"; method=GET; endpoint=""; input=""; sha=""; args=("$@"); i=0
while ((i < ${#args[@]})); do
  case "${args[$i]}" in
    api) ;; --method) method="${args[$((i + 1))]}"; i=$((i + 1)) ;; --input) input="${args[$((i + 1))]}"; i=$((i + 1)) ;;
    --jq) i=$((i + 1)) ;; -f) kv="${args[$((i + 1))]}"; [[ $kv == sha=* ]] && sha="${kv#sha=}"; i=$((i + 1)) ;; *) endpoint="${args[$i]}" ;;
  esac
  i=$((i + 1))
done
path="${endpoint#repos/cerebrai-app/automated-screenshots/contents/}"; path="${path%%\?*}"
fsha() { echo "sha-$(md5sum < "$store/$path" | cut -c1-8)"; }
if [[ $method == GET ]]; then
  if [[ ! -f "$store/$path" ]]; then echo "gh: Not Found (HTTP 404)" >&2; exit 1; fi
  if [[ -n "${STUB_GETFAIL:-}" && ( "$STUB_GETFAIL" == always || ! -f "$store/.getfailed" ) ]]; then
    touch "$store/.getfailed"; echo "gh: API rate limit exceeded (HTTP 403)" >&2; exit 1
  fi
  fsha; exit 0
fi
if [[ ! -f "$store/.flaked" ]]; then touch "$store/.flaked"; echo "gh: conflict (HTTP 409)" >&2; exit 1; fi
if [[ $method == PUT ]]; then
  if [[ -f "$store/$path" && "$(jq -r '.sha // ""' "$input")" != "$(fsha)" ]]; then echo "gh: sha mismatch (HTTP 422)" >&2; exit 1; fi
  mkdir -p "$store/$(dirname "$path")"; jq -r .content "$input" | base64 -d > "$store/$path"; echo '{}'
else
  [[ -f "$store/$path" && "$sha" == "$(fsha)" ]] || { echo "gh: sha mismatch (HTTP 422)" >&2; exit 1; }
  rm "$store/$path"; echo '{}'
fi
STUB
# A fake sleep that records how it was called, so the tests do not wait.
cat > "$tmp/bin/sleep" <<'STUB'
#!/usr/bin/env bash
echo "$1" >> "$STUB_SLEEPS"
STUB
chmod +x "$tmp/bin/gh" "$tmp/bin/sleep"

export PATH="$tmp/bin:$PATH" STUB_STORE="$tmp/store" STUB_SLEEPS="$tmp/sleeps"
export SCREENSHOTS_REPO=cerebrai-app/automated-screenshots GH_TOKEN=test SCREENSHOT_STORE_RETRY_DELAY=1

path=repo/pr-1/desktop.png
head -c 3000 /dev/urandom > "$tmp/one.png"
head -c 3000 /dev/urandom > "$tmp/two.png"

failures=0
ok() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; failures=$((failures + 1)); }
# expect <description> <condition command...>
expect() {
  local name="$1"; shift
  if "$@"; then ok "$name"; else fail "$name"; fi
}

status=0
reset() { rm -rf "$tmp/store" "$tmp/sleeps"; mkdir -p "$tmp/store"; touch "$tmp/sleeps"; }
run() { status=0; "$script" "$@" > "$tmp/out" 2>&1 || status=$?; }
sleeps() { wc -l < "$tmp/sleeps" | tr -d ' '; }
holds() { cmp -s "$1" "$tmp/store/$path"; }
exists() { [[ -f "$tmp/store/$path" ]]; }
exit_is() { [[ "$status" == "$1" ]]; }
sleeps_are() { [[ "$(sleeps)" == "$1" ]]; }

reset
run put "$path" "$tmp/one.png" msg
expect "put creates a new file (a 404 means new), retrying the first 409" exit_is 0
expect "  the new file has the right bytes" holds "$tmp/one.png"

touch "$tmp/store/.flaked"
run put "$path" "$tmp/two.png" msg
expect "put overwrites an existing file, which needs its sha" exit_is 0
expect "  the file now has the new bytes" holds "$tmp/two.png"

rm -f "$tmp/store/.getfailed"
STUB_GETFAIL=once run put "$path" "$tmp/one.png" msg
expect "put retries when reading the sha fails once" exit_is 0
expect "  and still overwrites the file" holds "$tmp/one.png"

rm -f "$tmp/store/.getfailed" "$tmp/sleeps"; touch "$tmp/sleeps"
STUB_GETFAIL=always run put "$path" "$tmp/two.png" msg
expect "put fails when reading the sha always fails" exit_is 1
expect "  and leaves the file alone" holds "$tmp/one.png"
expect "  and waits 4 times, not after the last attempt" sleeps_are 4

STUB_GETFAIL=always run delete "$path" bye
expect "delete fails when reading the sha always fails" exit_is 1
expect "  and the file stays" exists

rm -f "$tmp/store/.getfailed"
STUB_GETFAIL=once run delete "$path" bye
expect "delete retries when reading the sha fails once" exit_is 0
expect "  and removes the file" test ! -f "$tmp/store/$path"

run delete "$path" bye
expect "delete succeeds when the file is already gone (404)" exit_is 0

run bogus
expect "an unknown command is a usage error" exit_is 2

if ((failures > 0)); then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
