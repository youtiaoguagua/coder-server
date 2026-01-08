# ==========================================
# 阶段 1: 获取 UV (利用官方镜像作为构建层)
# ==========================================
FROM ghcr.io/astral-sh/uv:latest AS uv-source

# ==========================================
# 阶段 2: 主镜像构建 (基于 LinuxServer)
# ==========================================
FROM lscr.io/linuxserver/code-server:latest

# 切换到 root 进行安装
USER root

# ------------------------------------------
# 1. 安装基础工具、Python、Node.js 和 Docker CLI
# ------------------------------------------
# 注意：我们添加了 build-essential 和 python3-dev，这对于编译某些 python 库是必须的
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
    && curl -fsSL https://get.docker.com | sh \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------
# 2. 安装 pnpm
# ------------------------------------------
# 通过 npm 全局安装 pnpm，并设置 npm 镜像源（可选，国内建议开启）
RUN npm install -g pnpm && \
    npm config set registry https://registry.npmmirror.com

# ------------------------------------------
# 3. 安装 uv (从阶段 1 复制)
# ------------------------------------------
# 直接把编译好的二进制文件拿过来，比在容器里 curl 下载脚本更安全、更稳定
COPY --from=uv-source /uv /usr/local/bin/uv
COPY --from=uv-source /uvx /usr/local/bin/uvx

# 配置 uv 的环境变量 (让它知道不用创建 venv，直接装在系统里，或者根据你喜好调整)
# 这里的配置是让 uv 更加顺手：
# UV_LINK_MODE=copy: 避免在 docker 跨层文件系统中的硬链接问题
ENV UV_LINK_MODE=copy \
    UV_PYTHON_INSTALL_DIR=/usr/local/bin

# ------------------------------------------
# 4. 关键：注入 Docker 权限自适应脚本 (S6 机制)
# ------------------------------------------
# 这一步确保你挂载 /var/run/docker.sock 后，code-server 用户能直接用 docker
RUN echo '#!/bin/bash\n\
if [ -S /var/run/docker.sock ]; then\n\
    DOCKER_GID=$(stat -c %g /var/run/docker.sock)\n\
    # 如果组已存在则不报错，否则创建\n\
    groupadd -g $DOCKER_GID docker-host || true\n\
    # 将 abc (LSIO 默认用户) 加入该组\n\
    usermod -aG $DOCKER_GID abc\n\
fi' > /etc/cont-init.d/99-docker-permissions && \
    chmod +x /etc/cont-init.d/99-docker-permissions

# ------------------------------------------
# 5. 用户环境配置 (可选)
# ------------------------------------------
# 切换回 abc 用户（为了安全或者测试），但在 LSIO 镜像中
# 最好保持 Dockerfile 结尾不指定 USER，让 S6 进程管理器处理
# 这里仅仅是为了演示如果需要在构建时做用户级操作：
# USER abc
# RUN pnpm config set store-dir /home/coder/.local/share/pnpm/store
# USER root

# 保持默认入口
