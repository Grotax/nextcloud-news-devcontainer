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

# Install Node.js 24.x from the NodeSource repository using the GPG-verified
# apt repository method (avoids piping an untrusted script to bash).
# nextcloud/news requires node ^24.0.0 (see package.json engines field).
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*
