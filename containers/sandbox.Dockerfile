# Pin digest for reproducible builds and stable GHA cache layers.
# To update: docker pull kalilinux/kali-rolling:latest && docker inspect --format='{{index .RepoDigests 0}}' kalilinux/kali-rolling:latest
FROM kalilinux/kali-rolling@sha256:287cd5cfa409e258e9ec3661db4dff0bfbb45fc95734e82d3b270a0f749629ca

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

# Non-root operator user with passwordless sudo
# - Workspace files owned by UID 1000 (matches most host users → no permission issues)
# - sudo apt install / sudo nmap still work when needed
RUN apt-get update && apt-get install -y --no-install-recommends sudo && apt-get clean && \
    useradd -m -s /bin/bash -u 1000 -g operator operator && \
    echo "operator ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/operator && \
    chmod 0440 /etc/sudoers.d/operator

# Configure tmux: 50K line scrollback buffer to prevent output truncation
RUN echo "set-option -g history-limit 50000" > /home/operator/.tmux.conf && \
    chown operator:operator /home/operator/.tmux.conf

# Grant nmap raw socket capability so non-root operator can run SYN scans / OS detection
RUN apt-get update && apt-get install -y --no-install-recommends libcap2-bin && apt-get clean && \
    setcap cap_net_raw,cap_net_admin,cap_net_bind_service=eip $(which nmap)

# Working directory for the agent's virtual filesystem
WORKDIR /workspace

USER operator

# Keep the container alive so the backend can 'docker exec' into it
CMD ["tail", "-f", "/dev/null"]
