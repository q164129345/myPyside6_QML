# python3.10.11 - PySide6==6.9
import sys
from PySide6.QtCore import QObject, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

class Backend(QObject):
    # 定义信号
    buttonClicked = Signal()

    def __init__(self):
        super().__init__()
        self._counter = 0
        # 默认只连接计数功能
        self.buttonClicked.connect(self.update_counter)

    # 打印消息
    @Slot()
    def print_message(self):
        print("[Python] 槽函数：按钮被点击")

    # 计数器更新
    @Slot()
    def update_counter(self):
        self._counter += 1
        print(f"[Python] 槽函数：按钮点击次数 = {self._counter}")

    # 开启打印功能
    @Slot()
    def enablePrintLog(self):
        try:
            self.buttonClicked.connect(self.print_message)
            print("[Python] 已启用打印槽")
        except TypeError:
            # 如果重复连接，会抛 TypeError
            print("[Python] 打印槽已经启用")

    # 关闭打印功能
    @Slot()
    def disablePrintLog(self):
        try:
            self.buttonClicked.disconnect(self.print_message)
            print("[Python] 已关闭打印槽")
        except TypeError:
            # 如果槽没有连接，disconnect 会抛异常
            print("[Python] 打印槽未连接，无需关闭")

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

