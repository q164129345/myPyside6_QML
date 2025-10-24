import QtQuick
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
}
