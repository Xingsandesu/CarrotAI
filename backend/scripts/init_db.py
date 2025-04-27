import logging
import subprocess
import sys
from pathlib import Path

# 将项目根目录添加到路径
BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.append(str(BASE_DIR))

# 导入数据库会话
from app.db.session import engine  # noqa: E402
from app.db.base import Base  # noqa: E402

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def init_db() -> None:
    """初始化数据库，创建表"""
    try:
        # 创建表
        logger.info("创建数据库表...")
        Base.metadata.create_all(bind=engine)
        logger.info("数据库表创建成功")

        # 运行Alembic迁移
        logger.info("运行Alembic迁移...")
        subprocess.run(["alembic", "upgrade", "head"], check=True)
        logger.info("Alembic迁移完成")

    except Exception as e:
        logger.error(f"数据库初始化失败: {str(e)}")
        raise


if __name__ == "__main__":
    logger.info("开始初始化数据库")
    init_db()
    logger.info("数据库初始化完成")
