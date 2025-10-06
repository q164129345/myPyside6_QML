# python3.10.11 - PySide6==6.9
import sys, time, threading
from PySide6.QtCore import QObject, Signal, Slot, QThread
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine


class Worker(QObject):
    # 输入任务信号（主线程发来）
    doWork = Signal(str)
    # 输出结果信号（发回主线程）
    finished = Signal(str)

    def __init__(self):
        super().__init__()
        self.doWork.connect(self.handleTask)

    @Slot(str)
    def handleTask(self, task_name: str):
        """在子线程中执行任务"""
        print(f"[Worker] 收到任务: {task_name}, 线程ID={threading.get_ident()}")
        time.sleep(2)  # 模拟耗时任务
        result = f"任务 {task_name} 完成"
        self.finished.emit(result)


class Backend(QObject):
    taskSignal = Signal(str)  # 从 QML 发来的任务名

    def __init__(self):
        super().__init__()
        self.thread = QThread()
        self.worker = Worker()

        # 将 worker 移动到子线程
        self.worker.moveToThread(self.thread)
        self.thread.started.connect(self.onThreadStarted)

        # 信号连接：任务派发与结果返回
        self.taskSignal.connect(self.worker.doWork)
        self.worker.finished.connect(self.onTaskFinished)

        # 启动线程并保持事件循环
        self.thread.start()

    def onThreadStarted(self):
        print(f"[Backend] 线程启动成功，线程ID={self.thread.currentThreadId()}")
        # 保持事件循环运行
        self.thread.exec()  # 🟢 关键点：让线程持续工作

    @Slot(str)
    def sendTask(self, task_name: str):
        """由QML调用，发送任务到worker"""
        print(f"[Backend] 派发任务: {task_name}")
        self.taskSignal.emit(task_name)

    @Slot(str)
    def onTaskFinished(self, result: str):
        """任务完成后，主线程打印结果"""
        print(f"[Backend] 收到结果：{result}")

    def __del__(self):
        """线程安全退出"""
        self.thread.quit()
        self.thread.wait()


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