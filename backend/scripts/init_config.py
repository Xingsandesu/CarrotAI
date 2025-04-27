#!/usr/bin/env python
"""
配置文件初始化脚本
用于创建和初始化配置文件
"""

import os
import json
import argparse
from pathlib import Path

# 获取项目根目录
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BASE_DIR = os.path.dirname(SCRIPT_DIR)
CONFIG_DIR = os.path.join(BASE_DIR, "config")
APP_CONFIG_DIR = os.path.join(CONFIG_DIR, "app")

# 确保配置目录存在
Path(CONFIG_DIR).mkdir(parents=True, exist_ok=True)
Path(APP_CONFIG_DIR).mkdir(parents=True, exist_ok=True)

# 默认MCP服务器配置
DEFAULT_MCP_SERVERS = {"service_name": {"url": "http://localhost:port/sse", "env": {}}}

# 默认模型配置
DEFAULT_MODEL_CONFIGS = [
    {
        "id": "model_id",
        "icon": "icon_name",
        "translations": {
            "zh": {
                "name": "模型名称",
                "description": "模型描述",
            },
            "en": {
                "name": "Model Name",
                "description": "Model Description",
            },
            "ja": {
                "name": "モデル名",
                "description": "モデルの説明",
            },
        },
        "exclusiveRules": {
            "rule_name": {
                "enabled": True,
                "excludes": ["other_rule"],
            }
        },
    },
]

# 默认应用配置 - DuckDuckGo搜索示例
DEFAULT_APP_CONFIG = {
    "id": "duckduckgo-search",
    "icon": "🔍",
    "mcpServer": {"url": "http://localhost:10000/duckduckgo-search", "env": {}},
    "translations": {
        "zh": {
            "name": "DuckDuckGo搜索",
            "type": "搜索工具",
            "description": "使用DuckDuckGo搜索引擎进行安全、私密的网络搜索",
        },
        "en": {
            "name": "DuckDuckGo Search",
            "type": "Search Tool",
            "description": "Use DuckDuckGo search engine for secure and private web searches",
        },
        "ja": {
            "name": "DuckDuckGo検索",
            "type": "検索ツール",
            "description": "DuckDuckGo検索エンジンを使用して安全でプライベートなウェブ検索を行います",
        },
    },
}


def init_mcp_servers():
    """初始化MCP服务器配置"""
    filepath = os.path.join(CONFIG_DIR, "mcp_servers.json")
    if os.path.exists(filepath):
        print(f"MCP服务器配置文件已存在: {filepath}")
        return

    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(DEFAULT_MCP_SERVERS, f, ensure_ascii=False, indent=2)
    print(f"已创建MCP服务器配置文件: {filepath}")


def init_model_configs():
    """初始化模型配置"""
    filepath = os.path.join(CONFIG_DIR, "model_configs.json")
    if os.path.exists(filepath):
        print(f"模型配置文件已存在: {filepath}")
        return

    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(DEFAULT_MODEL_CONFIGS, f, ensure_ascii=False, indent=2)
    print(f"已创建模型配置文件: {filepath}")


def init_app_configs():
    """初始化应用配置"""
    filepath = os.path.join(APP_CONFIG_DIR, "duckduckgo-search.json")
    if os.path.exists(filepath):
        print(f"应用配置文件已存在: {filepath}")
        return

    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(DEFAULT_APP_CONFIG, f, ensure_ascii=False, indent=2)
    print(f"已创建应用配置文件: {filepath}")


def init_all():
    """初始化所有配置文件"""
    init_mcp_servers()
    init_model_configs()
    init_app_configs()
    print("所有配置文件初始化完成")


def main():
    parser = argparse.ArgumentParser(description="初始化配置文件")
    parser.add_argument("--all", action="store_true", help="初始化所有配置文件")
    parser.add_argument("--mcp", action="store_true", help="初始化MCP服务器配置")
    parser.add_argument("--model", action="store_true", help="初始化模型配置")
    parser.add_argument("--app", action="store_true", help="初始化应用配置")

    args = parser.parse_args()

    # 如果没有提供任何参数，默认初始化所有配置
    if not any(vars(args).values()):
        print("未提供任何参数，默认初始化所有配置文件")
        init_all()
        return

    if args.all:
        init_all()
        return

    if args.mcp:
        init_mcp_servers()

    if args.model:
        init_model_configs()

    if args.app:
        init_app_configs()


if __name__ == "__main__":
    main()
