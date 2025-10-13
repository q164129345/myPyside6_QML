# python3.10.11 - PySide6==6.9
"""
thread06 - QtConcurrent 极简版
核心概念：
1. QtConcurrent.run() - 在线程池中异步执行函数
2. 使用回调函数接收结果（比thread05的WorkerSignals更简洁）
3. 无需手动创建QRunnable类，代码更优雅

对比thread05的优势：
- 不需要为每个任务创建QRunnable类
- 不需要WorkerSignals辅助类
- 使用回调函数，代码更直观
- 一个通用的Runnable包装器搞定一切
"""
import sys
import time
from PySide6.QtCore import QObject, Signal, Slot, QThreadPool, QRunnable
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine


# ===== 第1步：通用任务包装器（只需定义一次）=====
class TaskRunnable(QRunnable):
    """通用任务包装器 - QtConcurrent的核心优势"""
    def __init__(self, func, callback):
        super().__init__()
        self.func = func
        self.callback = callback
        self.setAutoDelete(True)
    
    def run(self):
        """执行任务并通过回调返回结果"""
        result = self.func()
        self.callback(result)


# ===== 第2步：后端类（使用QtConcurrent风格）=====
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
        """启动5个任务"""
        print("[Backend] 开始提交5个任务...")
        
        # 创建5个任务并提交到线程池
        for i in range(1, 6):
            # 定义任务函数（使用lambda捕获变量）
            task_func = lambda tid=i: self._do_work(tid)
            
            # 创建Runnable并提交
            runnable = TaskRunnable(task_func, self._on_finished)
            self.pool.start(runnable)
            
            print(f"[Backend] 提交任务 {i}")
        
        self.resultReady.emit("已提交5个任务，观察控制台输出")
    
    def _do_work(self, task_id):
        """实际的工作函数（在工作线程中执行）"""
        print(f"[Task {task_id}] 开始工作...")
        
        # 模拟耗时操作（3秒）
        time.sleep(3)
        
        print(f"[Task {task_id}] 完成")
        return f"任务 {task_id} 完成！"
    
    def _on_finished(self, result):
        """任务完成回调（在工作线程中执行，通过信号传递到主线程）"""
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
