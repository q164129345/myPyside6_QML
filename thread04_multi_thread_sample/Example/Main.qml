import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    width: 400
    height: 300
    visible: true
    title: "多线程计数演示"

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20

        Text {
            text: "Task A count: " + backend.aCount
            font.pixelSize: 20
        }

        Text {
            text: "Task B count: " + backend.bCount
            font.pixelSize: 20
        }

        Text {
            text: "Task C count: " + backend.cCount
            font.pixelSize: 20
        }
    }
}
