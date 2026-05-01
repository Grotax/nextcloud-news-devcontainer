# nextcloud-news-devcontainer

A pre-built devcontainer image for [Nextcloud News](https://github.com/nextcloud/news).

## What's included

The image extends [`ghcr.io/juliusknorr/nextcloud-dev-php83`](https://github.com/juliusknorr/nextcloud-dev) and adds:

| Tool | Source | Reason |
|------|--------|--------|
| **Python 3 + pip** | Debian apt | Replaces the `ghcr.io/devcontainers/features/python` devcontainer feature, which compiles Python from source on every rebuild (slow). The apt package is pre-baked into the image. |
| **zizmor** | pip | GitHub Actions security scanner — pre-installed so the `postAttachCommand` doesn't need to fetch it each time. |
| **HTTPie** | pip | HTTP client (`http`/`https` commands) — used in `nextcloud/news` bats integration tests. |
| **nvm** | nvm install script | Node Version Manager, installed to `/usr/local/nvm` so all users can access it. Allows easy switching of Node.js versions inside the container. |
| **Node.js LTS** | nvm | Latest LTS release, installed via nvm and set as the default. The nvm directory is world-writable so non-root users can run `npm install -g` without sudo. |
| **bats** | npm (global) | [Bash Automated Testing System](https://github.com/bats-core/bats-core) — used in `nextcloud/news` for shell-level tests. |

## Usage in the Nextcloud News repo

Create or replace `.devcontainer/devcontainer.json` in the `nextcloud/news` repository:

```json
{
    "image": "ghcr.io/grotax/nextcloud-news-devcontainer:latest",
    "remoteUser": "vscode",
    "updateRemoteUserUID": true,
    "forwardPorts": [80],
    "containerEnv": {
        "NEXTCLOUD_VERSION": "33",
        "NEXTCLOUD_AUTOINSTALL_APPS": "news",
        "XDEBUG_MODE": "debug"
    },
    "workspaceMount": "source=${localWorkspaceFolder},target=/var/www/html/apps-extra/news,type=bind",
    "workspaceFolder": "/var/www/html/apps-extra/news",
    "postCreateCommand": "bash .devcontainer/setup.sh",
    "overrideCommand": true,
    "portsAttributes": {
        "80": { "label": "Webserver" }
    },
    "features": {
        "ghcr.io/devcontainers/features/github-cli": "latest"
    },
    "customizations": {
        "vscode": {
            "extensions": [
                "Vue.volar",
                "bmewburn.vscode-intelephense-client"
            ],
            "settings": {
                "php.suggest.basic": false
            }
        }
    }
}
```

Add the setup script at `.devcontainer/setup.sh`:

```bash
#!/bin/bash
bash /workspaces/nextcloud-news-devcontainer/.devcontainer/setup.sh
```

> **Note:** The `setup.sh` in this repository is the canonical one. If you vendor it into the news repo, copy `.devcontainer/setup.sh` from here.

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `NEXTCLOUD_VERSION` | *(latest master)* | Nextcloud server version to install. Use a number (`33`) for a stable branch or `master` for the development branch. |
| `NEXTCLOUD_AUTOINSTALL_APPS` | *(none)* | Space-separated list of apps to enable after install, e.g. `news`. |
| `SQL` | `sqlite` | Database backend: `sqlite`, `mysql`, `pgsql`. |
| `XDEBUG_MODE` | *(off)* | Xdebug mode, e.g. `debug` or `coverage`. |

### How it works

1. `postCreateCommand` runs `.devcontainer/setup.sh`.
2. The script calls the base image's `bootstrap.sh` with `sudo -E` so all environment variables are preserved.
3. `bootstrap.sh` clones the Nextcloud server at the requested branch (or uses a mounted source), installs it with `occ maintenance:install`, and enables any `NEXTCLOUD_AUTOINSTALL_APPS`.
4. After install, `setup.sh` fixes ownership of `config/`, `data/`, and `apps-writable/` so the `vscode` user can read and write them without sudo.
5. Apache is left running in the background, serving Nextcloud at `http://localhost` (credentials: `admin` / `admin`).

The workspace folder (`/var/www/html/apps-extra/news`) is bind-mounted from the host, so your source edits are reflected immediately without any copy step.

## Releases & CI

A new image is built and pushed to `ghcr.io/grotax/nextcloud-news-devcontainer` automatically when a GitHub Release is published in this repository. Images are tagged with the release version (e.g. `1.0.0`, `1.0`) as well as `latest`.
