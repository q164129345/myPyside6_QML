import QtQuick
import QtQuick.Controls

Window {
    width: 400
    height: 300
    visible: true
    title: "Log Handler Example"

    Column {
        anchors.centerIn: parent
        spacing: 20

        Text {
            text: "测试中文日志输出"
            font.pixelSize: 16
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Button {
            text: "按钮"
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: console.log("a standard log message (中文测试)")
        }
    }
}
