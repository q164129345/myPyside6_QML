from PySide6.QtCore import QObject, Signal, Slot, Property

class DataProcessor(QObject):
    """
    数据处理模块，负责处理接收到的原始数据
    """
    def __init__(self):
        super().__init__()
        self._processed_data = bytearray()

    @Slot(bytes)
    def process_data(self, data: bytes) -> None:
        print(f"[DataProcessor] Processing {len(data)} bytes {data}", flush=True)














