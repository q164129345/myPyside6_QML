import sys
from pathlib import Path
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import qInstallMessageHandler

def main():

    # 解决 Windows 下中文乱码
    qInstallMessageHandler(lambda mode, context, message: print(message))
    
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    
    # Load QML
    qml_file = Path(__file__).parent / "Example" / "Main.qml"
    engine.load(qml_file)
    
    if not engine.rootObjects():
        sys.exit(-1)
        
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
