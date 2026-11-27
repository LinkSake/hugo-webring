#!/usr/bin/env bash
# Tests for the member check action (.github/actions/check-members/check.sh).
# Serves a fake ring and fake member sites on localhost and checks the report.
#
# Usage: ./scripts/test-check-members.sh   (requires python3, curl and jq)

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
check="$root/.github/actions/check-members/check.sh"
tmp="$(mktemp -d)"
server_pid=""
cleanup() {
  [[ -n "$server_pid" ]] && kill "$server_pid" 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

failures=0
pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; failures=$((failures + 1)); }

port="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
closed_port="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
base="http://127.0.0.1:${port}/"

# A fake ring at the server root, and three member sites under /sites/.
www="$tmp/www"
mkdir -p "$www/sites/healthy" "$www/sites/no-widget"
cat >"$www/members.json" <<EOF
{
  "name": "Test ring",
  "url": "${base}",
  "members": [
    { "slug": "healthy", "name": "Healthy site", "url": "${base}sites/healthy/" },
    { "slug": "no-widget", "name": "Site | without widget", "url": "${base}sites/no-widget/" },
    { "slug": "missing", "name": "Missing site", "url": "${base}sites/missing/" },
    { "slug": "offline", "name": "Offline site", "url": "http://127.0.0.1:${closed_port}/" }
  ]
}
EOF
# The healthy member links with https, while the ring is served over http:
# the check must still find the widget.
cat >"$www/sites/healthy/index.html" <<EOF
<p>Hello</p>
<nav class="webring"><a href="https://127.0.0.1:${port}/ring/healthy/next/">→</a></nav>
EOF
echo "<p>No widget here</p>" >"$www/sites/no-widget/index.html"

python3 -m http.server "$port" --bind 127.0.0.1 --directory "$www" >/dev/null 2>&1 &
server_pid=$!
for _ in $(seq 50); do
  curl -fs "${base}members.json" >/dev/null 2>&1 && break
  sleep 0.1
done

echo "Member check"
report="$tmp/report.md"
output="$tmp/github-output"
: >"$output"
if ! log="$(GITHUB_OUTPUT="$output" "$check" "$base" "$report" 2>&1)"; then
  echo "$log"
  fail "check.sh failed on a readable ring"
fi

if grep -qx 'problems=3' "$output"; then
  pass "reports 3 members with problems"
else
  fail "expected problems=3, got: $(cat "$output")"
fi

expect_in_report() {
  if grep -qF "$2" "$report"; then pass "$1"; else fail "$1"; fi
}
expect_in_report "a member without the widget is reported" '| `no-widget` | Site \| without widget |'
expect_in_report "the missing widget says which link it looked for" "widget not found (no link to ${base}ring/no-widget/)"
expect_in_report "an HTTP error is reported with its status" 'responded with HTTP 404'
expect_in_report "a site that doesn't respond is reported" '| `offline` | Offline site |'
expect_in_report "the report suggests marking failing sites inactive" 'active: false'

if grep -qF '`healthy`' "$report"; then
  fail "a healthy member (widget linked over https) was reported"
else
  pass "a healthy member is not reported, even with an https widget link"
fi

echo
echo "Ring without problems"
cat >"$www/members.json" <<EOF
{ "name": "Test ring", "url": "${base}", "members": [
  { "slug": "healthy", "name": "Healthy site", "url": "${base}sites/healthy/" } ] }
EOF
: >"$output"
GITHUB_OUTPUT="$output" "$check" "$base" "$report" >/dev/null 2>&1 || true
if grep -qx 'problems=0' "$output" && grep -qF 'All 1 active members are online' "$report"; then
  pass "reports no problems"
else
  fail "a healthy ring was not reported as healthy"
fi

echo
echo "Unreadable ring"
if "$check" "http://127.0.0.1:${closed_port}/" "$report" >/dev/null 2>&1; then
  fail "check.sh succeeded although members.json can't be read"
else
  pass "fails when members.json can't be read"
fi

echo
if ((failures > 0)); then
  echo "$failures test(s) failed"
  exit 1
fi
echo "All member check tests passed"
