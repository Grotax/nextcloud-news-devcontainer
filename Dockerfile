FROM ghcr.io/juliusknorr/nextcloud-dev-php83:latest

# Install Python 3 and ssh
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-venv \
        openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Install zizmor (GitHub Actions security scanner) into an isolated venv so
# that pip does not touch system-managed packages.
RUN python3 -m venv /opt/zizmor-venv \
    && /opt/zizmor-venv/bin/pip install --quiet zizmor \
    && ln -s /opt/zizmor-venv/bin/zizmor /usr/local/bin/zizmor

# Install HTTPie (used in bats integration tests) into an isolated venv.
RUN python3 -m venv /opt/httpie-venv \
    && /opt/httpie-venv/bin/pip install --quiet httpie \
    && ln -s /opt/httpie-venv/bin/http /usr/local/bin/http \
    && ln -s /opt/httpie-venv/bin/https /usr/local/bin/https \
    && ln -s /opt/httpie-venv/bin/httpie /usr/local/bin/httpie

# Install nvm to a shared location so every user in the container can use it.
# NVM_DIR is exported as a build-time and runtime environment variable so that
# the nvm shell function and the node/npm binaries are on PATH for all users.
ENV NVM_DIR=/usr/local/nvm
RUN mkdir -p "$NVM_DIR" \
    && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash \
    && . "$NVM_DIR/nvm.sh" \
    # Install the latest LTS release and make it the default.
    && nvm install --lts \
    && nvm alias default lts/* \
    && nvm use default \
    # Install bats (Bash Automated Testing System) used in nextcloud/news.
    && npm install -g bats \
    # Make the whole nvm tree writable by all users so that any non-root
    # devcontainer user can run `npm install -g` without sudo.  This is an
    # intentional, dev-only trade-off: devcontainers are single-tenant
    # developer environments, not multi-tenant production systems.
    && chmod -R a+rwX "$NVM_DIR"

# Create the vscode user (UID/GID 1000) – the conventional non-root user for
# VS Code devcontainers (mirrors the pattern used by microsoft/vscode-dev-containers).
# * www-data  – allows the user to read/write files owned by the web server.
# * sudo      – allows the user to run privileged commands inside the container.
# The NOPASSWD:ALL sudoers rule is intentional and standard for devcontainers:
# these are ephemeral, single-tenant developer environments, not production
# systems.  Do NOT use this image outside of a local development context.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000
RUN apt-get update && apt-get install -y --no-install-recommends sudo \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid "$USER_GID" "$USERNAME" \
    && useradd --uid "$USER_UID" --gid "$USER_GID" --shell /bin/bash --create-home "$USERNAME" \
    && usermod -aG www-data,sudo "$USERNAME" \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$USERNAME" \
    && chmod 0440 /etc/sudoers.d/"$USERNAME"

# Wrap the upstream bootstrap.sh so that after Nextcloud is bootstrapped the
# config directory is re-owned to the vscode user so phpunit can write to it
# (bootstrap runs as root via sudo, leaving config/ owned by root).
#
# Note: the Nextcloud installer runs in the background after bootstrap returns,
# so any `occ` calls made here would race against the installation and run
# before config.php is written.  Post-install steps (e.g. disabling the
# profiler) are therefore performed in .devcontainer/setup.sh after the
# installer has confirmed it finished.
RUN mv /usr/local/bin/bootstrap.sh /usr/local/bin/bootstrap-original.sh \
    && printf '#!/bin/bash\nset -e\n/usr/local/bin/bootstrap-original.sh "$@"\nchown -R %s:%s /var/www/html/config\n' \
        "$USER_UID" "$USER_GID" > /usr/local/bin/bootstrap.sh \
    && chmod +x /usr/local/bin/bootstrap.sh

# Create the Xdebug log file and make it writable by the vscode user so that
# VS Code's PHP Debug extension can write to it without needing sudo.
RUN touch /var/log/xdebug.log \
    && chown "$USER_UID":"$USER_GID" /var/log/xdebug.log \
    && chmod 600 /var/log/xdebug.log

# Source nvm in every login shell (/etc/profile.d/) and every interactive
# non-login shell (/etc/bash.bashrc) so all users get nvm on PATH.
RUN printf 'export NVM_DIR="%s"\n[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"\n[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"\n' \
        "$NVM_DIR" > /etc/profile.d/nvm.sh \
    && chmod a+r /etc/profile.d/nvm.sh \
    && cat /etc/profile.d/nvm.sh >> /etc/bash.bashrc

# Remove any temporary files left in /tmp by the build steps above (e.g.
# pip's sfi_file_sequence_* directories whose names contain a random suffix
# and therefore cannot be targeted by a more specific glob).
RUN find /tmp -mindepth 1 -delete
