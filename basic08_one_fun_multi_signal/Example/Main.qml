import QtQuick
import QtQuick.Controls

Window {
    width: 320
    height: 240
    visible: true
    title: "信号与槽 06 - 一个槽响应多个信号"

    Column {
        anchors.centerIn: parent
        spacing: 10

        Button {
            text: "触发信号A"
            onClicked: backend.emitSignalA()
        }

        Button {
            text: "触发信号B"
            onClicked: backend.emitSignalB()
        }
    }
}
