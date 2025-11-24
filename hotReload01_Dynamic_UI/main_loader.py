"""
QML Loader 热重载 - 精简版
使用 Loader 组件动态加载 QML,实现可靠的热重载
"""
import sys
import time
from pathlib import Path
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QFileSystemWatcher, Slot, QUrl, QObject, Signal, Property, qInstallMessageHandler

class HotReloadController(QObject):
    """热重载控制器"""
    
    sourceChanged = Signal()
    
    def __init__(self, qml_file: Path):
        super().__init__()
        self.qml_file = qml_file
        self._source_url = ""
        print(f"初始化热重载控制器,监听文件: {qml_file}\n")
        
        # 文件监听
        self.watcher = QFileSystemWatcher([str(qml_file)])
        self.watcher.fileChanged.connect(self._load_new)
        print(f"QML热重载已启用,监听: {qml_file.name}\n")
    
    @Slot()
    def _load_new(self):
        """加载新源(添加时间戳防缓存)"""
        print(f"📝 检测到文件变化")
        base_url = QUrl.fromLocalFile(str(self.qml_file.resolve())).toString()
        self._source_url = f"{base_url}?t={int(time.time() * 1000)}"
        print(f"_source_url: {self._source_url}")
        self.sourceChanged.emit()
        print(f"已重载\n")
    
    # 暴露给QML的属性，getter方法
    # str：让QML侧知道函数返回值是字符串
    # notify=sourceChanged：当 sourceChanged 信号发出时，Qt会告诉QML侧该属性已更改，需要读取，更新 UI
    @Property(str, notify=sourceChanged)
    def sourceUrl(self):
        """QML 绑定的源 URL"""
        if not self._source_url:
            self._source_url = QUrl.fromLocalFile(str(self.qml_file.resolve())).toString()
        print(f"sourceUrl: {self._source_url}")
        return self._source_url


def main():
    # 解决 Windows 下中文乱码
    qInstallMessageHandler(lambda mode, context, message: print(message))

    app = QGuiApplication(sys.argv)
    
    # QML 文件路径
    example_dir = Path(__file__).parent / "Example" # Example 目录
    content_qml = example_dir / "Main_content.qml"  # Main_content.qml
    wrapper_qml = example_dir / "Main_wrapper.qml"  # Main_wrapper.qml
    
    # 创建热重载控制器
    controller = HotReloadController(content_qml)
    
    # 创建引擎并注册控制器
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("hotReloadController", controller)
    engine.load(QUrl.fromLocalFile(str(wrapper_qml.resolve())))
    
    if not engine.rootObjects():
        print("❌ 加载失败")
        sys.exit(-1)
    
    print("✅ 启动成功!")
    print("📝 编辑 Example/Main_content.qml 并保存即可看到 UI 更新\n")
    
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
