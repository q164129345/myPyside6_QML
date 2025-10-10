# python3.10.11 - PySide6==6.9
import sys, time
from PySide6.QtCore import QObject, Signal, Slot, QThread
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

class Worker(QObject):
    finished = Signal(str) # 定义线程结束信号，传递字符串参数

    @Slot()
    def run(self):
        for i in range(5):
            print(f"[Python] 线程运行中... {i+1}/5")
            time.sleep(1)  # 模拟耗时操作
        self.finished.emit("任务完成!来自子线程")  # 任务完成，发射信号

class Backend(QObject):
    resultReady = Signal(str)  # 定义信号，传递字符串参数

    def __init__(self):
        super().__init__() # 初始化父类
        self.thread = None
        self.worker = None

    @Slot()
    def startTask(self):
        # 创建子线程和Worker对象
        self.thread = QThread()
        self.worker = Worker()
        self.worker.moveToThread(self.thread)  # 将Worker对象移到子线程

        # 线程启动->调用worker的run方法
        self.thread.started.connect(self.worker.run)  # 线程启动时调用Worker的run方法

        # worker完成-> 发信号给UI
        self.worker.finished.connect(self.resultReady.emit)  # 将结果通过信号传递

        # worker完成->退出线程
        self.worker.finished.connect(self.thread.quit)
        self.worker.finished.connect(self.worker.deleteLater)  # 任务完成后删除worker对象
        self.thread.finished.connect(self.thread.deleteLater)  # 线程结束后删除线程对象

        self.thread.start()  # 启动线程
        print("[Backend] 子线程已启动...")

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

