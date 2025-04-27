FROM ghcr.io/astral-sh/uv:alpine

# 设置工作目录
WORKDIR /app

# 复制后端项目文件
COPY . .

# 安装依赖（创建并激活虚拟环境）
RUN uv sync

# 暴露后端服务端口
EXPOSE 8000

# 以生产模式启动服务
CMD ["uv", "run", "main.py", "prod"] 