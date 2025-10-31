#!/bin/sh

# 获取配置文件URL，可以从环境变量中获取，如果未设置则报错
CONFIG_URL=${CLASH_CONFIG_URL:?Error: CLASH_CONFIG_URL environment variable is not set.}
CONFIG_FILE="/root/.config/clash/config.yaml" # Clash默认或你指定的配置文件路径

echo "Downloading Clash configuration from $CONFIG_URL..."

# 确保配置文件目录存在
mkdir -p "$(dirname "$CONFIG_FILE")"

# 使用curl下载配置文件，-sL表示静默下载并跟随重定向
curl -sL "$CONFIG_URL" -o "$CONFIG_FILE"

if [ $? -eq 0 ]; then
    echo "Clash configuration downloaded successfully."
else
    echo "Failed to download Clash configuration. Exiting."
    exit 1
fi

echo "Starting Clash service..."
# 启动Clash服务，使用下载的配置文件
exec /usr/local/bin/mihomo -d "$(dirname "$CONFIG_FILE")"
