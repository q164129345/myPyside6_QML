import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    width: 300
    height: 200
    visible: true
    title: "03 一个线程跑多个任务"

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 10

        Button {
            text: "任务 A"
            onClicked: backend.sendTask("A")
        }

        Button {
            text: "任务 B"
            onClicked: backend.sendTask("B")
        }

        Button {
            text: "任务 C"
            onClicked: backend.sendTask("C")
        }
    }
}