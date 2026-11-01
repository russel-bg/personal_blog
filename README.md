# My Bioinformatics Blog

A personal blog built with [Hugo](https://gohugo.io/) 0.140.0 (extended) and the
[hugo-clarity](https://github.com/chipzoller/hugo-clarity) theme — the same engine
and template as [lovednacodeblog.com](https://lovednacodeblog.com/).

## Project layout

```
lovednacode-clone/
├── hugo.toml              # site config: title, params, navigation menu
├── content/
│   ├── posts/             # blog posts (markdown)
│   ├── about/_index.md    # About page
│   └── cv/_index.md       # CV page
├── data/authors/          # author profile for the sidebar
├── themes/hugo-clarity/   # theme, pinned to commit 0047222 (compatible with Hugo 0.140.0)
├── scripts/smoke_test.sh  # runtime smoke tests (used by CI and locally)
└── .github/workflows/ci.yml  # GitHub Actions: build + smoke tests on every push
```

## Requirements

- Hugo **0.140.0 extended** (do not upgrade blindly — the pinned theme commit is
  verified against this version; newer Hugo breaks the theme templates).

```bash
curl -sL -o /tmp/hugo.tar.gz \
  https://github.com/gohugoio/hugo/releases/download/v0.140.0/hugo_extended_0.140.0_linux-amd64.tar.gz
mkdir -p ~/.local/bin && tar -xzf /tmp/hugo.tar.gz -C ~/.local/bin hugo
hugo version   # -> v0.140.0+extended
```

## Local development

```bash
hugo server --bind 0.0.0.0 --port 1313
# open http://localhost:1313  (live-reload on every file change)
```

## Production build

```bash
hugo --minify --gc        # static site goes to ./public/
```

Do not commit `public/` — Hugo recreates it on every build (it is gitignored).

## Deploy to GitHub Pages

Deployment follows the official Hugo procedure
(https://gohugo.io/host-and-deploy/deploy-to-github-pages/):

1. Push the repository to GitHub.
2. In the repo: **Settings → Pages → Source: "GitHub Actions"**.
3. That's it. The deploy workflow `.github/workflows/deploy.yaml` runs on every
   push to `main` (and on demand via *workflow_dispatch*): it installs the pinned
   Hugo 0.140.0 extended, builds with `--baseURL` taken from
   `actions/configure-pages` (so `baseURL` in `hugo.toml` does **not** need to be
   edited manually), and deploys `./public` via `actions/deploy-pages`.

The `baseURL = "http://localhost:1313/"` in `hugo.toml` is only used for local
development; the deploy pipeline overrides it at build time. For a custom
domain, configure it in **Settings → Pages** and `configure-pages` passes the
right URL into the build.

CI (`.github/workflows/ci.yml`) additionally runs the smoke tests on every push
to any branch and on pull requests.

## Writing posts

```bash
hugo new content posts/my-post.md
# edit content/posts/my-post.md, set draft: false
```

Every post should carry front matter: `title`, `date`, `description`,
`author: "bio"`, `tags`. The theme computes reading time at ~212 wpm — a
"10 min read" needs roughly 2100+ words.

## Smoke tests

Run against a locally served site:

```bash
hugo server --port 1313 &      # or any port: SMOKE_BASE_URL overrides the target
./scripts/smoke_test.sh        # SMOKE_BASE_URL=http://localhost:8080 ./scripts/smoke_test.sh
```

The same script runs automatically in GitHub Actions on every push and pull
request (see `.github/workflows/ci.yml`): install Hugo 0.140.0 → build → serve
→ smoke-test key pages, navigation, and reading-time labels.

## Navigation

The menu lives in `hugo.toml` under `[[menus.main]]`: Home, About, CV and a
`Links` dropdown (currently LinkedIn). Edit those entries to change the header.
