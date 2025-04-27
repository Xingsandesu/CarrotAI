from typing import List, Union, Dict, Any, ClassVar
import json
import os
import logging
from pathlib import Path
import glob

from pydantic import PostgresDsn, field_validator
from pydantic_settings import BaseSettings

logger = logging.getLogger(__name__)

# 配置文件根路径
CONFIG_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "config",
)
APP_CONFIG_DIR = os.path.join(CONFIG_DIR, "app")

# 确保配置目录存在
Path(CONFIG_DIR).mkdir(parents=True, exist_ok=True)
Path(APP_CONFIG_DIR).mkdir(parents=True, exist_ok=True)


def load_json_config(filename: str, default_value: Any = None) -> Any:
    """
    从JSON文件加载配置，如果文件不存在则返回默认值或None
    """
    filepath = os.path.join(CONFIG_DIR, filename)
    try:
        if os.path.exists(filepath):
            with open(filepath, "r", encoding="utf-8") as f:
                return json.load(f)
        else:
            logger.warning(f"配置文件不存在: {filepath}")
            return default_value
    except Exception as e:
        logger.error(f"加载配置文件失败 {filepath}: {e}")
        return default_value


def load_app_configs() -> List[Dict[str, Any]]:
    """
    从app目录自动加载所有app配置文件并合并
    如果没有找到配置文件，则返回空列表
    """
    app_configs = []
    app_json_files = glob.glob(os.path.join(APP_CONFIG_DIR, "*.json"))

    if not app_json_files:
        logger.warning(f"没有找到app配置文件, 目录: {APP_CONFIG_DIR}")
        return []

    for app_file in app_json_files:
        try:
            with open(app_file, "r", encoding="utf-8") as f:
                app_config = json.load(f)
                # 确保app_config是一个字典，因为每个app文件应该包含单个app的配置
                if isinstance(app_config, dict):
                    app_configs.append(app_config)
                else:
                    logger.warning(f"无效的app配置文件格式: {app_file}, 应该是一个字典")
        except Exception as e:
            logger.error(f"加载app配置文件失败 {app_file}: {e}")

    return app_configs


class Settings(BaseSettings):
    """
    应用配置类，从环境变量和.env文件加载配置
    """

    APP_NAME: str = "Carrot"  # 应用名称
    SECRET_KEY: str  # JWT密钥
    ALGORITHM: str = "HS256"  # JWT算法
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 43200

    # CORS设置
    BACKEND_CORS_ORIGINS: List[str] = []

    @field_validator("BACKEND_CORS_ORIGINS", mode="before")
    def assemble_cors_origins(cls, v: Union[str, List[str]]) -> Union[List[str], str]:
        """将CORS配置解析为列表"""
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",")]
        elif isinstance(v, (list, str)):
            return v
        raise ValueError(v)

    # 数据库设置
    DATABASE_URL: PostgresDsn


    # DeepSeek API设置
    DEEPSEEK_API_KEY: str
    DEEPSEEK_API_BASE: str
    DEEPSEEK_MODEL: str
    DEEPSEEK_DEFAULT_TEMPERATURE: float = 0.9  # DeepSeek模型默认温度
    DEFAULT_MODEL: str = "deepseek-chat"  # 默认模型
    DEEPSEEK_SYSTEM_PROMPT: str = ""
    DEFAULT_CONTEXT_LENGTH: int = 5  # 默认上下文长度

    # MCP服务器配置 - 从外部文件加载
    # 加载MCP服务器配置
    MCP_SERVERS: Dict[str, Dict[str, Any]] = {}

    # 日志设置
    LOG_LEVEL: str = "INFO"  # 日志级别: DEBUG, INFO, WARNING, ERROR, CRITICAL
    LOG_API_REQUESTS: bool = False  # 是否记录API请求
    LOG_API_RESPONSES: bool = False  # 是否记录API响应
    LOG_MAX_SIZE: int = 10000  # 单条日志最大长度

    # Loguru特有设置
    LOG_ROTATION_SIZE: str = "20 MB"  # 日志文件轮转大小
    LOG_RETENTION: str = "30 days"  # 日志保留时间
    LOG_COMPRESSION: str = "zip"  # 日志压缩格式
    LOG_FORMAT: str = "<green>{time:YYYY-MM-DD HH:mm:ss.SSS}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> - <level>{message}</level>"  # 日志格式

    # 令牌限制设置
    USER_TOKEN_LIMIT: int = 9999999999  # 普通用户默认限制

    # 模型配置 - 从外部文件加载
    MODEL_CONFIGS: ClassVar[List[Dict[str, Any]]] = []

    # 应用配置 - 从外部文件加载
    APP_CONFIGS: ClassVar[List[Dict[str, Any]]] = []


    # MCP服务调试设置
    DEBUG_MCP_SERVICE: bool = True  # 是否启用MCP服务的详细调试日志

    @field_validator("MCP_SERVERS", mode="before")
    def parse_mcp_servers(
        cls, v: Union[str, Dict[str, Dict[str, Any]]]
    ) -> Dict[str, Dict[str, Any]]:
        """将MCP服务器配置解析为字典"""
        # 优先使用环境变量配置
        if isinstance(v, str):
            try:
                # 尝试解析JSON字符串
                custom_servers = json.loads(v)
                if isinstance(custom_servers, dict):
                    return custom_servers
            except json.JSONDecodeError:
                pass

        if isinstance(v, dict) and v:
            return v

        # 从配置文件加载
        return load_json_config("mcp_servers.json", {})

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        # 加载配置文件
        self._load_config_files()

    def _load_config_files(self):
        """从配置文件加载各种配置"""
        # 加载模型配置
        Settings.MODEL_CONFIGS = load_json_config("model_configs.json", [])

        # 加载应用配置 - 修改为从app目录自动加载
        Settings.APP_CONFIGS = load_app_configs()

    class Config:
        """配置元数据"""

        case_sensitive = True
        env_file = ".env"
        extra = "ignore"  # 忽略额外的配置项


# 创建全局设置对象
try:
    settings = Settings()
except Exception as e:
    logger.error(f"配置加载失败: {e}")
    exit(1)
