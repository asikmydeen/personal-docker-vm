# =============================================================================
# Claude Code Development VM
# Full development environment with Claude Code + AWS Bedrock + SSH access
# =============================================================================
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG NODE_MAJOR=22
ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=1000

# ---- System packages --------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core utilities
    ca-certificates curl wget gnupg2 unzip zip \
    # Development essentials
    git git-lfs build-essential pkg-config \
    # SSH server
    openssh-server \
    # Shell & terminal
    zsh tmux vim nano less htop tree jq ripgrep fd-find fzf bat \
    # Python
    python3 python3-pip python3-venv \
    # Networking & debugging
    iputils-ping dnsutils net-tools socat \
    # Misc
    locales sudo software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# ---- Locale -----------------------------------------------------------------
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# ---- Node.js ----------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g npm@latest

# ---- Bun --------------------------------------------------------------------
RUN curl -fsSL https://bun.sh/install | bash \
    && mv /root/.bun/bin/bun /usr/local/bin/bun \
    && ln -sf /usr/local/bin/bun /usr/local/bin/bunx \
    && rm -rf /root/.bun

# ---- AWS CLI v2 -------------------------------------------------------------
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
      AWSURL="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"; \
    else \
      AWSURL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"; \
    fi && \
    curl -fsSL "$AWSURL" -o /tmp/awscliv2.zip && \
    unzip -q /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/aws /tmp/awscliv2.zip

# ---- Claude Code CLI --------------------------------------------------------
RUN npm install -g @anthropic-ai/claude-code

# ---- Docker CLI (client only — talks to host Podman via mounted socket) ----
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# ---- Create developer user (reuse ubuntu UID/GID 1000) ---------------------
RUN usermod -l ${USERNAME} -d /home/${USERNAME} -m ubuntu \
    && groupmod -n ${USERNAME} ubuntu \
    && chsh -s /usr/bin/zsh ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME} \
    && groupadd -f docker \
    && usermod -aG docker ${USERNAME}

# ---- SSH server setup -------------------------------------------------------
RUN mkdir -p /run/sshd \
    && sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys/' /etc/ssh/sshd_config \
    && echo "AllowUsers ${USERNAME}" >> /etc/ssh/sshd_config \
    && echo "AcceptEnv LANG LC_*" >> /etc/ssh/sshd_config

# ---- Symlink fd and bat (Ubuntu names them differently) ---------------------
RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && ln -sf /usr/bin/batcat /usr/local/bin/bat

# ---- Switch to developer user ----------------------------------------------
USER ${USERNAME}
WORKDIR /home/${USERNAME}

# ---- Oh My Zsh + plugins ---------------------------------------------------
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
    && git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
       ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions \
    && git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
       ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# ---- Zsh configuration (from host) -----------------------------------------
COPY --chown=${USERNAME}:${USERNAME} config/zshrc /home/${USERNAME}/.zshrc

# ---- GitHub SSH keys -------------------------------------------------------
COPY --chown=${USERNAME}:${USERNAME} config/ssh/id_ed25519_github /home/${USERNAME}/.ssh/id_ed25519_github
COPY --chown=${USERNAME}:${USERNAME} config/ssh/id_ed25519_github.pub /home/${USERNAME}/.ssh/id_ed25519_github.pub
RUN chmod 600 /home/${USERNAME}/.ssh/id_ed25519_github \
    && chmod 644 /home/${USERNAME}/.ssh/id_ed25519_github.pub

# ---- SSH config for GitHub -------------------------------------------------
RUN printf 'Host github.com\n  AddKeysToAgent yes\n  IdentityFile ~/.ssh/id_ed25519_github\n  StrictHostKeyChecking accept-new\n' > /home/${USERNAME}/.ssh/config \
    && chmod 600 /home/${USERNAME}/.ssh/config \
    && chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.ssh/config

# ---- Clone claude-auto-setup -----------------------------------------------
RUN git clone --depth=1 https://github.com/asikmydeen/claude-auto-setup.git \
    ~/claude-auto-setup

# ---- Create persistent directories -----------------------------------------
RUN mkdir -p ~/projects ~/.ssh ~/.aws ~/.claude ~/.config/claude-code ~/.local/bin

# ---- Switch back to root for entrypoint ------------------------------------
USER root

# ---- Copy entrypoint -------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
