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
            text: "Check your terminal for output!"
            font.pixelSize: 16
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Button {
            text: "Trigger Info (console.log)"
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: console.log("This is a standard log message (中文测试)")
        }

        Button {
            text: "Trigger Warning (console.warn)"
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: console.warn("This is a warning message! (警告)")
        }

        Button {
            text: "Trigger Error (console.error)"
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: console.error("This is an error message! (错误)")
        }
    }
}
