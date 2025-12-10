import sys
import os
from pathlib import Path
from PySide6.QtWidgets import QApplication  # QtCharts 需要 QApplication 而非 QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import qInstallMessageHandler, QtMsgType

def qt_message_handler(mode, context, message):
    """
    Custom message handler to format Qt logs and fix encoding issues.
    """
    mode_str = {
        QtMsgType.QtDebugMsg: "[DEBUG]",
        QtMsgType.QtInfoMsg: "[INFO]",
        QtMsgType.QtWarningMsg: "[WARN]",
        QtMsgType.QtCriticalMsg: "[CRITICAL]",
        QtMsgType.QtFatalMsg: "[FATAL]"
    }.get(mode, "[LOG]")
    
    # Format the message with context if available (line number, file)
    if context.file:
        path_str = context.file.replace('file:///', '')
        p = Path(path_str)
        # Keep only parent folder and filename
        parts = p.parts
        short_path = f"{parts[-2]}/{parts[-1]}" if len(parts) >= 2 else p.name
        print(f"{mode_str} ...{short_path}:{context.line}: {message}")
    else:
        print(f"{mode_str}: {message}")

def main():
    # 设置 QML 样式为 Fusion,必须在创建 QApplication 之前设置
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Fusion"
    
    # Install the custom handler
    qInstallMessageHandler(qt_message_handler)

    app = QApplication(sys.argv)  # QtCharts 需要 QApplication
    engine = QQmlApplicationEngine()
    
    # Load QML
    qml_file = Path(__file__).parent / "Example" / "Main.qml"
    engine.load(qml_file)
    
    if not engine.rootObjects():
        sys.exit(-1)
        
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
