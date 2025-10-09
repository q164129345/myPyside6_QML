# python3.10.11 - PySide6==6.9
import sys, time
from PySide6.QtCore import QObject, Signal, Slot, QThread, QTimer
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

class Worker(QObject):
    finished = Signal(str)   # 完成信号
    progress = Signal(int)   # 进度信号

    def __init__(self):
        super().__init__()
        self._is_running = True

    def run(self):
        self._is_running = True
        for i in range(1, 11):  # 模拟10步任务
            if not self._is_running:
                print("[Worker] 收到停止信号，安全退出")
                self.finished.emit("任务已被取消")
                return
            print(f"[Worker] 工作中 {i}/10 ...")
            self.progress.emit(i * 10)  # 每次发进度
            time.sleep(1)
        self.finished.emit("任务完成！")

    def stop(self):
        self._is_running = False


class Backend(QObject):
    resultReady = Signal(str)
    progressChanged = Signal(int)

    def __init__(self):
        super().__init__()
        self.thread = None
        self.worker = None
        self.is_task_running = False  # 添加任务运行状态标志

    def cleanup(self):
        # 1. 先停止线程的事件循环
        self.thread.quit()
        # 2. 等待线程完全退出
        self.thread.wait()
        # 3. 使用deleteLater()延迟删除对象(更安全)
        self.worker.deleteLater()
        self.thread.deleteLater()
        print("[Backend] 已安排延迟清理 worker 和 thread")

        self.thread = None
        self.worker = None

    @Slot()
    def startTask(self):
        # 检查是否已有任务在运行
        if self.is_task_running:
            print("[Backend] 任务已在运行中")
            return

        print("[Backend] 准备启动新任务")
        
        # 创建新的线程和工作对象
        self.thread = QThread()
        self.worker = Worker()
        self.worker.moveToThread(self.thread)

        # 设置任务运行状态
        self.is_task_running = True

        # 线程启动
        self.thread.started.connect(self.worker.run)
        # worker 信号 → UI
        self.worker.finished.connect(self.resultReady.emit)
        self.worker.progress.connect(self.progressChanged.emit)

        # 生命周期管理
        self.worker.finished.connect(self._on_task_finished)

        self.thread.start()
        print("[Backend] 子线程已启动")

    @Slot()
    def stopTask(self):
        if self.worker and self.is_task_running:
            self.worker.stop()
            print("[Backend] 停止任务请求已发出")
        else:
            print("[Backend] 没有运行中的任务可停止")
    @Slot()
    def _on_task_finished(self, message):
        """任务完成后的清理工作"""
        print(f"[Backend] 任务完成: {message}")
        self.is_task_running = False
        self.cleanup() # 清理线程和worker

if __name__ == "__main__":
    # 创建应用程序和引擎
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    # qml与python交互
    backend = Backend() # 实例化python后端对象
    engine.rootContext().setContextProperty("backend", backend) # 注册到QML环境（名叫 “backend”）

    # 加载QML文件
    engine.addImportPath(sys.path[0])  # 当前项目路径
    engine.loadFromModule("Example", "Main")  # 模块(Example) + QML文件名(Main.qml)

    if not engine.rootObjects():
        sys.exit(-1)
    sys.exit(app.exec())

