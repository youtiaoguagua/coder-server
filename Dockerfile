# ==========================================
# 阶段 1: 获取 UV (Python 工具)
# ==========================================
FROM ghcr.io/astral-sh/uv:latest AS uv-source

# ==========================================
# 阶段 2: 获取 Docker CLI
# ==========================================
FROM library/docker:latest AS docker-source

# ==========================================
# 阶段 3: 获取 Golang (新增)
# ==========================================
# 使用官方镜像，确保获得最新版 Go
FROM library/golang:latest AS go-source

# ==========================================
# 阶段 4: 主镜像构建
# ==========================================
FROM lscr.io/linuxserver/code-server:latest

USER root

# 1. 安装基础依赖
# build-essential 和 python3-dev 对编译 C 扩展库至关重要
RUN apt-get update && apt-get install -y \
    curl git wget sudo \
    build-essential \
    python3 python3-dev python3-venv python3-pip \
    && rm -rf /var/lib/apt/lists/*

# 2. 配置 pnpm 环境
ENV PNPM_HOME="/usr/local/share/pnpm"
# ⬇️ 这里把 Go 的 bin 目录也加进 PATH
ENV PATH="$PNPM_HOME:/usr/local/go/bin:$PATH"

# 3. 安装 pnpm 并通过它安装 Node.js LTS
RUN curl -fsSL https://get.pnpm.io/install.sh | SHELL_CONFIG_FILE=/dev/null bash - && \
    pnpm env use --global lts

# 4. 从各阶段复制工具
# --- UV ---
COPY --from=uv-source /uv /usr/local/bin/uv
COPY --from=uv-source /uvx /usr/local/bin/uvx
# --- Docker ---
COPY --from=docker-source /usr/local/bin/docker /usr/local/bin/docker
# --- Golang (新增) ---
COPY --from=go-source /usr/local/go /usr/local/go

# 5. 环境变量微调
ENV UV_LINK_MODE=copy \
    UV_PYTHON_INSTALL_DIR=/usr/local/bin \
    # Go 默认 GOPATH 配置 (可选，方便直接用 go install)
    GOPATH=/home/coder/go

# 6. 注入 Docker 权限自适应脚本
COPY <<'EOF' /etc/cont-init.d/99-docker-permissions
#!/bin/bash
if [ -S /var/run/docker.sock ]; then
    DOCKER_GID=$(stat -c %g /var/run/docker.sock)
    groupadd -g $DOCKER_GID docker-host || true
    usermod -aG $DOCKER_GID abc
fi
EOF
RUN chmod +x /etc/cont-init.d/99-docker-permissions

# 7. 配置镜像源 (可选)
RUN pnpm config set registry https://registry.npmmirror.com && \
    go env -w GOPROXY=https://goproxy.cn,direct

# 保持默认启动
