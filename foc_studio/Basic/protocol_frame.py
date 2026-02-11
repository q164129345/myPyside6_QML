"""
上下位机通讯协议帧处理模块（纯函数式设计）

协议格式：
    head1   head2   cmd     datalen data[]  crc16_h crc16_l
    0xAA    0xBB    1byte   1byte   N bytes 1byte   1byte
    
CRC16 校验范围：cmd + datalen + data
CRC16 标准：CRC16-MODBUS（多项式0x8005，初值0xFFFF，大端序）
"""

from typing import Optional, Tuple

# 协议常量
FRAME_HEAD1 = 0xAA
FRAME_HEAD2 = 0xBB
MIN_FRAME_SIZE = 6  # head1 + head2 + cmd + datalen + crc16(2 bytes)


def calculate_crc16(data: bytes) -> int:
    """
    计算 CRC16 校验值 (CRC16-MODBUS)
    
    多项式: 0x8005 (x^16 + x^15 + x^2 + 1)
    初始值: 0xFFFF
    
    Args:
        data: 待校验的字节数据
    
    Returns:
        CRC16 校验值 (0-65535)
    """
    crc = 0xFFFF
    polynomial = 0x8005
    
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 0x0001:
                crc = (crc >> 1) ^ polynomial
            else:
                crc = crc >> 1
    
    return crc & 0xFFFF  # 保持在 16 位范围内


def pack_frame(cmd: int, data: bytes = b'') -> bytes:
    """
    将命令和数据打包成协议帧
    
    Args:
        cmd: 命令字 (0-255)
        data: 数据段，默认为空 (最大255字节)
    
    Returns:
        打包后的完整帧字节序列
        
    Raises:
        ValueError: 如果 cmd 或 data 参数超出范围
        
    Example:
        >>> frame = pack_frame(0x10, b'Hello')
        >>> frame.hex(' ').upper()
        'AA BB 10 05 48 65 6C 6C 6F 16 99'
    """
    if not (0 <= cmd <= 255):
        raise ValueError(f"cmd must be 0-255, got {cmd}")
    
    if len(data) > 255:
        raise ValueError(f"data length must be 0-255, got {len(data)}")
    
    datalen = len(data)
    
    # 计算 CRC16
    crc_data = bytes([cmd, datalen]) + data
    crc16 = calculate_crc16(crc_data)
    
    # CRC16 大端序：高字节在前，低字节在后
    crc_high = (crc16 >> 8) & 0xFF
    crc_low = crc16 & 0xFF
    
    # 组装完整帧
    frame = bytes([
        FRAME_HEAD1,
        FRAME_HEAD2,
        cmd,
        datalen
    ]) + data + bytes([crc_high, crc_low])
    
    return frame


def unpack_frame(buffer: bytes) -> Optional[Tuple[int, bytes]]:
    """
    从字节序列解包协议帧
    
    Args:
        buffer: 包含完整帧的字节数据
    
    Returns:
        成功: (cmd, data) 元组
        失败: None (帧格式错误或 CRC16 校验失败)
        
    Example:
        >>> frame = pack_frame(0x10, b'Hello')
        >>> cmd, data = unpack_frame(frame)
        >>> f"cmd=0x{cmd:02X}, data={data.decode('ascii')}"
        'cmd=0x10, data=Hello'
    """
    if len(buffer) < MIN_FRAME_SIZE:
        return None
    
    # 检查帧头
    if buffer[0] != FRAME_HEAD1 or buffer[1] != FRAME_HEAD2:
        return None
    
    cmd = buffer[2]
    datalen = buffer[3]
    
    # 检查数据长度是否足够
    expected_frame_size = 6 + datalen  # head1 + head2 + cmd + datalen + data + crc16(2 bytes)
    if len(buffer) < expected_frame_size:
        return None
    
    # 提取数据段和 CRC16（大端序）
    data = buffer[4:4+datalen]
    crc_high = buffer[4+datalen]
    crc_low = buffer[5+datalen]
    received_crc = (crc_high << 8) | crc_low
    
    # 验证 CRC16
    crc_data = bytes([cmd, datalen]) + data
    calculated_crc = calculate_crc16(crc_data)
    
    if calculated_crc != received_crc:
        return None  # CRC16 校验失败
    
    return (cmd, data)


def parse_frame_from_buffer(buffer: bytearray) -> Optional[Tuple[Optional[Tuple[int, bytes]], int]]:
    """
    从缓冲区中解析一个完整的协议帧
    
    该函数会在缓冲区中搜索帧头，尝试解析完整帧。
    支持处理粘包和无效数据。
    
    Args:
        buffer: 接收缓冲区（bytearray）
    
    Returns:
        成功解析: ((cmd, data), consumed_bytes) - 解析出的命令和数据，以及消耗的字节数
        未找到有效帧: (None, bytes_to_discard) - 可丢弃的无效字节数
        数据不足: None - 等待更多数据
        
    Example:
        >>> frame = pack_frame(0x10, b'Hello')
        >>> buffer = bytearray(b'\\x00\\x11' + frame + b'\\x22')
        >>> result = parse_frame_from_buffer(buffer)
        >>> if result:
        ...     frame_data, consumed = result
        ...     if frame_data:
        ...         cmd, data = frame_data
        ...         print(f"cmd=0x{cmd:02X}, consumed={consumed}")
        cmd=0x10, consumed=13
    """
    if len(buffer) < MIN_FRAME_SIZE:
        return None
    
    # 查找帧头
    for i in range(len(buffer) - 1):
        if buffer[i] == FRAME_HEAD1 and buffer[i+1] == FRAME_HEAD2:
            # 找到帧头，尝试解析
            if i + MIN_FRAME_SIZE > len(buffer):
                # 数据不足，等待更多数据
                return None
            
            cmd = buffer[i+2]
            datalen = buffer[i+3]
            expected_frame_size = 6 + datalen  # 包含2字节CRC16
            
            if i + expected_frame_size > len(buffer):
                # 数据段不完整，等待更多数据
                return None
            
            # 提取完整帧数据
            frame_data = bytes(buffer[i:i+expected_frame_size])
            
            # 尝试解析
            result = unpack_frame(frame_data)
            
            if result is not None:
                # 解析成功，返回(cmd, data)和已消耗字节数
                consumed = i + expected_frame_size
                return (result, consumed)
            else:
                # CRC 校验失败或格式错误，跳过这个帧头，继续搜索
                continue
    
    # 没有找到有效帧
    # 如果缓冲区中有单个 0xAA 但后面不是 0xBB，保留它等待更多数据
    if buffer[-1] == FRAME_HEAD1:
        return None
    
    # 清除无效数据（保留最后可能的帧头）
    for i in range(len(buffer) - 1, -1, -1):
        if buffer[i] == FRAME_HEAD1:
            # 保留从这里开始的数据
            return (None, i) if i > 0 else None
    
    # 没有任何可能的帧头，可以清空缓冲区
    return (None, len(buffer)) if len(buffer) > 0 else None


if __name__ == "__main__":
    # 测试代码
    print("=== 纯函数式协议测试 ===\n")
    
    print("=== CRC16-MODBUS 测试 ===")
    test_data = b'\x01\x05Hello'
    crc = calculate_crc16(test_data)
    print(f"数据: {test_data.hex()}, CRC16: 0x{crc:04X}\n")
    
    print("=== 协议帧打包测试 ===")
    packed = pack_frame(cmd=0x10, data=b'Hello')
    print(f"打包数据: {packed.hex(' ').upper()}")
    print(f"帧长度: {len(packed)} 字节（应为 {4 + 5 + 2}）\n")
    
    print("=== 协议帧解包测试 ===")
    result = unpack_frame(packed)
    if result:
        cmd, data = result
        print(f"解包成功!")
        print(f"  cmd: 0x{cmd:02X}")
        print(f"  data: {data.decode('ascii')}")
        print(f"  datalen: {len(data)}\n")
    else:
        print("解包失败\n")
    
    print("=== CRC16校验失败测试 ===")
    # 故意修改CRC制造校验失败
    bad_packed = packed[:-2] + b'\xFF\xFF'
    bad_result = unpack_frame(bad_packed)
    if bad_result:
        print("错误：应该校验失败但成功了\n")
    else:
        print("CRC16校验失败处理正确（预期行为）\n")
    
    print("=== 缓冲区解析测试（粘包） ===")
    buffer = bytearray(b'\x00\x11\x22' + packed + b'\x33\x44')
    print(f"缓冲区: {buffer.hex(' ').upper()}")
    result = parse_frame_from_buffer(buffer)
    if result:
        parsed_data, consumed = result
        if parsed_data:
            cmd, data = parsed_data
            print(f"解析成功!")
            print(f"  cmd: 0x{cmd:02X}")
            print(f"  data: {data.decode('ascii')}")
            print(f"  消耗字节: {consumed}\n")
        else:
            print(f"未找到有效帧，可丢弃字节: {consumed}\n")
    else:
        print("缓冲区数据不足\n")
    
    print("=== 使用示例 ===")
    print("# 发送数据")
    print("frame_bytes = pack_frame(0x01, b'Test')")
    print("serial.write(frame_bytes)")
    print()
    print("# 接收数据")
    print("result = parse_frame_from_buffer(recv_buffer)")
    print("if result:")
    print("    frame_data, consumed = result")
    print("    if frame_data:")
    print("        cmd, data = frame_data")
    print("        print(f'收到命令: 0x{cmd:02X}, 数据: {data}')")
    print("        del recv_buffer[:consumed]  # 清理已处理数据")
