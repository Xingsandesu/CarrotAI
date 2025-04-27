from typing import Any
from sqlalchemy.ext.declarative import declared_attr
from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    """SQLAlchemy 基类"""

    id: Any
    __name__: str

    # 为所有表生成小写表名
    @declared_attr.directive
    def __tablename__(cls) -> str:
        return cls.__name__.lower()
