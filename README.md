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
