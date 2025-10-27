# 使用Clash的官方或常用基础镜像。
# 每次此工作流运行时，如果基础镜像有更新，Docker会拉取新版本。
FROM tinyserve/mihomo:latest

# 安装curl，用于下载配置文件
# 对于基于Alpine的镜像（如dreamacro/clash:latest可能基于Alpine），使用apk
# 如果是基于Debian/Ubuntu，则使用 apt-get update && apt-get install -y curl
RUN apk add --no-cache curl

# 将启动逻辑直接嵌入到 ENTRYPOINT 中
# 使用 /bin/sh -c "..." 允许我们执行一个字符串作为shell命令
ENTRYPOINT ["/bin/sh", "-c", "\
    CONFIG_URL=${CLASH_CONFIG_URL:?Error: CLASH_CONFIG_URL environment variable is not set.}; \
    CONFIG_FILE=\"/etc/mihomo/config.yaml\"; \
    \
    echo \"Downloading Clash configuration from $CONFIG_URL...\"; \
    mkdir -p \"$(dirname \"$CONFIG_FILE\")\"; \
    curl -sL \"$CONFIG_URL\" -o \"$CONFIG_FILE\"; \
    \
    if [ $? -eq 0 ]; then \
        echo \"Clash configuration downloaded successfully.\"; \
    else \
        echo \"Failed to download Clash configuration. Exiting.\"; \
        exit 1; \
    fi; \
    \
    echo \"Starting Clash service...\"; \
    exec clash -d \"$(dirname \"$CONFIG_FILE\")\"; \
"]

# 暴露Clash服务的端口
EXPOSE 7890 7894 9090
