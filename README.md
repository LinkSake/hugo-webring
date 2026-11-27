# hugo-webring

A reusable Hugo module for building webrings hosted on GitHub Pages.
Each webring is its own repo: it imports this module and only provides its
configuration, its member list and, optionally, its theme.

## What it generates

| URL | What it does |
| --- | --- |
| `/` | Hub with the list of active members and how to join |
| `/ring/<slug>/next/` | Redirects to the next active member |
| `/ring/<slug>/previous/` | Redirects to the previous active member |
| `/random/` | Redirects to a random active member; `?from=<slug>` skips that member |
| `/members.json` | The ring's name, URL and active members, as JSON |

The ring follows the order of `data/members.yaml` and wraps around. GitHub
Pages has no server-side redirects, so each redirect is a static page with
`meta refresh`, `location.replace()` and a fallback link.

## The widget

The hub shows each member their own widget, ready to copy. It is plain HTML
with absolute URLs, so it works from any site:

```html
<nav class="webring" aria-label="My ring">
  <a href="https://my-ring.example/ring/alamo-seco/previous/" rel="prev">←</a>
  <a href="https://my-ring.example/">My ring</a>
  <a href="https://my-ring.example/random/?from=alamo-seco">Random site</a>
  <a href="https://my-ring.example/ring/alamo-seco/next/" rel="next">→</a>
</nav>
```

It ships unstyled; each member styles `.webring` to fit their site.

## Using it in a ring

Requires Hugo 0.158.0 or later, and Go (for Hugo modules).

```toml
# hugo.toml
baseURL = "https://my-ring.example/"
title = "My ring"
locale = "en-US"
defaultContentLanguage = "en"
disableKinds = ["taxonomy", "term"]

[module]
  [[module.imports]]
    path = "github.com/LinkSake/hugo-webring"

[params.webring]
  name = "My ring"
  description = "Personal sites about ..."
  repo = "https://github.com/<user>/my-ring"
  symbol = "○"
```

```yaml
# data/members.yaml
- slug: alamo-seco                # required, unique, a-z 0-9 and hyphens; never changes
  name: Álamo Seco                # required
  url: https://alamoseco.example/ # required, https
  author: Luis Ángel Ortega       # optional
  description: Poetry and fiction. # optional
  active: true                    # optional; false = out of the rotation
```

If the list has a duplicate or invalid slug, or a member without a name or an
https URL, the build fails and shows every error.

Members with `active: false` keep their URLs, but those redirect to the hub, so
their widget never breaks.

### Customizing

- **Colors and typography:** add `assets/css/theme.css` to your ring with the
  variables from [`assets/css/theme.css`](assets/css/theme.css).
- **Text:** the module ships `en` and `es` translations. Add `i18n/<lang>.yaml`
  to your ring with the keys from [`i18n/en.yaml`](i18n/en.yaml) you want to
  change.
- **Hub text:** write `content/_index.md` in your ring; its content appears
  under the header.
- **Hub layout:** if your ring overrides `layouts/home.html`, call
  `{{ partial "webring/members-json.html" $members }}` in it, or `/members.json`
  won't be published.

## Development

Tool versions live in [`.tool-versions`](.tool-versions) (for asdf or mise).

```sh
# Local server with the example site
hugo server --source exampleSite

# Tests: example site output + invalid member lists (needs jq)
./scripts/test.sh
```

`exampleSite/` uses the module from this same repo through
`module.replacements`. Each file in `tests/invalid/` is a member list that must
break the build; its first line (`# expect: ...`) is the error message the test
looks for.

## Weekly member check

This repo also ships a GitHub Action that checks every active member of a ring:
their site must respond with a 2xx status and link into the ring (the widget
must be there). It reads the ring's `/members.json`, so the ring must be
deployed with a version of this module that publishes it.

The action keeps one issue with the results: it opens it when there are
problems, updates it on each run while they last, and closes it when every
member passes. The run's summary shows the same report.

Add this workflow to your ring as `.github/workflows/check-members.yaml`:

```yaml
name: Member check

on:
  schedule:
    - cron: "17 15 * * 1" # Mondays, 15:17 UTC
  workflow_dispatch:

permissions:
  issues: write

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: LinkSake/hugo-webring/.github/actions/check-members@v1.0.0
        with:
          ring-url: https://my-ring.example/
```

| Input | Default | What it does |
| --- | --- | --- |
| `ring-url` | (required) | The ring's public URL |
| `manage-issue` | `true` | Open, update or close the results issue |
| `issue-label` | `webring-check` | Label of the results issue |
| `github-token` | `github.token` | Token used to manage the issue |

The action's `problems` output has the number of members with problems.

The check doesn't remove anyone. When a site keeps failing, set
`active: false` for it in `data/members.yaml`.

To run the action's tests locally (needs `python3`, `curl` and `jq`):

```sh
./scripts/test-check-members.sh
```
