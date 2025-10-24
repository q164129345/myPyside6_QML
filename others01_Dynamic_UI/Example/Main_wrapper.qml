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
    
    // 重载提示
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
