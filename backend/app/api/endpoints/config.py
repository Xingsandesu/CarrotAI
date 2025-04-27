from typing import List
from fastapi import APIRouter, Depends, status
import logging

from app.api.deps import get_current_active_user
from app.models.user import User
from app.utils.response_formatter import create_standard_response
from app.core.config import settings

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/models", response_model=List[dict])
async def get_model_configs(
    lang: str = "zh", current_user: User = Depends(get_current_active_user)
):
    """
    获取模型配置列表.

    - lang: 语言代码，默认为中文(zh)，支持英文(en)和日文(ja)

    此端点返回用于渲染前端模型选择器和处理功能互斥规则的配置数据.
    图标名称是字符串,需要在前端映射到实际的 Flutter IconData.
    需要有效的 JWT 才能访问.
    """
    try:
        logger.info(f"用户 {current_user.email} 获取模型配置请求，语言：{lang}")

        # 验证语言代码
        if lang not in ["zh", "en", "ja"]:
            lang = "zh"  # 默认使用中文

        # 处理多语言配置
        localized_configs = []
        for config in settings.MODEL_CONFIGS:
            # 复制基本配置，不包含翻译部分
            localized_config = {k: v for k, v in config.items() if k != "translations"}

            # 添加当前语言的翻译
            if "translations" in config and lang in config["translations"]:
                localized_config.update(config["translations"][lang])
            elif (
                "translations" in config and "zh" in config["translations"]
            ):  # 回退到中文
                localized_config.update(config["translations"]["zh"])

            localized_configs.append(localized_config)

        # 根据语言返回相应的成功消息
        success_message = {
            "zh": "获取模型配置成功",
            "en": "Successfully retrieved model configurations",
            "ja": "モデル設定の取得に成功しました",
        }.get(lang, "获取模型配置成功")

        return create_standard_response(
            result=localized_configs,
            message=success_message,
            actual_status_code=status.HTTP_200_OK,
        )
    except Exception as e:
        logger.error(f"获取模型配置失败: {e}")

        # 根据语言返回相应的错误消息
        error_message = {
            "zh": f"获取模型配置失败: {e}",
            "en": f"Failed to retrieve model configurations: {e}",
            "ja": f"モデル設定の取得に失敗しました: {e}",
        }.get(lang, f"获取模型配置失败: {e}")

        return create_standard_response(
            message=error_message,
            actual_status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )


@router.get("/apps", response_model=dict)
async def get_app_configs(
    lang: str = "zh", current_user: User = Depends(get_current_active_user)
):
    """
    获取应用市场配置列表.

    - lang: 语言代码，默认为中文(zh)，支持英文(en)和日文(ja)

    此端点返回用于渲染前端应用市场的应用列表数据.
    包含应用名称,图标,类型和MCP服务器配置信息.
    需要有效的 JWT 才能访问.
    """
    try:
        logger.info(f"用户 {current_user.email} 获取应用市场配置请求，语言：{lang}")

        # 验证语言代码
        if lang not in ["zh", "en", "ja"]:
            lang = "zh"  # 默认使用中文

        # 处理多语言配置
        localized_configs = []
        for config in settings.APP_CONFIGS:
            # 复制基本配置，不包含翻译部分
            localized_config = {k: v for k, v in config.items() if k != "translations"}

            # 添加当前语言的翻译
            if "translations" in config and lang in config["translations"]:
                localized_config.update(config["translations"][lang])
            elif (
                "translations" in config and "zh" in config["translations"]
            ):  # 回退到中文
                localized_config.update(config["translations"]["zh"])

            localized_configs.append(localized_config)

        # 根据语言返回相应的成功消息
        success_message = {
            "zh": "获取应用市场配置成功",
            "en": "Successfully retrieved app market configurations",
            "ja": "アプリマーケット設定の取得に成功しました",
        }.get(lang, "获取应用市场配置成功")

        return create_standard_response(
            result=localized_configs,
            message=success_message,
            actual_status_code=status.HTTP_200_OK,
        )
    except Exception as e:
        logger.error(f"获取应用市场配置失败: {e}")

        # 根据语言返回相应的错误消息
        error_message = {
            "zh": f"获取应用市场配置失败: {e}",
            "en": f"Failed to retrieve app market configurations: {e}",
            "ja": f"アプリマーケット設定の取得に失敗しました: {e}",
        }.get(lang, f"获取应用市场配置失败: {e}")

        return create_standard_response(
            message=error_message,
            actual_status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )
