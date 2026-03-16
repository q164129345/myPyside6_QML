from PySide6.QtCore import QObject, QTimer, Signal, Slot


class SerialStatisticsService(QObject):
    """串口统计服务，负责维护当前连接会话的收发与错误统计。"""

    txFrameCountTotalChanged = Signal()
    rxFrameCountTotalChanged = Signal()
    txBytesTotalChanged = Signal()
    rxBytesTotalChanged = Signal()
    txBytesPerSecChanged = Signal()
    rxBytesPerSecChanged = Signal()
    rxCrcErrorCountChanged = Signal()
    rxInvalidFrameCountChanged = Signal()

    def __init__(self, parent=None) -> None:
        """初始化统计状态，并启动 1 秒速率统计定时器。"""
        super().__init__(parent)

        self._tx_frame_count_total = 0
        self._rx_frame_count_total = 0
        self._tx_bytes_total = 0
        self._rx_bytes_total = 0
        self._tx_bytes_per_sec = 0
        self._rx_bytes_per_sec = 0
        self._rx_crc_error_count = 0
        self._rx_invalid_frame_count = 0

        self._tx_window_bytes = 0
        self._rx_window_bytes = 0

        self._rate_timer = QTimer(self)
        self._rate_timer.setInterval(1000)
        self._rate_timer.timeout.connect(self._on_rate_timer_timeout)
        self._rate_timer.start()

    @property
    def txFrameCountTotal(self) -> int:
        """返回当前会话累计发送完整帧数。"""
        return self._tx_frame_count_total

    @property
    def rxFrameCountTotal(self) -> int:
        """返回当前会话累计接收有效帧数。"""
        return self._rx_frame_count_total

    @property
    def txBytesTotal(self) -> int:
        """返回当前会话累计发送字节数。"""
        return self._tx_bytes_total

    @property
    def rxBytesTotal(self) -> int:
        """返回当前会话累计接收原始字节数。"""
        return self._rx_bytes_total

    @property
    def txBytesPerSec(self) -> int:
        """返回最近 1 秒发送字节速率。"""
        return self._tx_bytes_per_sec

    @property
    def rxBytesPerSec(self) -> int:
        """返回最近 1 秒接收字节速率。"""
        return self._rx_bytes_per_sec

    @property
    def rxCrcErrorCount(self) -> int:
        """返回当前会话累计 CRC 错误次数。"""
        return self._rx_crc_error_count

    @property
    def rxInvalidFrameCount(self) -> int:
        """返回当前会话累计无效帧恢复次数。"""
        return self._rx_invalid_frame_count

    @Slot()
    def reset(self) -> None:
        """在新连接建立时清零当前会话统计。"""
        self._tx_window_bytes = 0
        self._rx_window_bytes = 0

        self._set_tx_frame_count_total(0)
        self._set_rx_frame_count_total(0)
        self._set_tx_bytes_total(0)
        self._set_rx_bytes_total(0)
        self._set_tx_bytes_per_sec(0)
        self._set_rx_bytes_per_sec(0)
        self._set_rx_crc_error_count(0)
        self._set_rx_invalid_frame_count(0)

    @Slot(int, bool)
    def onDataWritten(self, bytes_written: int, frame_complete: bool) -> None:
        """统计串口层实际写入的字节数与完整帧数。"""
        if bytes_written <= 0:
            return

        self._tx_window_bytes += bytes_written
        self._set_tx_bytes_total(self._tx_bytes_total + bytes_written)

        if frame_complete:
            self._set_tx_frame_count_total(self._tx_frame_count_total + 1)

    @Slot(bytes)
    def onDataReceived(self, data: bytes) -> None:
        """统计串口层收到的原始字节数。"""
        if not data:
            return

        received_len = len(data)
        self._rx_window_bytes += received_len
        self._set_rx_bytes_total(self._rx_bytes_total + received_len)

    @Slot(object)
    def onFrameParsed(self, _frame) -> None:
        """统计协议层成功解析出的有效帧。"""
        self._set_rx_frame_count_total(self._rx_frame_count_total + 1)

    @Slot()
    def onCrcErrorDetected(self) -> None:
        """统计协议层识别出的 CRC 错误帧。"""
        self._set_rx_crc_error_count(self._rx_crc_error_count + 1)

    @Slot()
    def onInvalidFrameDetected(self) -> None:
        """统计协议层为恢复同步而丢弃无效数据的次数。"""
        self._set_rx_invalid_frame_count(self._rx_invalid_frame_count + 1)

    def _on_rate_timer_timeout(self) -> None:
        """每秒固化一次当前窗口吞吐，并清空窗口计数。"""
        self._set_tx_bytes_per_sec(self._tx_window_bytes)
        self._set_rx_bytes_per_sec(self._rx_window_bytes)
        self._tx_window_bytes = 0
        self._rx_window_bytes = 0

    def _set_tx_frame_count_total(self, value: int) -> None:
        """更新发送帧总数，并在变化时通知上层。"""
        if self._tx_frame_count_total == value:
            return
        self._tx_frame_count_total = value
        self.txFrameCountTotalChanged.emit()

    def _set_rx_frame_count_total(self, value: int) -> None:
        """更新接收有效帧总数，并在变化时通知上层。"""
        if self._rx_frame_count_total == value:
            return
        self._rx_frame_count_total = value
        self.rxFrameCountTotalChanged.emit()

    def _set_tx_bytes_total(self, value: int) -> None:
        """更新发送字节总数，并在变化时通知上层。"""
        if self._tx_bytes_total == value:
            return
        self._tx_bytes_total = value
        self.txBytesTotalChanged.emit()

    def _set_rx_bytes_total(self, value: int) -> None:
        """更新接收字节总数，并在变化时通知上层。"""
        if self._rx_bytes_total == value:
            return
        self._rx_bytes_total = value
        self.rxBytesTotalChanged.emit()

    def _set_tx_bytes_per_sec(self, value: int) -> None:
        """更新发送速率，并在变化时通知上层。"""
        if self._tx_bytes_per_sec == value:
            return
        self._tx_bytes_per_sec = value
        self.txBytesPerSecChanged.emit()

    def _set_rx_bytes_per_sec(self, value: int) -> None:
        """更新接收速率，并在变化时通知上层。"""
        if self._rx_bytes_per_sec == value:
            return
        self._rx_bytes_per_sec = value
        self.rxBytesPerSecChanged.emit()

    def _set_rx_crc_error_count(self, value: int) -> None:
        """更新 CRC 错误计数，并在变化时通知上层。"""
        if self._rx_crc_error_count == value:
            return
        self._rx_crc_error_count = value
        self.rxCrcErrorCountChanged.emit()

    def _set_rx_invalid_frame_count(self, value: int) -> None:
        """更新无效帧计数，并在变化时通知上层。"""
        if self._rx_invalid_frame_count == value:
            return
        self._rx_invalid_frame_count = value
        self.rxInvalidFrameCountChanged.emit()
