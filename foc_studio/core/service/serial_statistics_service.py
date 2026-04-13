from PySide6.QtCore import QObject, QTimer, Signal, SignalInstance, Slot


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

        # 仅在发布给 UI 时保留一份快照，避免高频串口统计持续触发 QML 重绘。
        self._published_tx_frame_count_total = 0
        self._published_rx_frame_count_total = 0
        self._published_tx_bytes_total = 0
        self._published_rx_bytes_total = 0
        self._published_tx_bytes_per_sec = 0
        self._published_rx_bytes_per_sec = 0
        self._published_rx_crc_error_count = 0
        self._published_rx_invalid_frame_count = 0

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
        self._publish_snapshot()

    def _publish_if_changed(self, published_attr: str, value: int, signal: SignalInstance) -> None:
        """仅在对外快照变化时发出通知，保持属性值与 notify 语义一致。"""
        if getattr(self, published_attr) == value:
            return
        setattr(self, published_attr, value)
        signal.emit()

    @Slot(int, bool)
    def onDataWritten(self, bytes_written: int, frame_complete: bool) -> None:
        """统计串口层实际写入的字节数与完整帧数。"""
        if bytes_written <= 0:
            return

        self._tx_window_bytes += bytes_written
        self._tx_bytes_total += bytes_written
        self._publish_if_changed(
            "_published_tx_bytes_total",
            self._tx_bytes_total,
            self.txBytesTotalChanged,
        )

        if frame_complete:
            self._tx_frame_count_total += 1
            self._publish_if_changed(
                "_published_tx_frame_count_total",
                self._tx_frame_count_total,
                self.txFrameCountTotalChanged,
            )

    @Slot(bytes)
    def onDataReceived(self, data: bytes) -> None:
        """统计串口层收到的原始字节数。"""
        if not data:
            return

        received_len = len(data)
        self._rx_window_bytes += received_len
        self._rx_bytes_total += received_len
        self._publish_if_changed(
            "_published_rx_bytes_total",
            self._rx_bytes_total,
            self.rxBytesTotalChanged,
        )

    @Slot(object)
    def onFrameParsed(self, _frame) -> None:
        """统计协议层成功解析出的有效帧。"""
        self._rx_frame_count_total += 1
        self._publish_if_changed(
            "_published_rx_frame_count_total",
            self._rx_frame_count_total,
            self.rxFrameCountTotalChanged,
        )

    @Slot()
    def onCrcErrorDetected(self) -> None:
        """统计协议层识别出的 CRC 错误帧。"""
        self._rx_crc_error_count += 1
        self._publish_if_changed(
            "_published_rx_crc_error_count",
            self._rx_crc_error_count,
            self.rxCrcErrorCountChanged,
        )

    @Slot()
    def onInvalidFrameDetected(self) -> None:
        """统计协议层为恢复同步而丢弃无效数据的次数。"""
        self._rx_invalid_frame_count += 1
        self._publish_if_changed(
            "_published_rx_invalid_frame_count",
            self._rx_invalid_frame_count,
            self.rxInvalidFrameCountChanged,
        )

    def _on_rate_timer_timeout(self) -> None:
        """每秒固化一次当前窗口吞吐，并清空窗口计数。"""
        self._tx_bytes_per_sec = self._tx_window_bytes
        self._rx_bytes_per_sec = self._rx_window_bytes
        self._tx_window_bytes = 0
        self._rx_window_bytes = 0
        self._publish_snapshot()

    def _publish_snapshot(self) -> None:
        """将最近一段时间的统计变化合并发布给上层。"""
        self._publish_if_changed(
            "_published_tx_frame_count_total",
            self._tx_frame_count_total,
            self.txFrameCountTotalChanged,
        )
        self._publish_if_changed(
            "_published_rx_frame_count_total",
            self._rx_frame_count_total,
            self.rxFrameCountTotalChanged,
        )
        self._publish_if_changed(
            "_published_tx_bytes_total",
            self._tx_bytes_total,
            self.txBytesTotalChanged,
        )
        self._publish_if_changed(
            "_published_rx_bytes_total",
            self._rx_bytes_total,
            self.rxBytesTotalChanged,
        )
        self._publish_if_changed(
            "_published_tx_bytes_per_sec",
            self._tx_bytes_per_sec,
            self.txBytesPerSecChanged,
        )
        self._publish_if_changed(
            "_published_rx_bytes_per_sec",
            self._rx_bytes_per_sec,
            self.rxBytesPerSecChanged,
        )
        self._publish_if_changed(
            "_published_rx_crc_error_count",
            self._rx_crc_error_count,
            self.rxCrcErrorCountChanged,
        )
        self._publish_if_changed(
            "_published_rx_invalid_frame_count",
            self._rx_invalid_frame_count,
            self.rxInvalidFrameCountChanged,
        )
