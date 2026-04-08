# nextcloud-news-devcontainer

A pre-built devcontainer image for [Nextcloud News](https://github.com/nextcloud/news).

## What's included

The image extends [`ghcr.io/juliusknorr/nextcloud-dev-php83`](https://github.com/juliusknorr/nextcloud-dev) and adds:

| Tool | Source | Reason |
|------|--------|--------|
| **Python 3 + pip** | Debian apt | Replaces the `ghcr.io/devcontainers/features/python` devcontainer feature, which compiles Python from source on every rebuild (slow). The apt package is pre-baked into the image. |
| **zizmor** | pip | GitHub Actions security scanner — pre-installed so the `postAttachCommand` doesn't need to fetch it each time. |
| **Node.js 24.x** | NodeSource apt repo | Required by `nextcloud/news` (`package.json` engine constraint `^24.0.0`). |

## Usage in devcontainer.json

Replace the base image and remove the `python` feature in `.devcontainer/devcontainer.json`:

```json
{
    "image": "ghcr.io/grotax/nextcloud-news-devcontainer:latest",
    "features": {
        "ghcr.io/devcontainers/features/github-cli": "latest"
    }
}
```

## Releases & CI

A new image is built and pushed to `ghcr.io/grotax/nextcloud-news-devcontainer` automatically when a GitHub Release is published in this repository. Images are tagged with the release version (e.g. `1.0.0`, `1.0`) as well as `latest`.
