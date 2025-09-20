# python3.10.11 - PySide6==6.9
import sys
from PySide6.QtCore import QObject, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

class Backend(QObject):
    # 定义两个信号
    signalA = Signal()
    signalB = Signal()

    def __init__(self):
        super().__init__()
        # 两个信号都连接到同一个槽函数
        self.signalA.connect(self.slot_handle_event)
        self.signalB.connect(self.slot_handle_event)

    @Slot()
    def emitSignalA(self):
        print("[Python] emitSignalA() called")
        self.signalA.emit()

    @Slot()
    def emitSignalB(self):
        print("[Python] emitSignalB() called")
        self.signalB.emit()

    # 统一的槽函数
    def slot_handle_event(self):
        print("[Python] 槽函数：收到一个信号事件")

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

