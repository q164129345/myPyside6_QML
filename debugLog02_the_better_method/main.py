import sys
from pathlib import Path
from PySide6.QtGui import QGuiApplication
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
        QtMsgType.QtCriticalMsg: "[ERROR]",
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
    # Install the custom handler
    qInstallMessageHandler(qt_message_handler)

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
