import sys
from PySide6.QtCore import QObject, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

# 导入串口类
from Basic.serial import mySerial
from Basic.data_processor import DataProcessor

if __name__ == "__main__":
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    
    # 创建串口后端对象
    serialBackend = mySerial()
    
    # 创建数据处理对象
    dataProcessor = DataProcessor()

    # 连接串口接收数据的信号到数据处理槽函数
    serialBackend.dataReceived.connect(dataProcessor.process_data)


    # 暴露给QML
    engine.rootContext().setContextProperty("serialBackend", serialBackend)

    # 加载QML文件
    engine.load("QMLFiles/Main.qml")
    
    if not engine.rootObjects():
        sys.exit(-1)
    
    sys.exit(app.exec())




