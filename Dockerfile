# ==========================================
# 阶段 1: 获取 UV (工具层)
# ==========================================
FROM ghcr.io/astral-sh/uv:latest AS uv-source

# ==========================================
# 阶段 2: 获取 Docker CLI (工具层)
# ==========================================
# ⬇️ 新增：直接从官方 Docker 镜像获取客户端二进制文件
# 这比运行安装脚本快得多，而且完全避免了 systemctl 报错
FROM library/docker:latest AS docker-source

# ==========================================
# 阶段 3: 主镜像构建 (基于 LinuxServer)
# ==========================================
FROM lscr.io/linuxserver/code-server:latest

# 切换到 root 进行安装
USER root

# ------------------------------------------
# 1. 安装基础工具、Python、Node.js
# ------------------------------------------
# 注意：删除了 curl | sh 安装 docker 的部分
RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    sudo \
    build-essential \
    python3 \
    python3-dev \
    python3-venv \
    python3-pip \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------
# 2. 安装 pnpm
# ------------------------------------------
RUN npm install -g pnpm && \
    npm config set registry https://registry.npmmirror.com

# ------------------------------------------
# 3. 安装 uv (从阶段 1 复制)
# ------------------------------------------
COPY --from=uv-source /uv /usr/local/bin/uv
COPY --from=uv-source /uvx /usr/local/bin/uvx

ENV UV_LINK_MODE=copy \
    UV_PYTHON_INSTALL_DIR=/usr/local/bin

# ------------------------------------------
# 4. 安装 Docker CLI (从阶段 2 复制)
# ------------------------------------------
# ⬇️ 修复点：直接复制二进制文件，不运行安装脚本
COPY --from=docker-source /usr/local/bin/docker /usr/local/bin/docker

# ------------------------------------------
# 5. 关键：注入 Docker 权限自适应脚本
# ------------------------------------------
# 使用 heredoc 写入脚本 (注意：如果你之前的 docker 版本不支持 <<EOF，请告诉我)
COPY <<'EOF' /etc/cont-init.d/99-docker-permissions
#!/bin/bash
if [ -S /var/run/docker.sock ]; then
    DOCKER_GID=$(stat -c %g /var/run/docker.sock)
    # 如果组已存在则不报错，否则创建
    groupadd -g $DOCKER_GID docker-host || true
    # 将 abc (LSIO 默认用户) 加入该组
    usermod -aG $DOCKER_GID abc
fi
EOF

RUN chmod +x /etc/cont-init.d/99-docker-permissions

# 保持默认入口
