# syntax=docker/dockerfile:1

# 1. 使用官方 Ubuntu 作为基础镜像
FROM ubuntu:20.04

# 2. 安装运行时依赖（如果你的 app 需要，比如证书、时区等）
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 3. 将当前目录下编译好的二进制文件复制到镜像中是的
WORKDIR /app
COPY app .

# 4. 声明容器启动时运行的命令
ENTRYPOINT ["./app"]