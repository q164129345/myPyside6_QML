# python3.10.11 - PySide6==6.9
"""
thread06 - 简化版线程池（QtConcurrent思想）
核心概念：
1. 使用 QRunnable + lambda 实现类似 QtConcurrent 的效果
2. 比 thread05 更简洁：不需要为每个任务创建类
3. 不需要 WorkerSignals 辅助类

说明：PySide6 的 QtConcurrent.run() 功能有限（不像C++版本）
所以我们用一个超简洁的方式模拟 QtConcurrent 的便利性

对比thread05的优势：
- 不需要为每个任务创建 QRunnable 类
- 不需要 WorkerSignals 类
- 使用 lambda 直接提交，代码极简
"""
import sys
import time
from PySide6.QtCore import QObject, Signal, Slot, QThreadPool, QRunnable
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine


# ===== 第1步：极简的Runnable包装器 =====
class SimpleRunnable(QRunnable):
    """
    极简包装器 - 让提交任务像 QtConcurrent 一样简单
    使用方式：SimpleRunnable(lambda: your_function(args))
    """
    def __init__(self, func):
        super().__init__()
        self.func = func
        self.setAutoDelete(True)
    
    def run(self):
        self.func()


# ===== 第2步：后端类 =====
class Backend(QObject):
    resultReady = Signal(str)  # 结果信号
    
    def __init__(self):
        super().__init__()
        
        # 获取全局线程池
        self.pool = QThreadPool.globalInstance()
        self.pool.setMaxThreadCount(2)  # 最多2个线程并发
        
        print(f"[Backend] 线程池就绪，最大线程数: {self.pool.maxThreadCount()}")
    
    @Slot()
    def startTasks(self):
        """启动5个任务 - 像 QtConcurrent 一样简洁"""
        print("[Backend] 开始提交5个任务...")
        
        # 🌟 关键：使用 lambda 直接提交，无需创建任务类
        for i in range(1, 6):
            self.pool.start(SimpleRunnable(
                lambda tid=i: self._do_work(tid)  # 注意：tid=i 捕获变量
            ))
            print(f"[Backend] 提交任务 {i}")
        
        self.resultReady.emit("已提交5个任务，观察控制台输出")
    
    def _do_work(self, task_id):
        """实际的工作函数（在工作线程中执行）"""
        print(f"[Task {task_id}] 开始工作...")
        
        # 模拟耗时操作（3秒）
        time.sleep(3)
        
        result = f"任务 {task_id} 完成！"
        print(f"[Task {task_id}] 完成")
        
        # 通过信号发送结果到主线程
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
