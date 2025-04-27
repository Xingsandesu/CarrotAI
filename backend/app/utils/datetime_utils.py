from datetime import datetime, timezone
import os
from zoneinfo import ZoneInfo

# 默认时区,如果环境变量未设置
DEFAULT_TIMEZONE = "Asia/Shanghai"


def get_timezone():
    """
    从环境变量获取时区,如果未设置则返回默认时区
    """
    tz_name = os.environ.get("TIMEZONE", DEFAULT_TIMEZONE)
    try:
        return ZoneInfo(tz_name)
    except KeyError:
        # 如果指定的时区无效,回退到默认时区
        return ZoneInfo(DEFAULT_TIMEZONE)


def get_now():
    """
    获取当前本地时间
    """
    return datetime.now(get_timezone())


def get_utc_now():
    """
    获取当前UTC时间(替代已废弃的datetime.utcnow())
    如果需要UTC时间,请使用此函数
    """
    return datetime.now(timezone.utc)


def timestamp_ms():
    """
    获取当前本地时间戳(毫秒)，返回整数类型
    """
    return int(get_now().timestamp() * 1000)


def from_timestamp(ts, use_local=True):
    """
    将时间戳转换为datetime对象

    Args:
        ts: 时间戳(秒)
        use_local: 是否转换为本地时间,默认为True
    """
    if use_local:
        dt = datetime.fromtimestamp(ts, get_timezone())
    else:
        dt = datetime.fromtimestamp(ts, timezone.utc)
    return dt


def get_now_naive():
    """
    获取不带时区信息的当前本地时间
    用于数据库存储，避免与PostgreSQL时区处理冲突
    """
    # 先获取带时区的时间，然后去除时区信息
    now = get_now()
    return now.replace(tzinfo=None)


def to_naive(dt):
    """
    将datetime对象转换为不带时区的datetime对象

    Args:
        dt: datetime对象，可以是带时区或不带时区

    Returns:
        不带时区的datetime对象
    """
    if dt is None:
        return None

    if dt.tzinfo is not None:
        # 如果有时区信息，先转换到本地时区，然后去除时区信息
        local_dt = dt.astimezone(get_timezone())
        return local_dt.replace(tzinfo=None)
    return dt  # 已经是不带时区的情况


def datetime_to_timestamp_ms(dt):
    """
    将datetime对象转换为毫秒时间戳

    Args:
        dt: datetime对象

    Returns:
        整数类型的毫秒时间戳
    """
    if dt is None:
        return None

    # 确保datetime对象有时区信息
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=get_timezone())

    # 转换为毫秒并确保是整数
    return int(dt.timestamp() * 1000)


def safe_get_now():
    """
    安全地获取当前时间，总是返回不带时区的时间
    用于数据库操作中，确保不会有时区相关错误
    """
    return get_now_naive()


def from_timestamp_ms(ts_ms, use_local=True, as_naive=False):
    """
    将毫秒时间戳转换为datetime对象

    Args:
        ts_ms: 时间戳(毫秒)
        use_local: 是否转换为本地时间，默认为True
        as_naive: 是否返回不带时区的对象，默认为False

    Returns:
        datetime对象
    """
    if ts_ms is None:
        return None

    # 转换为秒
    ts = ts_ms / 1000.0

    # 获取带时区的datetime
    if use_local:
        dt = datetime.fromtimestamp(ts, get_timezone())
    else:
        dt = datetime.fromtimestamp(ts, timezone.utc)

    # 是否需要转换为不带时区
    if as_naive:
        return dt.replace(tzinfo=None)

    return dt
