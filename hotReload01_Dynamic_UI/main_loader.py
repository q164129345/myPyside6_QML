"""
QML Loader 热重载 - 精简版
使用 Loader 组件动态加载 QML,实现可靠的热重载
"""
import sys
import time
from pathlib import Path
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QFileSystemWatcher, QTimer, Slot, QUrl, QObject, Signal, Property


class HotReloadController(QObject):
    """热重载控制器"""
    
    sourceChanged = Signal(str)
    reloadSignal = Signal()
    
    def __init__(self, qml_file: Path):
        super().__init__()
        self.qml_file = qml_file
        self._source_url = ""
        
        # 文件监听
        self.watcher = QFileSystemWatcher([str(qml_file), str(qml_file.parent)])
        self.watcher.fileChanged.connect(self._schedule_reload)
        self.watcher.directoryChanged.connect(self._on_dir_change)
        
        # 防抖定时器
        self.reload_timer = QTimer()
        self.reload_timer.setSingleShot(True)
        self.reload_timer.setInterval(300)
        self.reload_timer.timeout.connect(self._do_reload)
        
        print(f"🔥 QML 热重载已启用\n📁 监听: {qml_file.name}\n")
    
    @Slot(str)
    def _on_dir_change(self, path):
        """目录变化时重新添加监听"""
        if str(self.qml_file) not in self.watcher.files() and self.qml_file.exists():
            self.watcher.addPath(str(self.qml_file))
            self._schedule_reload()
    
    def _schedule_reload(self):
        """延迟触发重载(防抖)"""
        print(f"📝 检测到文件变化")
        self.reload_timer.start()
    
    @Slot()
    def _do_reload(self):
        """执行重载:先清空再加载"""
        self._source_url = ""
        self.sourceChanged.emit("")
        QTimer.singleShot(100, self._load_new)
    
    def _load_new(self):
        """加载新源(添加时间戳防缓存)"""
        base_url = QUrl.fromLocalFile(str(self.qml_file.resolve())).toString()
        self._source_url = f"{base_url}?t={int(time.time() * 1000)}"
        self.sourceChanged.emit(self._source_url)
        self.reloadSignal.emit()
        print(f"✅ 已重载\n")
    
    @Property(str, notify=sourceChanged)
    def sourceUrl(self):
        """QML 绑定的源 URL"""
        if not self._source_url:
            self._source_url = QUrl.fromLocalFile(str(self.qml_file.resolve())).toString()
        return self._source_url


def main():
    app = QGuiApplication(sys.argv)
    
    # QML 文件路径
    example_dir = Path(__file__).parent / "Example"
    content_qml = example_dir / "Main_content.qml"
    wrapper_qml = example_dir / "Main_wrapper.qml"
    
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
