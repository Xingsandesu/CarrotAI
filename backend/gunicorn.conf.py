# 绑定地址和端口
bind = "0.0.0.0:8000"

# 工作进程数
workers = 6

# 工作模式
worker_class = "uvicorn.workers.UvicornWorker"

# 日志配置
accesslog = "logs/gunicorn_access.log"
errorlog = "logs/gunicorn_error.log"
loglevel = "info"

# 超时设置
timeout = 120
keepalive = 5

# 进程名称
proc_name = "carrot-backend"

# 最大请求数
max_requests = 1000
max_requests_jitter = 50
