import QtQuick
import QtQuick.Controls

Window {
    width: 300
    height: 200
    visible: true
    title: "信号与槽 05 - 一个信号多个槽"

    Column {
        anchors.centerIn: parent
        spacing: 10

        Button {
            text: "点击我 (触发Python信号)"
            onClicked: backend.emitSignal()
        }
    }
}
