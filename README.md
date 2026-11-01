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

Deploy `public/` to any static host: GitHub Pages, Netlify, Cloudflare Pages,
S3 + CloudFront, nginx. For GitHub Pages, set `baseURL` in `hugo.toml` to the
final URL (e.g. `https://<user>.github.io/<repo>/`) before building.

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
