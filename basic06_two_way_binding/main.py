# python3.10.11 - PySide6==6.9
import sys
from PySide6.QtCore import QObject, Property, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

class Backend(QObject):

    countChanged = Signal(int)  # 信号，值改变时触发

    def __init__(self) -> None:
        super().__init__()
        self._count = 0 # 内部变量

    # Property属性，暴露给QML
    @Property(int, notify=countChanged)
    def count(self) -> int:
        return self._count

    @count.setter
    def count(self, value: int):
        # 只有值改变时才触发信号
        if self._count != value:
            self._count = value
            self.countChanged.emit(self._count)  # 触发信号

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

