import sys
import os


def run_uvicorn():
    import uvicorn

    """
    主入口函数
    使用 uvicorn 运行 FastAPI 应用，
    并确保不覆盖我们的自定义日志配置
    """
    uvicorn.run(
        "app.app:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_config=None,  # 不使用uvicorn的日志配置
        log_level=None,  # 不设置日志级别，使用我们的配置
    )


def run_gunicorn():
    """
    主入口函数
    使用 gunicorn 运行 FastAPI 应用
    """
    # 获取当前文件所在目录
    current_dir = os.path.dirname(os.path.abspath(__file__))

    # 构建 gunicorn 命令
    gunicorn_cmd = [
        "gunicorn",
        "app.app:app",
        "-c",
        os.path.join(current_dir, "gunicorn.conf.py"),
    ]

    # 执行 gunicorn 命令
    os.execvp("gunicorn", gunicorn_cmd)


if __name__ == "__main__":
    # 检查是否有命令行参数且参数为 dev
    if len(sys.argv) > 1 and sys.argv[1] == "prod":
        # 如果是生产模式，使用 gunicorn
        run_gunicorn()
    else:
        # 默认使用 uvicorn 开发模式
        run_uvicorn()
