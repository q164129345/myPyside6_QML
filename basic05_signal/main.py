# python3.10.11 - PySide6==6.9
import sys
from PySide6.QtCore import QObject, Slot, Signal, QTimer
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

class Backend(QObject):
    # 定义信号
    messageChanged = Signal(str)

    def __init__(self):
        super().__init__()
        # 使用定时器，每秒触发一次
        self.counter = 0
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.updateMessage)
        self.timer.start(1000)  # 1000毫秒

    def updateMessage(self):
        # 每1秒发送一次信号
        self.counter += 1
        self.messageChanged.emit(f"Hello from Python! {self.counter}") # 发送信号

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

