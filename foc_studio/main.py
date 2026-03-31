import os
import sys
from pathlib import Path


def _binary_dir() -> Path:
    """返回当前解释器或已编译程序所在目录。"""
    if getattr(sys, "frozen", False) or "__compiled__" in globals():
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent


def _application_base_dir() -> Path:
    """返回应用资源根目录，支持启动器通过环境变量覆盖。"""
    app_root = os.environ.get("FOC_STUDIO_APP_ROOT")
    if app_root:
        return Path(app_root).resolve()
    return _binary_dir()


def _runtime_dirs() -> list[Path]:
    """收集可能存放运行时依赖的目录，兼容根目录与回退启动器两种布局。"""
    runtime_dirs: list[Path] = []
    candidate_dirs = [
        _application_base_dir() / "runtime",
        _binary_dir() / "runtime",
        _binary_dir(),
    ]
    for candidate in candidate_dirs:
        resolved = candidate.resolve()
        if resolved.is_dir() and resolved not in runtime_dirs:
            runtime_dirs.append(resolved)
    return runtime_dirs


def _configure_runtime_environment() -> None:
    """在导入 PySide6 前配置运行时搜索路径。"""
    if os.name != "nt":
        return

    app_root = _application_base_dir()
    app_root_text = str(app_root)
    qt_plugin_dir = app_root / "PySide6" / "qt-plugins"
    qml_import_dir = app_root / "PySide6" / "qml"
    # 回退启动器方案下，PySide6/shiboken6 包目录仍位于应用根目录，需要优先加入模块搜索路径。
    if app_root_text not in sys.path:
        sys.path.insert(0, app_root_text)
    # 统一设置 Qt 插件与 QML 导入根目录，兼容根目录运行和 runtime 回退运行两种发布布局。
    if qt_plugin_dir.is_dir():
        os.environ["QT_PLUGIN_PATH"] = str(qt_plugin_dir)
    if qml_import_dir.is_dir():
        qml_import_dir_text = str(qml_import_dir)
        os.environ["QML2_IMPORT_PATH"] = qml_import_dir_text
        os.environ["QML_IMPORT_PATH"] = qml_import_dir_text

    for runtime_dir in _runtime_dirs():
        runtime_dir_text = str(runtime_dir)
        # 将运行时目录插入模块搜索路径，确保 .pyd 可被 Python 正常导入。
        if runtime_dir_text not in sys.path:
            sys.path.insert(0, runtime_dir_text)
        # 将运行时目录加入 Windows DLL 搜索路径，确保 Qt/Python 依赖可被加载。
        if hasattr(os, "add_dll_directory"):
            os.add_dll_directory(runtime_dir_text)


_configure_runtime_environment()

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

from core.backend_facade import BackendFacade


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
