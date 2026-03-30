"""
Command 层：TUNE 参数命令构造。
职责：
    - 定义速度环 / 电流环及电机限幅参数的读写与保存命令字
    - 将 QML / Backend 的工程量参数编码成协议帧

约束（Layer Contracts）：
    - 纯函数、无状态、无副作用
    - 不访问 Transport / UI
    - 不依赖 QObject / Qt 信号
"""

import struct

from core.protocol.protocol_frame import pack_frame

# 参数查询 / 设置 / 保存命令字
CMD_QUERY_SPEED_LOOP_PARAMS: int = 0x05
CMD_QUERY_CURRENT_LOOP_PARAMS: int = 0x06
CMD_SET_SPEED_LOOP_PARAMS: int = 0x07
CMD_SET_CURRENT_LOOP_PARAMS: int = 0x08
CMD_SAVE_CURRENT_TUNE_PARAMS_TO_FLASH: int = 0x09
CMD_QUERY_MOTOR_LIMITS: int = 0x0B
CMD_SET_MOTOR_LIMITS: int = 0x0C

_PARAM_SCALE: int = 1000000
_PARAM_RAW_MIN: int = -2147483648
_PARAM_RAW_MAX: int = 2147483647


def _encode_scaled_int32(value: float, field_name: str, scale: int) -> int:
    """将工程量参数按指定倍率编码为 int32。"""
    raw_value = int(round(float(value) * scale))
    if not (_PARAM_RAW_MIN <= raw_value <= _PARAM_RAW_MAX):
        raise ValueError(
            f"{field_name} 超出 int32 x{scale} 可表示范围: {value}"
        )
    return raw_value


def _build_set_loop_params(
    cmd: int,
    kp: float,
    ki: float,
    kd: float,
    ramp: float,
    tf: float,
) -> bytes:
    """按固定顺序 kp/ki/kd/ramp/tf 构造 PID 参数设置帧。"""
    payload = struct.pack(
        ">iiiii",
        _encode_scaled_int32(kp, "kp", _PARAM_SCALE),
        _encode_scaled_int32(ki, "ki", _PARAM_SCALE),
        _encode_scaled_int32(kd, "kd", _PARAM_SCALE),
        _encode_scaled_int32(ramp, "ramp", _PARAM_SCALE),
        _encode_scaled_int32(tf, "tf", _PARAM_SCALE),
    )
    return pack_frame(cmd, payload)


def build_query_speed_loop_params() -> bytes:
    """构造速度环参数查询帧。"""
    return pack_frame(CMD_QUERY_SPEED_LOOP_PARAMS)


def build_query_current_loop_params() -> bytes:
    """构造电流环参数查询帧。"""
    return pack_frame(CMD_QUERY_CURRENT_LOOP_PARAMS)


def build_set_speed_loop_params(
    kp: float,
    ki: float,
    kd: float,
    ramp: float,
    tf: float,
) -> bytes:
    """构造速度环 PID 参数设置帧。"""
    return _build_set_loop_params(CMD_SET_SPEED_LOOP_PARAMS, kp, ki, kd, ramp, tf)


def build_set_current_loop_params(
    kp: float,
    ki: float,
    kd: float,
    ramp: float,
    tf: float,
) -> bytes:
    """构造电流环 PID 参数设置帧。"""
    return _build_set_loop_params(CMD_SET_CURRENT_LOOP_PARAMS, kp, ki, kd, ramp, tf)


def build_query_motor_limits() -> bytes:
    """构造电机限幅参数查询帧。"""
    return pack_frame(CMD_QUERY_MOTOR_LIMITS)


def build_set_motor_limits(voltage_limit: float, current_limit: float) -> bytes:
    """构造电机限幅参数设置帧。"""
    payload = struct.pack(
        ">ii",
        _encode_scaled_int32(voltage_limit, "voltage_limit", _PARAM_SCALE),
        _encode_scaled_int32(current_limit, "current_limit", _PARAM_SCALE),
    )
    return pack_frame(CMD_SET_MOTOR_LIMITS, payload)


def build_save_current_tune_params_to_flash() -> bytes:
    """构造将当前已生效 TUNE 参数写入 FLASH 的命令帧。"""
    return pack_frame(CMD_SAVE_CURRENT_TUNE_PARAMS_TO_FLASH)

