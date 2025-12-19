# Install Scripts

> 🚀 One-liner installation scripts for development tools on Linux.

[![Go](https://img.shields.io/badge/Go-00ADD8?style=for-the-badge&logo=go&logoColor=white)](#-go)
[![Node.js](https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)](#-nodejs)
[![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)](#-python)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](#-postgresql)
[![Zsh](https://img.shields.io/badge/Zsh-F15A24?style=for-the-badge&logo=zsh&logoColor=white)](#-zsh)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](#-docker)

---

## 📑 Table of Contents

- [Features](#-features)
- [Go](#-go)
- [Node.js](#-nodejs)
- [Python](#-python)
- [PostgreSQL](#-postgresql)
- [Zsh](#-zsh)
- [Docker](#-docker)
- [Other Tools](#-other-tools)
  - [OpenAI Codex](#openai-codex)
  - [Google Gemini CLI](#google-gemini-cli)
  - [Claude Code](#claude-code)
  - [Cursor](#cursor)
  - [OpenCode](#opencode)
  - [Factory AI](#factory-ai)
  - [Kiro](#kiro)
  - [Kilocode CLI](#kilocode-cli)
- [Tunel-Antigravity-Linux](#-tunel-antigravity-linux)
- [License](#-license)


---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🔒 **Checksum Verification** | SHA256 verification for secure downloads |
| 🔍 **Auto-detect Architecture** | Supports amd64, arm64, armv7l, etc. |
| 📦 **Multi-distro Support** | Works with apt, dnf, yum, pacman, apk, zypper |
| 🔄 **Idempotent** | Safe to run multiple times |
| 🎨 **Colored Output** | Beautiful CLI experience |
| ⚙️ **Configurable** | Environment variables for customization |
| 🧹 **Auto-cleanup** | No leftover temp files |

---

## 🐹 Go

**Description:** Go (Golang) is a statically typed, compiled programming language designed at Google. Known for simplicity, efficiency, and excellent concurrency support.

**Install:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-go.sh)
```

**Usage:**
```bash
# Install specific version
bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-go.sh) 1.22.5

# With environment variables
GO_VERSION=1.22.5 VERBOSE=1 bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-go.sh)
```

**Environment Variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `GO_VERSION` | auto-detect | Go version to install |
| `PREFIX` | `/usr/local` | Installation prefix |
| `VERBOSE` | `0` | Enable debug output |

**Official Source:** [https://go.dev/dl/](https://go.dev/dl/)

---

## 📗 Node.js

**Description:** Node.js is a JavaScript runtime built on Chrome's V8 engine. Enables server-side JavaScript execution with excellent npm ecosystem.

**Install:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-node22.sh)
```

**Usage:**
```bash
# Install specific version
bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-node22.sh) 22 22.12.0

# Force tar.gz instead of tar.xz
FORCE_TARGZ=1 bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-node22.sh)
```

**Environment Variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `NODE_MAJOR` | `22` | Node.js major version |
| `NODE_VERSION` | auto-detect | Specific version |
| `NPM_VERSION` | `11.7.0` | npm version to install |
| `AUTO_UPDATE_NPM` | `1` | Auto-upgrade npm |
| `FORCE_TARGZ` | `0` | Force tar.gz (skip xz) |
| `VERBOSE` | `0` | Enable debug output |

**Official Source:** [https://nodejs.org/en/download](https://nodejs.org/en/download)

---

## 🐍 Python

**Description:** Python is a high-level, interpreted programming language known for readability and versatility. Used in web development, data science, AI/ML, and automation.

**Install:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-python.sh)
```

**Usage:**
```bash
# Install specific version
bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-python.sh) 3.12.4

# Install via pyenv
INSTALL_METHOD=pyenv bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-python.sh)

# Without optimizations (faster build)
ENABLE_OPTIMIZATIONS=0 bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-python.sh)
```

**Environment Variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `PYTHON_VERSION` | auto-detect | Python version |
| `INSTALL_METHOD` | `source` | `source` or `pyenv` |
| `PREFIX` | `/usr/local` | Installation prefix |
| `ENABLE_OPTIMIZATIONS` | `1` | Enable PGO/LTO |
| `SKIP_DEPS` | `0` | Skip build dependencies |
| `VERBOSE` | `0` | Enable debug output |

**Official Source:** [https://www.python.org/downloads/](https://www.python.org/downloads/)

---

## 🐘 PostgreSQL

**Description:** PostgreSQL is a powerful, open-source object-relational database system with over 35 years of active development. Known for reliability, feature robustness, and performance.

**Install:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-postgresql.sh)
```

**Usage:**
```bash
# Install specific version
bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-postgresql.sh) 17

# With custom user and password
PG_USER=myuser PG_PASSWORD=mypassword bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-postgresql.sh)

# Connect after installation
psql -U reza -d reza -h localhost
```

**Environment Variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `PG_VERSION` | `17` | PostgreSQL version |
| `PG_USER` | `reza` | Database user to create |
| `PG_PASSWORD` | `reza` | User password |
| `PG_DATABASE` | `reza` | Database to create |
| `PG_PORT` | `5432` | PostgreSQL port |
| `VERBOSE` | `0` | Enable debug output |

**Connection String:**
```
postgresql://reza:reza@localhost:5432/reza
```

**Official Source:** [https://www.postgresql.org/download/](https://www.postgresql.org/download/)

---

## � Zsh

**Description:** Z Shell (Zsh) is a powerful shell with advanced features including better auto-completion, syntax highlighting, and plugin support. This installer sets up a complete environment with Powerlevel10k theme and useful plugins.

**Install:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-zsh.sh)
```

**Usage:**
```bash
# Install for specific user
ZSH_USER=myuser bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-zsh.sh)

# Skip changing default shell
SKIP_SHELL=1 bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-zsh.sh)

# Verbose mode
VERBOSE=1 bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-zsh.sh)
```

**What's Included:**
| Component | Description |
|-----------|-------------|
| Zinit | Fast plugin manager |
| Powerlevel10k | Beautiful theme |
| zsh-syntax-highlighting | Command highlighting |
| zsh-autosuggestions | Fish-like suggestions |
| zsh-completions | Extra completions |
| fzf | Fuzzy finder |
| exa | Modern ls |
| MesloLGS NF | Nerd fonts |

**Environment Variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `ZSH_USER` | current user | User to configure |
| `VERBOSE` | `0` | Enable debug output |
| `SKIP_DEPS` | `0` | Skip dependencies |
| `SKIP_SHELL` | `0` | Skip shell change |

**Useful Aliases (after install):**
```bash
profile     # Edit .zshrc
rprofile    # Reload .zshrc
gupp "msg"  # Git push with message
supdate     # System update
```

**Official Source:** [https://www.zsh.org/](https://www.zsh.org/)

---

## 🐳 Docker

**Description:** Docker is a platform for developing, shipping, and running applications in containers. Containers package code and dependencies together, ensuring consistent environments.

**Install:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-docker.sh)
```

**Usage:**
```bash
# Specify user to add to docker group
DOCKER_USER=myuser bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-docker.sh)

# Skip docker-compose
SKIP_COMPOSE=1 bash <(curl -fsSL https://raw.githubusercontent.com/Productions-code/Install/master/install-docker.sh)
```

**What's Installed:**
| Component | Description |
|-----------|-------------|
| docker-ce | Docker Engine |
| docker-ce-cli | Docker CLI |
| containerd.io | Container runtime |
| docker-buildx-plugin | Build tool |
| docker-compose-plugin | Compose v2 |

**Environment Variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `DOCKER_USER` | current user | User to add to docker group |
| `SKIP_COMPOSE` | `0` | Skip docker-compose |
| `SKIP_GROUP` | `0` | Skip user group setup |
| `VERBOSE` | `0` | Enable debug output |

**Quick Commands:**
```bash
docker run hello-world     # Test Docker
docker ps                  # List containers
docker compose up -d       # Start services
```

**Official Source:** [https://docs.docker.com/engine/install/](https://docs.docker.com/engine/install/)

---

## 🛠️ Other Tools

### OpenAI Codex

**Description:** AI pair programmer powered by OpenAI. Assists with code generation, debugging, and documentation.

**Install:**
```bash
npm i -g @openai/codex
```

**Official Source:** [https://www.npmjs.com/package/@openai/codex](https://www.npmjs.com/package/@openai/codex)

---

### Google Gemini CLI

**Description:** Command-line interface for Google's Gemini AI models. Enables AI assistance directly from terminal.

**Install:**
```bash
npm install -g @google/gemini-cli
```

**Official Source:** [https://www.npmjs.com/package/@google/gemini-cli](https://www.npmjs.com/package/@google/gemini-cli)

---

### Claude Code

**Description:** Anthropic's Claude AI assistant for coding. Available as CLI tool for Windows.

**Install (Windows PowerShell):**
```powershell
irm https://claude.ai/install.ps1 | iex
```

**Official Source:** [https://claude.ai/](https://claude.ai/)

---

### Cursor

**Description:** AI-first code editor built for pair programming. Features intelligent code completion and AI chat.

**Install:**
```bash
curl https://cursor.com/install -fsS | bash
```

**Official Source:** [https://cursor.com/](https://cursor.com/)

---

### OpenCode

**Description:** Open-source AI coding assistant. Self-hostable and privacy-focused alternative.

**Install:**
```bash
curl -fsSL https://raw.githubusercontent.com/opencode-ai/opencode/refs/heads/main/install | bash
```

**Official Source:** [https://github.com/opencode-ai/opencode](https://github.com/opencode-ai/opencode)

---

### Factory AI

**Description:** AI-powered development platform for automated code generation and deployment.

**Install:**
```bash
curl -fsSL https://app.factory.ai/cli | sh
```

**Official Source:** [https://factory.ai/](https://factory.ai/)

---

### Kiro

**Description:** AI coding assistant with focus on developer productivity and code quality.

**Install:**
```bash
curl -fsSL https://cli.kiro.dev/install | bash
```

**Official Source:** [https://kiro.dev/](https://kiro.dev/)

---

### Kilocode CLI

**Description:** Command-line tools for code analysis and generation.

**Install:**
```bash
npm install -g @kilocode/cli
```

**Official Source:** [https://www.npmjs.com/package/@kilocode/cli](https://www.npmjs.com/package/@kilocode/cli)

---

## 📁 Tunel-Antigravity-Linux

| Project | Description |
|---------|-------------|
| [Tunel-Antigravity-Linux](https://github.com/Productions-code/Tunel-Antigravity-Linux) | All Tunnel ai connection access |

```bash
git clone https://github.com/Productions-code/Tunel-Antigravity-Linux && cd Tunel-Antigravity-Linux && make quick-start
```

---

## 📄 License

MIT © Productions-code
