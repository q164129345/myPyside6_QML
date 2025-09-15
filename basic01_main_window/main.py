# python3.10.11 - PySide6==6.9
import sys
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

if __name__ == "__main__":
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    engine.addImportPath(sys.path[0])  # 当前项目路径
    engine.loadFromModule("Example", "Main")  # 模块(Example) + QML文件名(Main.qml)

    if not engine.rootObjects():
        sys.exit(-1)
    sys.exit(app.exec())
    del engine
    sys.exit(exit_code)










