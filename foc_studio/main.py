import sys
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from core.backend_facade import BackendFacade

if __name__ == "__main__":
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    # 创建系统控制中心（内部完成对象创建与信号连接）
    backend = BackendFacade()

    # 暴露给QML
    engine.rootContext().setContextProperty("backend", backend)

    # 加载QML文件
    engine.load("ui/QMLFiles/Main.qml")

    if not engine.rootObjects():
        sys.exit(-1)

    sys.exit(app.exec())
