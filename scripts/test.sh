#!/usr/bin/env bash
# Module tests: builds exampleSite and checks that every redirect points where
# it should; then checks that each invalid member list breaks the build with
# the expected message.
#
# Usage: ./scripts/test.sh   (requires hugo on the PATH)

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Use this repo's module through an absolute path, so copies of the example
# site can be built outside the repo.
export HUGO_MODULE_REPLACEMENTS="github.com/LinkSake/hugo-webring -> $root"

failures=0
pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; failures=$((failures + 1)); }

echo "Example site"
out="$tmp/example"
if ! log="$(hugo build --source "$root/exampleSite" --destination "$out" 2>&1)"; then
  echo "$log"
  fail "the example site does not build"
  exit 1
fi
if grep -qE '^(WARN|ERROR)' <<<"$log"; then
  echo "$log"
  fail "the example site build has warnings"
else
  pass "builds without warnings"
fi

# expect_target <slug> <direction> <expected url>
expect_target() {
  local file="$out/ring/$1/$2/index.html"
  if [[ ! -f "$file" ]]; then
    fail "/ring/$1/$2/ does not exist"
  elif grep -qF "content=\"0; url=$3\"" "$file"; then
    pass "/ring/$1/$2/ → $3"
  else
    fail "/ring/$1/$2/ does not point to $3"
  fi
}

expect_target first next https://no-active-field.example/
expect_target first previous https://last.example/
expect_target no-active-field next https://last.example/
expect_target no-active-field previous https://first.example/
expect_target last next https://first.example/
expect_target last previous https://no-active-field.example/
expect_target inactive next https://example.test/
expect_target inactive previous https://example.test/

if grep -q '/ring/' "$out/sitemap.xml"; then
  fail "redirects appear in sitemap.xml"
else
  pass "redirects are not in sitemap.xml"
fi

if grep -q 'inactive.example' "$out/index.html"; then
  fail "the hub shows the inactive member"
else
  pass "the hub hides the inactive member"
fi

# The widget is shown escaped in the hub, so its URLs appear as plain text.
for slug in first no-active-field last; do
  if grep -qF "https://example.test/ring/$slug/previous/" "$out/index.html" &&
    grep -qF "https://example.test/ring/$slug/next/" "$out/index.html" &&
    grep -qF "https://example.test/random/?from=$slug" "$out/index.html"; then
    pass "the hub shows the widget for $slug"
  else
    fail "the hub is missing the widget for $slug"
  fi
done

members="$(jq -r '[.members[].slug] | join(",")' "$out/members.json" 2>/dev/null || true)"
if [[ "$members" == "first,no-active-field,last" ]] &&
  [[ "$(jq -r '.url' "$out/members.json")" == "https://example.test/" ]]; then
  pass "members.json lists the active members in order"
else
  fail "members.json is wrong (got \"$members\")"
fi

random="$out/random/index.html"
if [[ -f "$random" ]] &&
  grep -qF '"url":"https://last.example/"' "$random" &&
  ! grep -q 'inactive.example' "$random"; then
  pass "/random/ picks only from active members"
else
  fail "/random/ is missing or includes inactive members"
fi

if grep -q '/random/' "$out/sitemap.xml"; then
  fail "/random/ appears in sitemap.xml"
else
  pass "/random/ is not in sitemap.xml"
fi

echo
echo "Example site under a subpath (GitHub Pages project site)"
sub="$tmp/subpath"
hugo build --source "$root/exampleSite" --destination "$sub" \
  --baseURL "https://user.github.io/my-ring/" >/dev/null 2>&1
if grep -qF "https://user.github.io/my-ring/ring/first/next/" "$sub/index.html" &&
  grep -qF '"url": "https://user.github.io/my-ring/"' "$sub/members.json" &&
  grep -qF "url=https://user.github.io/my-ring/" "$sub/ring/inactive/next/index.html"; then
  pass "widget, members.json and redirects keep the subpath"
else
  fail "some URLs lose the /my-ring/ subpath"
fi

echo
echo "Invalid member lists"
for case_file in "$root"/tests/invalid/*.yaml; do
  name="$(basename "$case_file" .yaml)"
  expected="$(sed -n '1s/^# expect: //p' "$case_file")"
  site="$tmp/$name"
  cp -r "$root/exampleSite" "$site"
  cp "$case_file" "$site/data/members.yaml"
  if log="$(hugo build --source "$site" --destination "$site/public" 2>&1)"; then
    fail "$name: the build should have failed"
  elif grep -qF "$expected" <<<"$log"; then
    pass "$name"
  else
    echo "$log"
    fail "$name: failed, but without the message \"$expected\""
  fi
done

echo
if ((failures > 0)); then
  echo "$failures test(s) failed"
  exit 1
fi
echo "All tests passed"
