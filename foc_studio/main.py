import sys
from PySide6.QtCore import QObject, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine



if __name__ == "__main__":
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    
    # 创建后端对象
    #backend = Backend()
    
    # 暴露给QML
    #engine.rootContext().setContextProperty("backend", backend)
    
    # 加载QML文件
    engine.load("Example/Main.qml")
    
    if not engine.rootObjects():
        sys.exit(-1)
    
    sys.exit(app.exec())




