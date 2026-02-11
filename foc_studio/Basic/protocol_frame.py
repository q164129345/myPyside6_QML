"""
上下位机通讯协议帧处理模块

协议格式：
    head1   head2   cmd     datalen data[]  crc16_h crc16_l
    0xAA    0xBB    1byte   1byte   N bytes 1byte   1byte
    
CRC16 校验范围：cmd + datalen + data
CRC16 标准：CRC16-MODBUS（多项式0x8005，初值0xFFFF，大端序）
"""

from typing import Optional, Tuple


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


class ProtocolFrame:
    """
    通讯协议帧
    
    Attributes:
        cmd: 命令字 (0-255)
        data: 数据段 (bytes)
    """
    
    HEAD1 = 0xAA
    HEAD2 = 0xBB
    MIN_FRAME_SIZE = 6  # head1 + head2 + cmd + datalen + crc16(2 bytes)
    
    def __init__(self, cmd: int, data: bytes = b''):
        """
        创建协议帧
        
        Args:
            cmd: 命令字 (0-255)
            data: 数据段，默认为空
        """
        if not (0 <= cmd <= 255):
            raise ValueError(f"cmd must be 0-255, got {cmd}")
        
        if len(data) > 255:
            raise ValueError(f"data length must be 0-255, got {len(data)}")
        
        self.cmd = cmd
        self.data = data
        self.datalen = len(data)
        self.crc16 = self._calculate_crc()
    
    def _calculate_crc(self) -> int:
        """计算当前帧的 CRC16 值"""
        # CRC 计算范围: cmd + datalen + data
        crc_data = bytes([self.cmd, self.datalen]) + self.data
        return calculate_crc16(crc_data)
    
    def to_bytes(self) -> bytes:
        """
        将协议帧打包为字节序列
        
        Returns:
            打包后的字节数据
        """
        # CRC16 大端序：高字节在前，低字节在后
        crc_high = (self.crc16 >> 8) & 0xFF
        crc_low = self.crc16 & 0xFF
        
        frame = bytes([
            self.HEAD1,
            self.HEAD2,
            self.cmd,
            self.datalen
        ]) + self.data + bytes([crc_high, crc_low])
        
        return frame
    
    @classmethod
    def from_bytes(cls, buffer: bytes) -> Optional['ProtocolFrame']:
        """
        从字节序列解包协议帧
        
        Args:
            buffer: 包含完整帧的字节数据
        
        Returns:
            解析成功返回 ProtocolFrame 对象，失败返回 None
        """
        if len(buffer) < cls.MIN_FRAME_SIZE:
            return None
        
        # 检查帧头
        if buffer[0] != cls.HEAD1 or buffer[1] != cls.HEAD2:
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
        
        # 创建帧对象
        frame = cls(cmd, data)
        return frame
    
    def __repr__(self) -> str:
        return f"ProtocolFrame(cmd=0x{self.cmd:02X}, datalen={self.datalen}, data={self.data.hex()})"


def parse_frame_from_buffer(buffer: bytearray) -> Optional[Tuple[Optional[ProtocolFrame], int]]:
    """
    从缓冲区中解析一个完整的协议帧（无状态函数）
    
    该函数会在缓冲区中搜索帧头，尝试解析完整帧。
    如果解析成功，返回帧对象和已消耗的字节数。
    
    Args:
        buffer: 接收缓冲区（bytearray）
    
    Returns:
        成功: (ProtocolFrame, consumed_bytes)
        失败: None（缓冲区中没有完整帧或格式错误）
    """
    if len(buffer) < ProtocolFrame.MIN_FRAME_SIZE:
        return None
    
    # 查找帧头
    for i in range(len(buffer) - 1):
        if buffer[i] == ProtocolFrame.HEAD1 and buffer[i+1] == ProtocolFrame.HEAD2:
            # 找到帧头，尝试解析
            if i + ProtocolFrame.MIN_FRAME_SIZE > len(buffer):
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
            frame = ProtocolFrame.from_bytes(frame_data)
            
            if frame is not None:
                # 解析成功，返回帧和已消耗字节数
                consumed = i + expected_frame_size
                return (frame, consumed)
            else:
                # CRC 校验失败或格式错误，跳过这个帧头，继续搜索
                continue
    
    # 没有找到有效帧
    # 如果缓冲区中有单个 0xAA 但后面不是 0xBB，保留它等待更多数据
    if buffer[-1] == ProtocolFrame.HEAD1:
        return None
    
    # 清除无效数据（保留最后可能的帧头）
    for i in range(len(buffer) - 1, -1, -1):
        if buffer[i] == ProtocolFrame.HEAD1:
            # 保留从这里开始的数据
            return (None, i) if i > 0 else None
    
    # 没有任何可能的帧头，可以清空缓冲区
    return (None, len(buffer)) if len(buffer) > 0 else None


if __name__ == "__main__":
    # 测试代码
    print("=== CRC16-MODBUS 测试 ===")
    test_data = b'\x01\x05Hello'
    crc = calculate_crc16(test_data)
    print(f"数据: {test_data.hex()}, CRC16: 0x{crc:04X}")
    
    print("\n=== 协议帧打包测试 ===")
    frame = ProtocolFrame(cmd=0x10, data=b'Hello')
    packed = frame.to_bytes()
    print(f"帧对象: {frame}")
    print(f"打包数据: {packed.hex(' ').upper()}")
    print(f"帧长度: {len(packed)} 字节（应为 {4 + len(frame.data) + 2}）")
    
    print("\n=== 协议帧解包测试 ===")
    unpacked_frame = ProtocolFrame.from_bytes(packed)
    if unpacked_frame:
        print(f"解包成功: {unpacked_frame}")
        print(f"数据内容: {unpacked_frame.data.decode('ascii')}")
        print(f"CRC16校验通过: 0x{unpacked_frame.crc16:04X}")
    else:
        print("解包失败")
    
    print("\n=== CRC16校验失败测试 ===")
    # 故意修改CRC制造校验失败
    bad_packed = packed[:-2] + b'\xFF\xFF'
    bad_frame = ProtocolFrame.from_bytes(bad_packed)
    if bad_frame:
        print("错误：应该校验失败但成功了")
    else:
        print("CRC16校验失败处理正确（预期行为）")
    
    print("\n=== 缓冲区解析测试 ===")
    buffer = bytearray(b'\x00\x11\x22' + packed + b'\x33\x44')
    print(f"缓冲区: {buffer.hex(' ').upper()}")
    result = parse_frame_from_buffer(buffer)
    if result:
        parsed_frame, consumed = result
        if parsed_frame:
            print(f"解析成功: {parsed_frame}")
            print(f"消耗字节: {consumed}")
        else:
            print(f"未找到有效帧，可丢弃字节: {consumed}")
    else:
        print("缓冲区数据不足")
