// 导入QtQuick模块，提供基本的QML元素
import QtQuick
// 导入QtQuick.Controls模块，提供UI控件如Button
import QtQuick.Controls

// 定义一个窗口组件，作为应用程序的主窗口
Window {
    width: 350
    height: 280
    visible: true
    title: "QThread 生命周期与安全退出"

    // 使用Column布局垂直排列UI元素
    Column {
        anchors.centerIn: parent
        spacing: 20

        // 按钮行，包含开始和停止按钮
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 15
            
            // 开始任务按钮
            Button { 
                text: "开始任务"
                onClicked: {
                    backend.startTask()
                    // 重置进度条和状态文本
                    progressBar.value = 0
                    if (resultText.text === "等待任务..." || 
                        resultText.text === "任务完成！" || 
                        resultText.text === "任务已被取消") {
                        resultText.text = "任务启动中..."
                    }
                }
            }
            
            // 停止任务按钮
            Button { 
                text: "停止任务"
                onClicked: backend.stopTask()
            }
        }

        // 进度条显示任务进度
        ProgressBar {
            id: progressBar
            width: 250
            anchors.horizontalCenter: parent.horizontalCenter
            value: 0
            // 添加进度百分比文本
            Text {
                anchors.centerIn: parent
                text: Math.round(progressBar.value * 100) + "%"
                font.pointSize: 10
                color: "white"
            }
        }

        // 结果文本显示任务状态和结果
        Text {
            id: resultText
            text: "等待任务..."
            font.pointSize: 16
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // 说明文本
        Text {
            text: "点击'开始任务'可重复启动新任务"
            font.pointSize: 10
            color: "gray"
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // 信号连接，处理后端发来的信号
    Connections {
        target: backend
        // 处理进度更新信号
        function onProgressChanged(val) {
            progressBar.value = val / 100.0
        }
        // 处理任务结果信号
        function onResultReady(msg) {
            resultText.text = msg
        }
    }
}
