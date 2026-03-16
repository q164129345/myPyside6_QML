"""
Command 层：电机类型查询命令构造。
"""

from core.protocol.protocol_frame import pack_frame

CMD_QUERY_MOTOR_TYPE: int = 0x04  # PC -> MCU 查询电机类型，无 payload


def build_query_motor_type() -> bytes:
    """构建 CMD 0x04 电机类型查询帧。"""
    return pack_frame(CMD_QUERY_MOTOR_TYPE)
