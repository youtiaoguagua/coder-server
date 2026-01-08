FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    apt-get update && \
    apt-get install -y docker.io && \
    rm -rf /var/lib/apt/lists/*

# Create docker permissions script using heredoc
RUN cat > /docker-entrypoint.sh << 'EOF'
#!/bin/bash
set -e

# Fix docker socket permissions if it exists
if [ -S /var/run/docker.sock ]; then
    chmod 666 /var/run/docker.sock
fi

# Execute the main command
exec "$@"
EOF

RUN chmod +x /docker-entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/bin/bash"]
