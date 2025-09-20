import QtQuick
import QtQuick.Controls

Window {
    width: 320
    height: 240
    visible: true
    title: "信号与槽 07 - 动态连接与断开"

    Column {
        anchors.centerIn: parent
        spacing: 10

        Button {
            text: "点击我 (触发Python信号)"
            onClicked: backend.emitSignal()
        }

        Button {
            text: "启用打印功能"
            onClicked: backend.enablePrintLog()
        }

        Button {
            text: "关闭打印功能"
            onClicked: backend.disablePrintLog()
        }
    }
}
