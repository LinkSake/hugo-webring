#!/usr/bin/env bash
# Checks every active member of a hugo-webring ring:
#   1. their site responds with a 2xx status, and
#   2. their page links into the ring (the widget is there).
#
# Usage: check.sh <ring-url> <report-file>
#
# Reads <ring-url>/members.json, writes a Markdown report to <report-file>, and
# prints the number of members with problems. When GITHUB_OUTPUT is set, it also
# writes `problems=<n>` there. Exits 0 even when members have problems; exits
# non-zero only when the ring itself can't be read.

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <ring-url> <report-file>" >&2
  exit 2
fi

ring="${1%/}/"
report="$2"
# The widget's links contain the ring URL; match it without the scheme, so an
# http/https mismatch on the member's side doesn't count as a missing widget.
ring_no_scheme="${ring#*://}"
user_agent="hugo-webring member check"

if ! members_json="$(curl -fsSL --max-time 30 --retry 2 -A "$user_agent" "${ring}members.json")"; then
  echo "error: could not read ${ring}members.json" >&2
  exit 1
fi

ring_name="$(jq -r '.name // "the ring"' <<<"$members_json")"
total=0
problems=0
rows=""
body="$(mktemp)"
trap 'rm -f "$body"' EXIT

while IFS=$'\t' read -r slug name url; do
  total=$((total + 1))
  status="$(curl -sSL -o "$body" -w '%{http_code}' --max-time 30 --retry 2 \
    -A "$user_agent" "$url" 2>/dev/null || true)"

  problem=""
  if [[ ! "$status" =~ ^2 ]]; then
    if [[ -z "$status" || "$status" == "000" ]]; then
      problem="did not respond"
    else
      problem="responded with HTTP $status"
    fi
  elif ! grep -qF "${ring_no_scheme}ring/${slug}/" "$body"; then
    problem="widget not found (no link to ${ring}ring/${slug}/)"
  fi

  if [[ -n "$problem" ]]; then
    problems=$((problems + 1))
    rows+="| \`${slug}\` | ${name//|/\\|} | ${url} | ${problem} |"$'\n'
    echo "FAIL  $slug: $problem"
  else
    echo "ok    $slug"
  fi
done < <(jq -r '.members[] | [.slug, .name, .url] | @tsv' <<<"$members_json")

{
  echo "Member check for **${ring_name}** (${ring}) on $(date -u +%F)."
  echo
  if ((problems == 0)); then
    echo "All ${total} active members are online and show the widget."
  else
    echo "${problems} of ${total} active members need attention:"
    echo
    echo "| Slug | Name | URL | Problem |"
    echo "| --- | --- | --- | --- |"
    printf '%s' "$rows"
    echo
    echo "If a site keeps failing, set \`active: false\` for it in \`data/members.yaml\`."
    echo "Its URLs keep working and redirect to the hub."
  fi
} >"$report"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "problems=${problems}" >>"$GITHUB_OUTPUT"
fi

echo "${problems} of ${total} members with problems"
