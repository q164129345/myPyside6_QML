# python3.10.11 - PySide6==6.9
import sys
from PySide6.QtCore import QObject, Signal, Slot, QThread, Property
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

# ========== Worker 类（独立线程 + msleep 循环） ==========
class Worker(QThread):
    countChanged = Signal(str, int)  # 发射任务名和最新计数

    def __init__(self, name: str, interval_sec: float):
        super().__init__()
        self.name = name
        self.interval_sec = interval_sec
        self.count = 0
        self._running = True

    def run(self):
        """线程的主循环"""
        while self._running:
            self.count += 1
            self.countChanged.emit(self.name, self.count)
            self.msleep(self.interval_sec * 1000)  # 转换为毫秒

    def stop(self):
        """停止线程"""
        self._running = False


# ========== Backend 类（统一管理多个 Worker + 提供属性给 QML） ==========
class Backend(QObject):
    aCountChanged = Signal(int)
    bCountChanged = Signal(int)
    cCountChanged = Signal(int)

    def __init__(self):
        super().__init__()
        self._aCount = 0
        self._bCount = 0
        self._cCount = 0
        self.workers = []

    # --- QML 可绑定属性 ---
    def get_aCount(self): return self._aCount
    def get_bCount(self): return self._bCount
    def get_cCount(self): return self._cCount

    aCount = Property(int, get_aCount, notify=aCountChanged)
    bCount = Property(int, get_bCount, notify=bCountChanged)
    cCount = Property(int, get_cCount, notify=cCountChanged)

    # --- 启动所有任务 ---
    @Slot()
    def start_all(self):
        tasks = [
            ("A", 1.0),   # 1秒间隔
            ("B", 0.5),   # 0.5秒间隔
            ("C", 0.1),   # 0.1秒间隔
        ]
        for name, interval in tasks:
            worker = Worker(name, interval)
            worker.countChanged.connect(self.on_count_changed)
            
            self.workers.append(worker)
            worker.start()  # 直接启动线程

    # --- 接收 Worker 的信号 ---
    @Slot(str, int)
    def on_count_changed(self, name: str, value: int):
        if name == "A":
            self._aCount = value
            self.aCountChanged.emit(value)
        elif name == "B":
            self._bCount = value
            self.bCountChanged.emit(value)
        elif name == "C":
            self._cCount = value
            self.cCountChanged.emit(value)

    def clean_up(self):
        """清理所有线程(程序退出时调用)"""
        # 1. 停止所有 worker 线程
        for worker in self.workers:
            worker.stop()  # 设置标志位让 run() 循环退出
        
        # 2. 等待所有线程结束
        for worker in self.workers:
            # worker重写了run()，所以并没有调用exec()启动事件循环，所以不必调用quit()
            # worker.quit()  # 退出线程事件循环
            if not worker.wait(2000):  # 最多等待2秒
                print(f"警告: 线程 {worker.name} 未能在2秒内结束")
        
        # 3. 安全删除对象
        for worker in self.workers:
            worker.deleteLater()


# ========== 主程序入口 ==========
if __name__ == "__main__":
    # 创建QGuiApplication实例
    app = QGuiApplication(sys.argv)
    # 创建QQmlApplicationEngine实例，用于加载QML界面
    engine = QQmlApplicationEngine()

    # 创建Backend实例，后端逻辑管理器
    backend = Backend()
    # 将backend对象设置为QML上下文的属性，使QML可以访问
    engine.rootContext().setContextProperty("backend", backend)

    # 启动所有后台任务（多线程计数器）
    backend.start_all()

    # 连接应用程序退出信号到backend的clean_up方法，确保线程安全退出
    app.aboutToQuit.connect(backend.clean_up)

    # 添加当前目录到QML导入路径
    engine.addImportPath(sys.path[0])
    # 从模块加载QML文件（模块名"Example"，主文件"Main"）
    engine.loadFromModule("Example", "Main")

    # 检查是否成功加载了根对象，如果没有则退出程序
    if not engine.rootObjects():
        sys.exit(-1)
    # 启动应用程序事件循环
    sys.exit(app.exec())
