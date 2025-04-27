import sys
import logging
from typing import Optional
from pathlib import Path

from loguru import logger

from app.core.config import settings


class InterceptHandler(logging.Handler):
    """
    拦截标准库logging的处理器，将日志重定向到loguru
    """

    def emit(self, record):
        # 获取对应的loguru级别
        try:
            level = logger.level(record.levelname).name
        except ValueError:
            level = record.levelno

        # 找到调用者以获取正确的堆栈深度
        frame, depth = logging.currentframe(), 2
        while frame.f_back and frame.f_code.co_filename == logging.__file__:
            frame = frame.f_back
            depth += 1

        logger.opt(depth=depth, exception=record.exc_info).log(
            level, record.getMessage()
        )


def setup_logger():
    """
    配置并初始化Loguru日志系统。
    设置日志级别、格式、输出位置等。
    """
    # 确保日志目录存在
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)

    # 从设置中获取日志格式
    log_format = settings.LOG_FORMAT

    # 移除默认处理器
    logger.remove()

    # 添加控制台输出处理器
    logger.add(
        sys.stdout,
        format=log_format,
        level=settings.LOG_LEVEL,
        colorize=True,
    )

    # 添加主应用日志文件处理器
    logger.add(
        "logs/app.log",
        format=log_format,
        level=settings.LOG_LEVEL,
        rotation=settings.LOG_ROTATION_SIZE,
        compression=settings.LOG_COMPRESSION,
        retention=settings.LOG_RETENTION,
        encoding="utf-8",
        backtrace=True,
        diagnose=True,
        enqueue=True,  # 异步写入
    )

    # 添加API日志文件处理器
    logger.add(
        "logs/api.log",
        format=log_format,
        level=settings.LOG_LEVEL,
        filter=lambda record: record["name"].startswith("app.services"),
        rotation=settings.LOG_ROTATION_SIZE,
        compression=settings.LOG_COMPRESSION,
        retention=settings.LOG_RETENTION,
        encoding="utf-8",
        enqueue=True,  # 异步写入
    )

    # 添加错误日志文件处理器
    logger.add(
        "logs/error.log",
        format=log_format,
        level="ERROR",
        rotation=settings.LOG_ROTATION_SIZE,
        compression=settings.LOG_COMPRESSION,
        retention=settings.LOG_RETENTION,
        encoding="utf-8",
        backtrace=True,
        diagnose=True,
        enqueue=True,  # 异步写入
    )

    # 设置第三方模块的日志级别
    for module in ["httpx", "httpcore", "sqlalchemy", "alembic"]:
        logging.getLogger(module).setLevel(logging.WARNING)

    # 拦截标准库logging日志并重定向到loguru
    # 移除现有的处理器
    logging.basicConfig(handlers=[InterceptHandler()], level=logging.INFO)

    # 确保uvicorn和fastapi的日志被正确拦截
    for logger_name in [
        "uvicorn",
        "uvicorn.access",
        "uvicorn.error",
        "fastapi",
        "asyncio",
        "starlette",
    ]:
        logging_logger = logging.getLogger(logger_name)
        logging_logger.handlers = []  # 移除默认处理器
        logging_logger.propagate = True  # 允许日志传播到根记录器

    # 记录初始化消息
    logger.info(f"日志系统初始化完成，级别: {settings.LOG_LEVEL}")
    logger.info(
        f"API日志记录: 请求={settings.LOG_API_REQUESTS}, 响应={settings.LOG_API_RESPONSES}"
    )

    # 测试直接写入日志文件
    with open("logs/app.log", "a", encoding="utf-8") as f:
        f.write(f"测试日志消息：日志系统初始化完成 - {settings.LOG_LEVEL}\n")

    return logger


def get_logger(name: Optional[str] = None):
    """
    获取具有给定名称的日志记录器

    Args:
        name: 日志记录器名称，通常使用模块名，例如 'app.services.openai_service'

    Returns:
        配置好的loguru.logger实例
    """
    if name:
        return logger.bind(name=name)
    else:
        return logger


# 初始化日志系统
setup_logger()
