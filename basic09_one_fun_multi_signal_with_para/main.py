# python3.10.11 - PySide6==6.9
import sys
from PySide6.QtCore import QObject, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

class Backend(QObject):
    # 定义两个信号，带 (来源, 次数) 参数
    signalA = Signal(str, int)
    signalB = Signal(str, int)

    def __init__(self):
        super().__init__()
        self.signalA.connect(self.slot_handle_event)
        self.signalB.connect(self.slot_handle_event)

    # 统一的函数，接收 (来源, 次数) 参数
    def slot_handle_event(self, source: str, count: int):
        print(f"[Python] 槽函数：收到来自信号 {source} 的事件，第 {count} 次点击")

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

