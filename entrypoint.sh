#!/bin/sh

# 获取配置文件URL，可以从环境变量中获取，如果未设置则报错
CONFIG_URL=${CLASH_CONFIG_URL:?Error: CLASH_CONFIG_URL environment variable is not set.}
CONFIG_FILE="/root/.config/clash/config.yaml" # Clash默认或你指定的配置文件路径
CLASH_API_URL="http://127.0.0.1:9090" # Clash External Controller API 地址
# 配置文件检查间隔，默认1小时 (3600秒)，可以通过环境变量 CONFIG_POLLING_INTERVAL 配置
CONFIG_POLLING_INTERVAL=${CONFIG_POLLING_INTERVAL:-3600}

echo "Downloading initial Clash configuration from $CONFIG_URL..."

# 确保配置文件目录存在
mkdir -p "$(dirname "$CONFIG_FILE")"

# 使用curl下载配置文件，-sL表示静默下载并跟随重定向
curl -sL "$CONFIG_URL" -o "$CONFIG_FILE"

if [ $? -ne 0 ]; then
    echo "Failed to download initial Clash configuration. Exiting."
    exit 1
fi
echo "Initial Clash configuration downloaded successfully."

echo "Starting Clash service..."
# 启动Clash服务，使用下载的配置文件
# 注意: exec 会替换当前shell进程，所以后台的配置检查循环需要在Clash启动后运行
/usr/local/bin/mihomo -d "$(dirname "$CONFIG_FILE")" &
CLASH_PID=$! # 获取Clash进程ID

echo "Clash service started with PID $CLASH_PID. Waiting for API to be ready..."
# 等待Clash服务启动并确保API可用
sleep 10 # 给予Clash足够的启动时间

# 进入无限循环，定期检查和加载配置文件
while true; do
    echo "Waiting for $CONFIG_POLLING_INTERVAL seconds before checking for config updates..."
    sleep "$CONFIG_POLLING_INTERVAL"

    if ! kill -0 "$CLASH_PID" > /dev/null 2>&1; then
        echo "Clash process ($CLASH_PID) is no longer running. Exiting updater loop."
        exit 1
    fi

    echo "Checking for Clash configuration updates from $CONFIG_URL..."
    TEMP_CONFIG_FILE="/tmp/clash_config_new.yaml"
    curl -sL "$CONFIG_URL" -o "$TEMP_CONFIG_FILE"

    if [ $? -ne 0 ]; then
        echo "Failed to download new configuration. Will retry later."
        rm -f "$TEMP_CONFIG_FILE" # 清理临时文件
        continue
    fi
    echo "New configuration downloaded to $TEMP_CONFIG_FILE."

    # 验证新配置文件的有效性
    echo "Validating new configuration using mihomo..."
    /usr/local/bin/mihomo -t -f "$TEMP_CONFIG_FILE" > /dev/null 2>&1

    if [ $? -ne 0 ]; then
        echo "New configuration is invalid. Keeping current configuration."
        rm -f "$TEMP_CONFIG_FILE" # 清理临时文件
        continue
    fi
    echo "New configuration is valid."

    # 比较新旧配置文件，如果内容相同则无需重新加载
    if cmp -s "$CONFIG_FILE" "$TEMP_CONFIG_FILE"; then
        echo "Configuration file content is identical. No reload needed."
        rm -f "$TEMP_CONFIG_FILE" # 清理临时文件
        continue
    fi

    echo "New configuration differs from current one. Reloading Clash service with new configuration via API..."
    
    # 替换当前配置文件
    mv "$TEMP_CONFIG_FILE" "$CONFIG_FILE"

    # 调用Clash API进行热加载
    # 通常是向 /configs 发送 PUT 请求，带上新的配置文件路径
    RELOAD_RESPONSE=$(curl -X PUT -H "Content-Type: application/json" \
                          -d "{\"path\": \"$CONFIG_FILE\"}" \
                          "$CLASH_API_URL/configs" 2>/dev/null)

    if [ $? -eq 0 ]; then
        # 检查API响应，Clash Premium API成功时通常返回204 No Content，或者一个空的JSON {}
        # 如果有错误，会返回包含 "error" 字段的JSON
        if echo "$RELOAD_RESPONSE" | grep -q '^\s*{}'; then # 检查是否是空JSON对象
            echo "Clash configuration reloaded successfully via API."
        elif echo "$RELOAD_RESPONSE" | jq -e 'has("error")' >/dev/null 2>&1; then
            ERROR_MESSAGE=$(echo "$RELOAD_RESPONSE" | jq -r '.error')
            echo "Clash configuration API reload failed: $ERROR_MESSAGE."
            echo "If this issue persists, a manual restart of the container might be necessary."
        else
            echo "Clash configuration API reload completed with unknown response: $RELOAD_RESPONSE."
        fi
    else
        echo "Clash configuration API reload failed (curl error). Response: $RELOAD_RESPONSE"
        echo "If this issue persists, a manual restart of the container might be necessary."
    fi
done
