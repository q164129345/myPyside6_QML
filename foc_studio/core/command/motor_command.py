"""
Command 层：电机控制命令构造

职责：
    - 定义命令字常量
    - 将语义参数编码为完整协议帧字节

约束（layer-contracts）：
    - 纯函数，无状态，无副作用
    - 不持有任何运行时状态
    - 不访问 Transport / UI
    - 不使用 QObject / Qt 信号
"""

import struct

from core.protocol.protocol_frame import pack_frame

# ── 命令字常量 ─────────────────────────────────────────────────────────────────
CMD_MOTOR_CONTROL: int = 0x01   # PC → MCU：电机控制（使能 + 目标转速）


def build_motor_control(enable: int, speed_rpm: int) -> bytes:
    """
    构造 CMD 0x01 Motor Control 完整帧。

    Payload 格式（DATA_LEN = 3）：
        Offset 0  1 byte  uint8  使能位（0 = 松轴，1 = 使能）
        Offset 1  2 bytes int16  目标转速 (rpm)，Big-Endian

    Args:
        enable:    使能位，0 = 松轴 / 停止，1 = 使能
        speed_rpm: 目标转速（rpm，有符号，-32768 ~ 32767）

    Returns:
        完整协议帧字节串（含帧头、CRC）
    """
    payload = struct.pack('>Bh', enable, speed_rpm)
    return pack_frame(CMD_MOTOR_CONTROL, payload)
