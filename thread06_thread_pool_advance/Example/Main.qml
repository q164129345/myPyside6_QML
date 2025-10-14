import QtQuick
import QtQuick.Controls

Window {
    width: 400
    height: 300
    visible: true
    title: "thread06 - QtRunnable优化版本"

    Column {
        anchors.centerIn: parent
        spacing: 20

        Text {
            text: "QtRunnable优化、实用的版本"
            font.pointSize: 16
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "使用通用Runnable包装器\n代码比thread05更简洁\n观察控制台输出"
            font.pointSize: 10
            color: "gray"
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Button {
            text: "启动5个任务（每个3秒）"
            font.pointSize: 12
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: {
                backend.startTasks()
                resultText.text = "任务运行中..."
            }
        }

        Rectangle {
            width: 350
            height: 80
            color: "#f0f0f0"
            radius: 8
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                id: resultText
                text: "等待启动..."
                anchors.centerIn: parent
                font.pointSize: 11
                wrapMode: Text.WordWrap
                width: parent.width - 20
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Connections {
        target: backend
        function onResultReady(msg) {
            resultText.text = msg
        }
    }
}
