"""
FOC 上下位机通讯协议帧处理模块

协议格式：
    head1   head2   cmd     datalen data[]  crc16_h crc16_l
    0xAA    0xBB    1byte   1byte   N bytes 1byte   1byte

CRC16 校验范围：cmd + datalen + data[]
CRC16 规范：CRC16-MODBUS（多项式 0x8005，初值 0xFFFF，大端序输出）

设计约束：
    - 所有函数为纯函数（无状态、无副作用）
    - 不持有也不修改缓冲区
    - 格式非法或 CRC 校验失败时返回 None，不抛出运行时异常
    - 支持增量解析（粘包、半包场景）
"""

import struct
from typing import NamedTuple, Optional, Tuple

# ── 协议常量 ──────────────────────────────────────────────────────────────────

FRAME_HEAD1: int    = 0xAA
FRAME_HEAD2: int    = 0xBB
HEADER_SIZE: int    = 4     # head1 + head2 + cmd + datalen
CRC_SIZE: int       = 2     # crc16_h + crc16_l
MIN_FRAME_SIZE: int = HEADER_SIZE + CRC_SIZE   # 最小帧长（data 段为空时）
MAX_DATA_SIZE: int  = 255

# ── 数据结构 ──────────────────────────────────────────────────────────────────

class ParsedFrame(NamedTuple):
    """
    成功解析后的协议帧，只读；基于 tuple，属性访问无哈希开销。

    Attributes:
        cmd:     命令字（0x00 ~ 0xFF）
        datalen: 数据段长度（冗余字段，等于 len(data)，保留以便快速访问）
        data:    数据段字节串
        crc:     帧内 CRC16 值（16 位整数，大端序）
    """
    cmd:     int
    datalen: int
    data:    bytes
    crc:     int

# parse_frame_from_buffer 的返回语义：
#   (ParsedFrame, consumed)   ← 解析到一帧；consumed 为已消耗字节数
#   (None, discard_count)     ← 无有效帧头；discard_count 为可安全丢弃的字节数
#   None                      ← 数据不足；调用方保留缓冲区等待更多数据
ParseResult = Optional[Tuple[Optional[ParsedFrame], int]]

# ── CRC16-MODBUS 查表 ─────────────────────────────────────────────────────────

def _build_crc16_table() -> Tuple[int, ...]:
    """预生成 CRC16-MODBUS 查找表（256 项，LSB-first，反射多项式 0xA001）。

    CRC16-MODBUS 官方多项式为 0x8005，输入/输出均做位反转（reflected）。
    采用右移（LSB-first）查表实现时，必须使用反射多项式 0xA001 = reverse_bits(0x8005)。
    """
    poly = 0xA001  # reflected form of 0x8005，LSB-first 右移实现专用
    table: list[int] = []
    for i in range(256):
        crc = i
        for _ in range(8):
            crc = (crc >> 1) ^ poly if crc & 0x0001 else crc >> 1
        table.append(crc & 0xFFFF)
    return tuple(table)

_CRC16_TABLE: Tuple[int, ...] = _build_crc16_table()


def calculate_crc16(data: bytes) -> int:
    """
    计算 CRC16-MODBUS 校验值（查表法）。

    规范：多项式 0x8005（LSB-first 查表实现使用反射多项式 0xA001），初值 0xFFFF，大端序存储。

    Args:
        data: 待校验字节序列。

    Returns:
        16 位无符号整数校验值（范围 0x0000 ~ 0xFFFF）。
    """
    crc = 0xFFFF
    for byte in data:
        crc = (crc >> 8) ^ _CRC16_TABLE[(crc ^ byte) & 0xFF]
    return crc & 0xFFFF


# ── 帧构造 ────────────────────────────────────────────────────────────────────

def pack_frame(cmd: int, data: bytes = b'') -> bytes:
    """
    将命令字和数据段打包为完整协议帧。

    Args:
        cmd:  命令字，范围 [0, 255]。
        data: 数据段，最大 255 字节，默认为空。

    Returns:
        完整帧字节序列（head1 head2 cmd datalen data[] crc16_h crc16_l）。

    Raises:
        ValueError: cmd 或 data 超出允许范围。

    Example:
        >>> frame = pack_frame(0x10, bytes([0x10, 0x11, 0x12, 0x13, 0x14]))
        >>> frame.hex(' ').upper()
        'AA BB 10 05 10 11 12 13 14 B6 A4'
    """
    if not (0 <= cmd <= 255):
        raise ValueError(f"cmd 超出范围 [0, 255]，当前值: {cmd}")
    if len(data) > MAX_DATA_SIZE:
        raise ValueError(f"data 超出最大长度 {MAX_DATA_SIZE}，当前长度: {len(data)}")

    datalen = len(data)
    crc_payload = struct.pack('BB', cmd, datalen) + data
    crc16 = calculate_crc16(crc_payload)

    return (
        struct.pack('>BBBB', FRAME_HEAD1, FRAME_HEAD2, cmd, datalen)
        + data
        + struct.pack('>H', crc16)
    )


# ── 帧解析 ────────────────────────────────────────────────────────────────────

def unpack_frame(frame: bytes) -> Optional[ParsedFrame]:
    """
    解析一段完整协议帧字节序列。

    调用方负责传入完整帧（不含前缀垃圾数据）。
    CRC 验证失败或格式非法时返回 None，不抛出异常。

    Args:
        frame: 完整帧字节序列，至少 MIN_FRAME_SIZE 字节。

    Returns:
        成功: ParsedFrame(cmd, datalen, data, crc) 实例。
        失败: None。
    """
    if len(frame) < MIN_FRAME_SIZE:
        return None

    if frame[0] != FRAME_HEAD1 or frame[1] != FRAME_HEAD2:
        return None

    cmd: int     = frame[2]
    datalen: int = frame[3]
    frame_size   = HEADER_SIZE + datalen + CRC_SIZE

    if len(frame) < frame_size:
        return None

    data         = frame[4: 4 + datalen]
    (recv_crc,)  = struct.unpack_from('>H', frame, 4 + datalen)
    crc_payload  = struct.pack('BB', cmd, datalen) + data

    if calculate_crc16(crc_payload) != recv_crc:
        return None

    return ParsedFrame(cmd=cmd, datalen=datalen, data=data, crc=recv_crc)


def parse_frame_from_buffer(buffer: bytearray) -> ParseResult:
    """
    从接收缓冲区中尝试解析一个完整协议帧（增量解析）。

    调用方应在每次收到新字节后循环调用此函数，直到返回 None 为止。
    此函数不修改缓冲区，由调用方根据返回值决定如何清理。

    返回语义：
        (ParsedFrame, consumed)  → 解析到一帧，执行 del buffer[:consumed]
        (None, discard_count)    → 无有效帧头，执行 del buffer[:discard_count]
        None                     → 数据不足，保留缓冲区等待更多数据

    Args:
        buffer: 接收缓冲区（只读，本函数不会修改它）。

    Returns:
        ParseResult（见上方语义说明）。

    Service 层调用示范：
        while True:
            result = parse_frame_from_buffer(self._buffer)
            if result is None:
                break                           # 等待更多数据
            frame_data, consumed = result
            del self._buffer[:consumed]
            if frame_data:
                self._dispatch(frame_data.cmd, frame_data.data)  # 分发给业务逻辑
    """
    buf_len = len(buffer)
    if buf_len < MIN_FRAME_SIZE:
        return None

    i = 0
    while i < buf_len - 1:

        # ── 搜索帧头 ────────────────────────────────────────────────────────
        if buffer[i] != FRAME_HEAD1 or buffer[i + 1] != FRAME_HEAD2:
            i += 1
            continue

        # ── 帧头已找到（位于偏移 i） ─────────────────────────────────────────
        # header 字段不完整：等待更多数据；若 i>0 先通知丢弃前导垃圾字节
        if i + HEADER_SIZE > buf_len:
            return (None, i) if i > 0 else None

        datalen   = buffer[i + 3]
        frame_end = i + HEADER_SIZE + datalen + CRC_SIZE

        # 数据段或 CRC 不完整：等待更多数据
        if frame_end > buf_len:
            return (None, i) if i > 0 else None

        # ── 尝试解析完整帧 ───────────────────────────────────────────────────
        parsed = unpack_frame(bytes(buffer[i:frame_end]))
        if parsed is not None:
            return (parsed, frame_end)

        # CRC 校验失败：此 0xAA 不是有效帧头，向后移动一字节继续搜索
        i += 1

    # ── 全缓冲区搜索完毕，未找到可成功解码的帧 ──────────────────────────────
    # 保留最后一个 0xAA 及其之后的字节（可能是下一帧起始）
    for j in range(buf_len - 1, -1, -1):
        if buffer[j] == FRAME_HEAD1:
            return (None, j) if j > 0 else None

    # 缓冲区内没有任何 0xAA，全部可安全丢弃
    return (None, buf_len)


# ── 自测 ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("=== protocol_frame 自测 ===\n")

    # CRC16-MODBUS
    print("[1] CRC16-MODBUS")
    test_data = b'\x01\x02\x03\x04\x05'
    crc = calculate_crc16(test_data)
    print(f"    数据: {test_data.hex(' ').upper()}  CRC16: 0x{crc:04X}\n")

    # 打包
    print("[2] pack_frame")
    packed = pack_frame(cmd=0x10, data=b'\x10\x11\x12\x13\x14')
    print(f"    帧: {packed.hex(' ').upper()}  长度: {len(packed)} 字节\n")

    # 解包
    print("[3] unpack_frame")
    result = unpack_frame(packed)
    assert result is not None
    print(f"    cmd: 0x{result.cmd:02X}  datalen: {result.datalen}  data: {result.data.hex(' ').upper()}  crc: 0x{result.crc:04X}\n")

    # CRC 校验失败
    print("[4] CRC 校验失败检测")
    bad = packed[:-2] + b'\xFF\xFF'
    assert unpack_frame(bad) is None
    print("    正确拒绝（预期行为）\n")

    # 粘包解析
    print("[5] parse_frame_from_buffer（粘包）")
    buf = bytearray(b'\x00\x11\x22') + bytearray(packed) + bytearray(b'\x33\x44')
    print(f"    缓冲区: {buf.hex(' ').upper()}")
    res = parse_frame_from_buffer(buf)
    assert res is not None
    frame_data, consumed = res
    assert frame_data is not None
    print(f"    cmd: 0x{frame_data.cmd:02X}  datalen: {frame_data.datalen}  data: {frame_data.data.hex(' ').upper()}  crc: 0x{frame_data.crc:04X}  consumed: {consumed}\n")

    print("所有自测通过。")
