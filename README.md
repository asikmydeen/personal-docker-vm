# Claude Code Dev VM

A persistent, SSH-accessible Docker development environment with Claude Code pre-configured for AWS Bedrock. Built for Podman on macOS (Apple Silicon).

## What's Inside

| Component | Version/Details |
|-----------|----------------|
| **Base OS** | Ubuntu 24.04 (arm64) |
| **Shell** | zsh + oh-my-zsh (robbyrussell), autosuggestions, syntax highlighting |
| **Node.js** | v22 LTS |
| **Bun** | Latest |
| **Python** | 3.12 |
| **AWS CLI** | v2 |
| **Claude Code** | Latest (`@anthropic-ai/claude-code`) |
| **claude-auto-setup** | 59 commands, 11 rules, 9 agents, 15 plugins |
| **Tools** | git, tmux, vim, nano, ripgrep, fd, fzf, bat, jq, htop, tree |
| **Auth** | AWS Bedrock (bearer token), GitHub SSH (ed25519) |

---

## Quick Start

### Prerequisites

- **Podman** installed and machine running (`podman machine start`)
- **SSH key pair** on host (`~/.ssh/id_ed25519.pub` or similar)
- **AWS Bedrock** bearer token or IAM credentials

### 1. Clone and configure

```bash
git clone <this-repo> ~/projects/personal-docker-vm
cd ~/projects/personal-docker-vm

cp env.example .env
```

### 2. Edit `.env`

```bash
vim .env
```

Fill in these required values:

```env
# Your SSH public key (for SSH access into the container)
SSH_PUBLIC_KEY=ssh-ed25519 AAAA... you@email.com

# Bedrock auth (pick one)
AWS_BEARER_TOKEN_BEDROCK=ABSK...        # Option A: Bearer token
# — OR —
AWS_ACCESS_KEY_ID=AKIA...               # Option B: IAM credentials
AWS_SECRET_ACCESS_KEY=...
AWS_SESSION_TOKEN=...                   # (if using temporary creds)

# Region where Bedrock models are enabled
AWS_REGION=us-east-1
```

### 3. Build and start

```bash
podman compose up -d --build
```

Or use the helper script (auto-detects your SSH key):

```bash
./start.sh
```

### 4. Connect

```bash
ssh -p 2222 developer@localhost
```

You land in a zsh shell with Claude Code ready. Start working:

```bash
cd ~/projects
git clone git@github.com:your-org/your-repo.git
cd your-repo
claude
```

---

## SSH Configuration (Recommended)

Add to your host `~/.ssh/config` for convenience:

```ssh-config
Host claude-vm
  HostName localhost
  Port 2222
  User developer
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
```

Then just:

```bash
ssh claude-vm
```

For VS Code Remote SSH, use the same host alias `claude-vm`.

---

## Container Lifecycle

```bash
# Start (detached)
podman compose up -d

# Stop (preserves all data)
podman compose down

# Restart
podman compose restart

# Rebuild (after Dockerfile changes — data still preserved)
podman compose up -d --build

# View logs
podman compose logs -f

# Shell in without SSH (emergency)
podman exec -it -u developer claude-dev-vm zsh
```

---

## Persistent Volumes

All data survives `podman compose down` and `podman compose up -d --build`.

| Volume | Mount Point | What's Stored |
|--------|-------------|---------------|
| `claude-vm-projects` | `~/projects` | Your cloned repos, code, work |
| `claude-vm-aws-config` | `~/.aws` | AWS credentials and config |
| `claude-vm-claude-config` | `~/.claude` | Claude settings, memory, rules, plugins |
| `claude-vm-claude-code-config` | `~/.config/claude-code` | Claude Code app settings |
| `claude-vm-local-bin` | `~/.local` | Installed tools, pip packages |
| `claude-vm-claude-setup` | `~/claude-auto-setup` | The setup repo (won't re-clone) |
| `claude-vm-ssh-host-keys` | `/etc/ssh/ssh_host_keys` | SSH host keys (no warnings on rebuild) |

### Nuke and start fresh

To destroy all data and start from scratch:

```bash
podman compose down
podman volume rm $(podman volume ls -q --filter name=claude-vm-)
podman compose up -d --build
```

To reset only one volume (e.g., Claude config):

```bash
podman compose down
podman volume rm claude-vm-claude-config
podman compose up -d
```

---

## Environment Variables

Set in `.env` (loaded automatically by docker-compose):

| Variable | Required | Description |
|----------|----------|-------------|
| `SSH_PUBLIC_KEY` | Yes | Your public SSH key for container access |
| `AWS_BEARER_TOKEN_BEDROCK` | Yes* | Bedrock bearer token |
| `AWS_ACCESS_KEY_ID` | Yes* | IAM access key (alternative to bearer token) |
| `AWS_SECRET_ACCESS_KEY` | Yes* | IAM secret key |
| `AWS_SESSION_TOKEN` | No | For temporary/assumed role credentials |
| `AWS_REGION` | No | Default: `us-east-1` |
| `ANTHROPIC_MODEL` | No | Default: `us.anthropic.claude-sonnet-4-20250514-v1:0` |
| `GIT_USER_NAME` | No | Default: `Asik Mydeen` |
| `GIT_USER_EMAIL` | No | Default: `writetoasik@gmail.com` |

*Either bearer token OR IAM credentials required.

### Available Bedrock Models

```env
# Sonnet 4 (default — fast, good balance)
ANTHROPIC_MODEL=us.anthropic.claude-sonnet-4-20250514-v1:0

# Opus 4 (most capable, slower)
ANTHROPIC_MODEL=us.anthropic.claude-opus-4-0-20250514-v1:0

# Haiku 4.5 (fastest, cheapest)
ANTHROPIC_MODEL=us.anthropic.claude-haiku-4-5-20251001-v1:0
```

---

## GitHub SSH

The container has your GitHub SSH key (`id_ed25519_github`) baked into the image. It's configured in `~/.ssh/config`:

```
Host github.com
  AddKeysToAgent yes
  IdentityFile ~/.ssh/id_ed25519_github
  StrictHostKeyChecking accept-new
```

Test from inside the container:

```bash
ssh -T git@github.com
# Hi asikmydeen! You've successfully authenticated...
```

**Security note**: The private key is in `config/ssh/` (gitignored). Don't commit it. If you share this repo, others must provide their own key.

---

## claude-auto-setup

Pre-installed at `~/claude-auto-setup`. Runs automatically on first boot.

### What it installs

- **59 commands** across 7 developer roles and 37 specialist sub-agents
- **11 rules** — code quality, security, testing, git workflows, orchestration
- **9 native agents** — code-reviewer, debugger, test-writer, explorer, security-auditor, etc.
- **15 plugins** — LSP, context7, serena, security-guidance, PR review toolkit, etc.
- **Multi-agent dispatcher** (`dispatch.sh`) for routing tasks to optimal providers

### Re-run setup

If you need to re-install or update:

```bash
cd ~/claude-auto-setup
git pull
bash install.sh
```

Or force a fresh install by removing the marker:

```bash
rm ~/.claude-auto-setup-done
# Then restart the container
```

---

## Fleet Mode (Multi-Agent Container Orchestration)

Fleet is a parallel task execution system in `~/claude-auto-setup/fleet/` that spawns containers to run multiple AI agents concurrently.

**Fleet is pre-configured and works out of the box in this VM.**

### How It Works

Fleet containers are **siblings** of the VM, not nested. The host Podman socket is mounted into the VM, so when fleet runs `docker run`, it talks to the host's Podman daemon:

```
macOS Host
└── Podman Machine (libkrun VM)
    ├── claude-dev-vm (this VM)
    │   └── fleet.ts orchestrator
    │       └── uses Docker CLI → /var/run/docker.sock
    │
    ├── fleet-agent-1 (sibling container)  ← spawned by fleet
    ├── fleet-agent-2 (sibling container)  ← spawned by fleet
    └── fleet-agent-N (sibling container)  ← spawned by fleet
```

This is the "Docker-out-of-Docker" (DooD) pattern — no nested containers, no `--privileged` flag, no performance overhead. Fleet containers share the same Podman runtime as the VM itself.

### Pre-configured Components

| Component | Status | Details |
|-----------|--------|---------|
| Docker CLI (client) | Installed | v29+ talks to Podman socket |
| Podman socket mount | Mounted | `/run/podman/podman.sock` → `/var/run/docker.sock` |
| `docker` group | Configured | `developer` user has socket access |
| Fleet config | `~/.claude/fleet/accounts.json` | Created via `--init` |
| Fleet image | `claude-fleet:latest` (~2GB) | Built via `--build-image` |

### First-Time Setup (Inside the VM)

```bash
# 1. Initialize fleet config
bun ~/claude-auto-setup/fleet/fleet.ts --init

# 2. Configure accounts with your Bedrock credentials
#    (or use the Python helper below)
python3 << 'EOF'
import json, os
cfg = {
  "accounts": [{
    "id": "bedrock-1",
    "label": "Bedrock via bearer token",
    "credentials": {
      "CLAUDE_CODE_USE_BEDROCK": "1",
      "AWS_BEARER_TOKEN_BEDROCK": os.environ.get("AWS_BEARER_TOKEN_BEDROCK", ""),
      "AWS_REGION": "us-east-1",
      "ANTHROPIC_MODEL": "us.anthropic.claude-sonnet-4-20250514-v1:0"
    }
  }],
  "settings": {
    "maxConcurrent": 4,
    "cooldownMs": 60000,
    "containerImage": "claude-fleet:latest",
    "runtime": "docker",
    "taskTimeoutMs": 600000,
    "containerMemory": "4g",
    "containerCpus": "2",
    "maxTotalSpawns": 500
  }
}
with open(os.path.expanduser("~/.claude/fleet/accounts.json"), "w") as f:
    json.dump(cfg, f, indent=2)
print("Fleet config written")
EOF

# 3. Build the fleet agent image
bun ~/claude-auto-setup/fleet/fleet.ts --build-image
```

### Configuring Fleet Accounts

Fleet needs API credentials to run agents. Three options:

#### Option A: CSV file (easiest for multiple Bedrock keys)

Create a CSV file with one key per line:

```bash
# keys.csv — one ABSK key per line
cat > ~/keys.csv << 'EOF'
ABSKkey1...
ABSKkey2...
ABSKkey3...
EOF

# Load into fleet
fleet --from-csv ~/keys.csv --region us-east-1
```

Supported CSV formats:

| Format | Example |
|--------|---------|
| One key per line | `ABSKkey1\nABSKkey2\nABSKkey3` |
| Comma-separated | `ABSKkey1,ABSKkey2,ABSKkey3` |
| Label + key | `Bedrock 1,ABSKkey1\nBedrock 2,ABSKkey2` |
| With header row | `key\nABSKkey1\nABSKkey2` (auto-detected, skipped) |

All keys are treated as Bedrock bearer tokens. This **replaces** existing accounts.

#### Option B: Copy from host machine

If you already have fleet configured on your macOS host:

```bash
# Run from host terminal (not inside the VM)
podman cp ~/.claude/fleet/accounts.json claude-dev-vm:/home/developer/.claude/fleet/accounts.json
podman exec claude-dev-vm chown developer:developer /home/developer/.claude/fleet/accounts.json
```

Verify inside the VM:

```bash
fleet --accounts
```

#### Option C: Manual JSON setup

```bash
fleet --init   # creates ~/.claude/fleet/accounts.json
vim ~/.claude/fleet/accounts.json
```

Edit the JSON directly — see the Python helper in the "First-Time Setup" section above for a template.

### Fleet Usage

```bash
cd ~/projects/your-repo

# Build the fleet agent image (required once)
fleet --build-image

# Pool mode — run a list of tasks in parallel
fleet --pool tasks.json --workers 4

# Scatter mode — same prompt, multiple agents, pick best result
fleet --scatter "implement feature X" --workers 3 --strategy best

# Decompose mode — break a complex task into subtasks automatically
fleet --decompose "build auth system" --workers 4

# Pipeline mode — sequential stages with parallel workers per stage
fleet --pipeline "add search" --stages research,implement,test,review

# Check status / stop
fleet --status
fleet --accounts
fleet --stop
```

### Fleet Modes Explained

| Mode | What it does | Use when |
|------|-------------|----------|
| `--pool` | Runs N independent tasks in parallel across worker containers | You have a list of unrelated tasks |
| `--scatter` | Sends the same prompt to N agents, compares results | You want multiple approaches to the same problem |
| `--decompose` | Auto-breaks a complex task into subtasks, runs in parallel | Large feature that can be parallelized |
| `--pipeline` | Sequential stages (research → implement → test → review) | Structured workflow with dependencies |

### Fleet vs Claude Code Sub-agents

| Feature | Fleet | Claude Code `Agent()` |
|---------|-------|-----------------------|
| **Isolation** | Full container per agent | Subprocess, shared filesystem |
| **Concurrency** | True parallel (separate containers) | Cooperative (shared context) |
| **Multi-account** | Yes (different API keys per worker) | No (single auth) |
| **Rate-limit handling** | Auto-cooldown, account rotation | Manual |
| **Use case** | Batch processing, cost-sensitive parallel work | In-session exploration, review |

---

## Resource Limits

Default limits (adjustable in `docker-compose.yml`):

```yaml
deploy:
  resources:
    limits:
      memory: 8G
      cpus: "4.0"
    reservations:
      memory: 2G
      cpus: "1.0"
```

Increase if running fleet or multiple Claude sessions.

---

## Troubleshooting

### Can't SSH in

```bash
# Check container is running
podman ps

# Check logs for SSH errors
podman logs claude-dev-vm

# Emergency shell (bypasses SSH)
podman exec -it -u developer claude-dev-vm zsh

# Verify your SSH key matches
podman exec claude-dev-vm cat /home/developer/.ssh/authorized_keys
```

### Claude won't authenticate

```bash
# Inside the VM — verify env vars are set
env | grep -E "(BEDROCK|BEARER|ANTHROPIC)"

# Should show:
# CLAUDE_CODE_USE_BEDROCK=1
# AWS_BEARER_TOKEN_BEDROCK=ABSK...
# ANTHROPIC_MODEL=us.anthropic.claude-sonnet-4-20250514-v1:0

# If missing, check .env on the host and restart:
podman compose restart
```

### Bearer token expired

Update `.env` on the host with the new token, then:

```bash
podman compose restart
```

The entrypoint regenerates `~/.zshrc.local` with fresh env vars on every start.

### Host key warning after rebuild

Should not happen (host keys are in a persistent volume). If it does:

```bash
ssh-keygen -R "[localhost]:2222"
```

### Volume permissions issues

```bash
# Inside the VM
sudo chown -R developer:developer ~/projects ~/. ~/.claude
```

### Rebuilding the image

Code changes to Dockerfile/entrypoint require a rebuild. Data is preserved:

```bash
podman compose up -d --build
```

### Updating Claude Code

```bash
# Inside the VM
sudo npm install -g @anthropic-ai/claude-code@latest
```

---

## File Structure

```
personal-docker-vm/
├── Dockerfile           # Ubuntu 24.04 image with all tools
├── docker-compose.yml   # Podman-compatible compose with volumes
├── entrypoint.sh        # Bootstrap: SSH keys, env vars, git config, setup
├── env.example          # Template — copy to .env
├── start.sh             # One-command launcher
├── .gitignore           # Protects .env and SSH private keys
├── config/
│   ├── zshrc            # Zsh config (adapted for Linux container)
│   └── ssh/
│       ├── id_ed25519_github      # GitHub SSH private key (gitignored)
│       └── id_ed25519_github.pub  # GitHub SSH public key (gitignored)
└── README.md
```

---

## Architecture

```
macOS Host (Podman)
└── podman machine (libkrun VM)
    └── claude-dev-vm container (Ubuntu 24.04)
        ├── sshd (port 22 → host:2222)
        ├── zsh + oh-my-zsh
        ├── Claude Code CLI (Bedrock auth)
        ├── claude-auto-setup (59 cmds, 11 rules, 9 agents)
        ├── ~/projects/ (persistent volume)
        │   └── famcal/, your-repo/, ...
        └── [optional] fleet containers (if runtime installed)
            ├── fleet-agent-1
            ├── fleet-agent-2
            └── ...
```
