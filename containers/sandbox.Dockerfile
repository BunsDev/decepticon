# Pin digest for reproducible builds and stable GHA cache layers.
# To update: docker pull kalilinux/kali-rolling:latest && docker inspect --format='{{index .RepoDigests 0}}' kalilinux/kali-rolling:latest
FROM kalilinux/kali-rolling@sha256:a3849f99f9f187122de4822341c49e55d250a771f2dbc5cfd56a146017e0e6ae

# Fix SSL certificate issues with Kali mirrors, then install packages
# Disable apt sandbox so it doesn't fail to drop privileges/chown to _apt user
RUN echo "APT::Sandbox::User \"root\";" > /etc/apt/apt.conf.d/10sandbox && \
    apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    nmap \
    dnsutils \
    whois \
    curl \
    wget \
    netcat-openbsd \
    iputils-ping \
    python3 \
    python3-pip \
    tmux \
    && apt-get clean

# Install subfinder (often not in default kali repos or needs specific setup, but lets try to get it via apt if possible, otherwise we skip or use go)
# Actually, subfinder is in Kali repos: `apt install subfinder`
RUN apt-get update && apt-get install -y --no-install-recommends subfinder && apt-get clean

# Exploit & post-exploitation tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    hydra \
    sqlmap \
    nikto \
    smbclient \
    exploitdb \
    dirb \
    gobuster \
    && apt-get clean

# C2 client — Sliver client connects to the separate C2 server container.
# The full `sliver` package includes both server and client binaries;
# only the client (`sliver-client`) is used from the sandbox.
RUN apt-get update && \
    apt-get install -y --no-install-recommends sliver && \
    apt-get clean

# Configure tmux: 50K line scrollback buffer to prevent output truncation
RUN echo "set-option -g history-limit 50000" > /root/.tmux.conf

# Working directory for the agent's virtual filesystem
# Runs as root — security boundary is the container, not the user.
# Root access is required for raw sockets (nmap SYN scans), packet capture,
# and unrestricted filesystem access during red team operations.
WORKDIR /workspace

# Entrypoint: chmod 777 /workspace so host user can access files without sudo.
# Security boundary is the container, not file permissions.
COPY containers/sandbox-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# Keep the container alive so the backend can 'docker exec' into it
CMD ["tail", "-f", "/dev/null"]
