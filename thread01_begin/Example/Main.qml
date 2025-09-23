import QtQuick
import QtQuick.Controls

Window {
    width: 320
    height: 240
    visible: true
    title: "信号与槽 07 - 动态连接与断开"

    Column {
        anchors.centerIn: parent
        spacing: 20

        Button {
            text: "开始耗时任务"
            onClicked: {
                backend.startTask()
                resultText.text = "任务进行中..."
            }
        }

        Text {
            id: resultText
            text: "等待结果..."
            font.pointSize: 18
        }
    }

    Connections {
        target: backend
        function onResultReady(msg) {
            resultText.text = msg
        }
    }
}
