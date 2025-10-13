# python3.10.11 - PySide6==6.9
"""
thread05 - QThreadPool 极简版
核心概念：
1. QRunnable - 轻量级任务
2. QThreadPool - 自动管理线程
3. WorkerSignals - 信号辅助类（因为QRunnable不能直接发信号）
"""
import sys
import time
from PySide6.QtCore import QObject, Signal, Slot, QRunnable, QThreadPool
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine


# ===== 第1步：信号辅助类（因为QRunnable不能直接发信号）=====
class WorkerSignals(QObject):
    """帮助QRunnable发射信号"""
    finished = Signal(int, str)  # 参数：任务ID, 结果消息


# ===== 第2步：创建任务类（继承QRunnable）=====
class SimpleTask(QRunnable):
    """简单任务：模拟耗时操作"""
    
    def __init__(self, task_id, signals):
        super().__init__()
        self.task_id = task_id
        self.signals = signals
        self.setAutoDelete(True)  # 重要！任务完成后自动删除
    
    def run(self):
        """任务执行函数（在线程池的工作线程中运行）"""
        print(f"[Task {self.task_id}] 开始工作...")
        
        # 模拟耗时操作（3秒）
        time.sleep(3)
        
        # 发射完成信号
        result = f"任务 {self.task_id} 完成！"
        self.signals.finished.emit(self.task_id, result)
        print(f"[Task {self.task_id}] 完成")


# ===== 第3步：后端类（管理线程池）=====
class Backend(QObject):
    resultReady = Signal(str)  # 结果信号
    
    def __init__(self):
        super().__init__()
        
        # 获取全局线程池
        self.pool = QThreadPool.globalInstance()
        self.pool.setMaxThreadCount(2)  # 最多2个线程并发
        
        # 创建共享的信号对象
        self.signals = WorkerSignals()
        self.signals.finished.connect(self._on_finished)
        
        print(f"[Backend] 线程池就绪，最大线程数: {self.pool.maxThreadCount()}")
    
    @Slot()
    def startTasks(self):
        """启动5个任务"""
        print("[Backend] 开始提交5个任务...")
        
        # 创建5个任务并提交到线程池
        for i in range(1, 6):
            task = SimpleTask(i, self.signals)
            self.pool.start(task)  # 提交任务，自动调度
            print(f"[Backend] 提交任务 {i}")
        
        self.resultReady.emit("已提交5个任务，观察控制台输出")
    
    def _on_finished(self, task_id, result):
        """任务完成回调"""
        print(f"[Backend] 收到结果: {result}")
        self.resultReady.emit(result)


if __name__ == "__main__":
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    backend = Backend()
    engine.rootContext().setContextProperty("backend", backend)

    engine.addImportPath(sys.path[0])
    engine.loadFromModule("Example", "Main")

    if not engine.rootObjects():
        sys.exit(-1)

    sys.exit(app.exec())
