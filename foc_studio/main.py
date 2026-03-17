import sys
from pathlib import Path

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

from core.backend_facade import BackendFacade


def _application_base_dir() -> Path:
    if getattr(sys, "frozen", False) or "__compiled__" in globals():
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent


def _main_qml_path() -> Path:
    return _application_base_dir() / "ui" / "QMLFiles" / "Main.qml"


def _application_icon_path() -> Path:
    return _application_base_dir() / "ui" / "assets" / "app.ico"


def _report_qml_warnings(warnings: list) -> None:
    for warning in warnings:
        print(warning.toString(), file=sys.stderr)


if __name__ == "__main__":
    base_dir = _application_base_dir()
    qml_path = _main_qml_path()
    if not qml_path.is_file():
        print(f"Missing QML entry file: {qml_path}", file=sys.stderr)
        sys.exit(-1)

    app = QGuiApplication(sys.argv)
    icon_path = _application_icon_path()
    if icon_path.is_file():
        # 设置运行时窗口图标，避免标题栏和任务栏回退到默认 PySide 图标
        app.setWindowIcon(QIcon(str(icon_path)))
    engine = QQmlApplicationEngine()
    engine.warnings.connect(_report_qml_warnings)

    # 创建系统控制中心（内部完成对象创建与信号连接）
    backend = BackendFacade()

    # 暴露给QML
    engine.rootContext().setContextProperty("backend", backend)

    # Ensure bundled Qt QML modules and local components resolve in deployed builds.
    engine.addImportPath(str(qml_path.parent))
    bundled_qml_dir = base_dir / "PySide6" / "qml"
    if bundled_qml_dir.is_dir():
        engine.addImportPath(str(bundled_qml_dir))

    # 加载QML文件
    engine.load(QUrl.fromLocalFile(str(qml_path)))

    if not engine.rootObjects():
        print(f"Failed to load root QML object from: {qml_path}", file=sys.stderr)
        sys.exit(-1)

    sys.exit(app.exec())
