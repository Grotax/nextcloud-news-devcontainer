FROM ghcr.io/juliusknorr/nextcloud-dev-php83:latest

# Install Python 3 from the Debian repo.
# This replaces the devcontainer 'python' feature which compiles Python from
# source on every rebuild, making container startup significantly slower.
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Install zizmor (GitHub Actions security scanner) into an isolated venv so
# that pip does not touch system-managed packages.
RUN python3 -m venv /opt/zizmor-venv \
    && /opt/zizmor-venv/bin/pip install --quiet zizmor \
    && ln -s /opt/zizmor-venv/bin/zizmor /usr/local/bin/zizmor

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
# Create the vscode user, handling the case where the base image already owns
# the requested GID or UID (a common source of build failures that leaves the
# published image without the user).  Strategy mirrors the approach used by
# Microsoft's devcontainer base images:
#   - If another group already owns GID $USER_GID, rename it to $USERNAME.
#   - If another user  already owns UID $USER_UID, rename it to $USERNAME.
RUN apt-get update && apt-get install -y --no-install-recommends sudo \
    && rm -rf /var/lib/apt/lists/* \
    && existing_group="$(getent group "$USER_GID" | cut -d: -f1)" \
    && if [ -n "$existing_group" ]; then \
           groupmod -n "$USERNAME" "$existing_group"; \
       else \
           groupadd --gid "$USER_GID" "$USERNAME"; \
       fi \
    && existing_user="$(getent passwd "$USER_UID" | cut -d: -f1)" \
    && if [ -n "$existing_user" ]; then \
           existing_home="$(getent passwd "$USER_UID" | cut -d: -f6)"; \
           if [ -d "$existing_home" ]; then \
               usermod -l "$USERNAME" -g "$USER_GID" -d /home/"$USERNAME" -m -s /bin/bash "$existing_user"; \
           else \
               usermod -l "$USERNAME" -g "$USER_GID" -d /home/"$USERNAME" -s /bin/bash "$existing_user" \
               && mkdir -p /home/"$USERNAME" && chown "$USER_UID":"$USER_GID" /home/"$USERNAME"; \
           fi; \
       else \
           useradd --uid "$USER_UID" --gid "$USER_GID" --shell /bin/bash --create-home "$USERNAME"; \
       fi \
    && usermod -aG www-data,sudo "$USERNAME" \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$USERNAME" \
    && chmod 0440 /etc/sudoers.d/"$USERNAME"

# Source nvm in every login shell (/etc/profile.d/) and every interactive
# non-login shell (/etc/bash.bashrc) so all users get nvm on PATH.
RUN printf 'export NVM_DIR="%s"\n[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"\n[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"\n' \
        "$NVM_DIR" > /etc/profile.d/nvm.sh \
    && chmod a+r /etc/profile.d/nvm.sh \
    && cat /etc/profile.d/nvm.sh >> /etc/bash.bashrc
