#!/usr/bin/env bash
# Keeps one open issue with the latest member check results:
#   - problems found and no open issue: opens one
#   - problems found and an open issue: updates it and comments
#   - no problems and an open issue: closes it
#
# Environment: GH_TOKEN, GITHUB_REPOSITORY, REPORT (file), PROBLEMS (number),
# LABEL (issue label).

set -euo pipefail

repo="$GITHUB_REPOSITORY"
today="$(date -u +%F)"
title="Webring member check: ${PROBLEMS} site(s) need attention"

existing="$(gh issue list --repo "$repo" --label "$LABEL" --state open --limit 1 \
  --json number --jq '.[0].number // empty' 2>/dev/null || true)"

if ((PROBLEMS > 0)); then
  gh label create "$LABEL" --repo "$repo" --color d93f0b \
    --description "Results of the weekly webring member check" --force >/dev/null
  if [[ -n "$existing" ]]; then
    gh issue edit "$existing" --repo "$repo" --title "$title" --body-file "$REPORT" >/dev/null
    gh issue comment "$existing" --repo "$repo" \
      --body "Checked again on ${today}: ${PROBLEMS} site(s) still need attention." >/dev/null
    echo "Updated issue #${existing}"
  else
    gh issue create --repo "$repo" --title "$title" --label "$LABEL" --body-file "$REPORT"
  fi
elif [[ -n "$existing" ]]; then
  gh issue close "$existing" --repo "$repo" \
    --comment "All members passed the check on ${today}." >/dev/null
  echo "Closed issue #${existing}"
else
  echo "No problems and no open issue; nothing to do"
fi
