# 使用Clash的官方或常用基础镜像。
# 每次此工作流运行时，如果基础镜像有更新，Docker会拉取新版本。
FROM tinyserve/mihomo:latest

# 安装curl，用于下载配置文件
# 对于基于Alpine的镜像（如dreamacro/clash:latest可能基于Alpine），使用apk
# 如果是基于Debian/Ubuntu，则使用 apt-get update && apt-get install -y curl
RUN apk add --no-cache curl

# 将entrypoint.sh复制到镜像中
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# 赋予脚本执行权限
RUN chmod +x /usr/local/bin/entrypoint.sh

# 暴露Clash服务的端口（根据你的配置文件中的实际端口）
EXPOSE 7890 9090

# 设置容器启动时执行的命令为我们的启动脚本
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
