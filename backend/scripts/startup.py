#!/usr/bin/env python
"""
启动项目脚本
自动初始化配置、数据库和管理员用户
"""

import os
import sys
import argparse
from pathlib import Path

# 将项目根目录加入路径
SCRIPT_DIR = Path(__file__).resolve().parent
BASE_DIR = SCRIPT_DIR.parent
sys.path.append(str(BASE_DIR))

# 导入初始化脚本
from scripts.init_config import init_all as init_configs  # noqa: E402
from scripts.init_db import init_db as init_database  # noqa: E402

# 导入数据库和模型
from app.db.session import get_db_context  # noqa: E402
from app.models.user import User  # noqa: E402
import bcrypt
from sqlalchemy.exc import IntegrityError


def init_user(email=None, username=None, password=None, token_limit=None):
    """
    创建管理员用户
    优先使用传入的参数，如果没有则尝试从环境变量获取
    """
    # 如果参数没有提供，尝试从环境变量获取
    email = email or os.getenv("ADMIN_EMAIL")
    username = username or os.getenv("ADMIN_USERNAME")
    password = password or os.getenv("ADMIN_PASSWORD")
    token_limit = token_limit or os.getenv("ADMIN_TOKEN_LIMIT", 999999999)

    if not email or not username or not password:
        print("用户信息不完整，必须提供邮箱、用户名和密码，否则跳过用户初始化")
        return

    if token_limit:
        try:
            token_limit = int(token_limit)
        except ValueError:
            print("令牌限制必须是整数，使用默认值")
            token_limit = None

    # 哈希密码
    hashed = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

    with get_db_context() as session:
        existing = session.query(User).filter_by(email=email).one_or_none()
        if existing:
            print(f"用户 {email} 已存在，跳过创建")
            return
        user = User(
            email=email,
            username=username,
            hashed_password=hashed,
        )
        if token_limit:
            user.token_limit = token_limit

        session.add(user)
        try:
            session.commit()
            print(f"管理员用户 {email} 创建成功")
        except IntegrityError as e:
            session.rollback()
            print(f"创建用户失败: {e}")


def main():
    parser = argparse.ArgumentParser(description="启动项目脚本")
    parser.add_argument("--config", action="store_true", help="初始化配置文件")
    parser.add_argument("--db", action="store_true", help="初始化数据库")
    parser.add_argument("--qs", action="store_true", help="快速开始")
    parser.add_argument("--email", help="管理员邮箱")
    parser.add_argument("--username", help="管理员用户名")
    parser.add_argument("--password", help="管理员密码")
    args = parser.parse_args()

    if not any(vars(args).values()):
        # 默认执行全部任务
        print("未指定参数，默认执行全部任务")
        init_configs()
        init_database()
        init_user()
        return

    if args.config:
        init_configs()
    if args.db:
        init_database()
    if args.qs:
        init_configs()
        init_database()
        init_user(email=args.email, username=args.username, password=args.password, token_limit=999999999)


if __name__ == "__main__":
    main() 