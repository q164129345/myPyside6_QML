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
        self.last_mtime = qml_file.stat().st_mtime if qml_file.exists() else 0
        
        # 文件监听 + 轮询双保险
        self.watcher = QFileSystemWatcher([str(qml_file), str(qml_file.parent)])
        self.watcher.fileChanged.connect(lambda: self._schedule_reload("监听"))
        self.watcher.directoryChanged.connect(self._on_dir_change)
        
        # 防抖定时器
        self.reload_timer = QTimer()
        self.reload_timer.setSingleShot(True)
        self.reload_timer.setInterval(300)
        self.reload_timer.timeout.connect(self._do_reload)
        
        # 轮询定时器(备用)
        self.poll_timer = QTimer()
        self.poll_timer.setInterval(500)
        self.poll_timer.timeout.connect(self._check_modified)
        self.poll_timer.start()
        
        print(f"🔥 QML 热重载已启用\n📁 监听: {qml_file.name}\n")
    
    @Slot()
    def _check_modified(self):
        """轮询检查文件修改(备用方案)"""
        if not self.qml_file.exists():
            return
        try:
            mtime = self.qml_file.stat().st_mtime
            if mtime > self.last_mtime:
                self.last_mtime = mtime
                self._schedule_reload("轮询")
                # 重新添加监听(如果丢失)
                if str(self.qml_file) not in self.watcher.files():
                    self.watcher.addPath(str(self.qml_file))
        except:
            pass
    
    @Slot(str)
    def _on_dir_change(self, path):
        """目录变化时重新添加监听"""
        if str(self.qml_file) not in self.watcher.files() and self.qml_file.exists():
            self.watcher.addPath(str(self.qml_file))
            self._schedule_reload("目录")
    
    def _schedule_reload(self, source):
        """延迟触发重载(防抖)"""
        print(f"📝 检测到文件变化 ({source})")
        if self.qml_file.exists():
            self.last_mtime = self.qml_file.stat().st_mtime
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


def create_wrapper_qml():
    """创建包装器 QML"""
    return '''import QtQuick
import QtQuick.Controls

ApplicationWindow {
    visible: true
    width: 600
    height: 400
    title: "QML 热重载"
    
    Loader {
        anchors.fill: parent
        source: hotReloadController.sourceUrl
        onStatusChanged: {
            if (status === Loader.Ready) console.log("✅ 加载成功")
            else if (status === Loader.Error) console.log("❌ 加载失败")
        }
    }
    
    Rectangle {
        width: 160; height: 40
        color: "#4CAF50"
        radius: 20
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 15 }
        opacity: 0
        
        Text {
            anchors.centerIn: parent
            text: "✅ 已重载"
            color: "white"
            font { pixelSize: 14; bold: true }
        }
        
        Connections {
            target: hotReloadController
            function onReloadSignal() {
                parent.opacity = 1
                hideTimer.restart()
            }
        }
        
        Timer {
            id: hideTimer
            interval: 1500
            onTriggered: parent.opacity = 0
        }
        
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }
}
'''


def create_content_qml():
    """创建示例内容 QML"""
    return '''import QtQuick
import QtQuick.Controls

Rectangle {
    width: 600
    height: 400
    
    gradient: Gradient {
        GradientStop { position: 0.0; color: "#667eea" }
        GradientStop { position: 1.0; color: "#764ba2" }
    }
    
    Column {
        anchors.centerIn: parent
        spacing: 20
        
        Text {
            text: "🔥 QML 热重载"
            font { pixelSize: 36; bold: true }
            color: "white"
            anchors.horizontalCenter: parent.horizontalCenter
        }
        
        Text {
            text: "修改这个文件并保存,UI 会立即更新!"
            font.pixelSize: 16
            color: "white"
            anchors.horizontalCenter: parent.horizontalCenter
        }
        
        Button {
            text: "点我测试"
            font.pixelSize: 18
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: console.log("按钮被点击!")
        }
    }
}
'''


def main():
    app = QGuiApplication(sys.argv)
    
    # QML 文件路径
    example_dir = Path(__file__).parent / "Example"
    content_qml = example_dir / "Main_content.qml"
    wrapper_qml = example_dir / "Main_wrapper.qml"
    
    # 创建示例文件(如果不存在)
    if not content_qml.exists():
        example_dir.mkdir(exist_ok=True)
        content_qml.write_text(create_content_qml(), encoding='utf-8')
        print(f"✅ 已创建: {content_qml}")
    
    wrapper_qml.write_text(create_wrapper_qml(), encoding='utf-8')
    
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
