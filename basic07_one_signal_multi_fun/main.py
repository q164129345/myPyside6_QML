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
        # 将一个信号连接到多个槽函数
        self.buttonClicked.connect(self.slot_print_message)
        self.buttonClicked.connect(self.slot_update_counter)

        self._counter = 0

    @Slot()
    def emitSignal(self):
        """供 QML 调用，触发 buttonClicked 信号"""
        print("[Python] emitSignal() called")
        self.buttonClicked.emit()

    # 槽函数1：打印信息
    def slot_print_message(self):
        print("[Python] 槽函数1：按钮被点击")

    # 槽函数2：计数器更新
    def slot_update_counter(self):
        self._counter += 1
        print(f"[Python] 槽函数2：按钮点击次数 = {self._counter}")

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

