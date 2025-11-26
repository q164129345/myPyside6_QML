import sys
from PySide6.QtCore import QObject, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

# 导入串口类
from Basic.serial import mySerial


if __name__ == "__main__":
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    
    # 创建串口后端对象
    serialBackend = mySerial()
    
    # 暴露给QML
    engine.rootContext().setContextProperty("serialBackend", serialBackend)

    # 加载QML文件
    engine.load("QMLFiles/Main.qml")
    
    if not engine.rootObjects():
        sys.exit(-1)
    
    sys.exit(app.exec())




