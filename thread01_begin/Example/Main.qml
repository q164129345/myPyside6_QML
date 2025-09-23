// 导入QtQuick模块，提供基本的QML元素
import QtQuick
// 导入QtQuick.Controls模块，提供UI控件如Button
import QtQuick.Controls

// 定义一个窗口组件，作为应用程序的主窗口
Window {
    // 设置窗口宽度
    width: 320
    // 设置窗口高度
    height: 240
    // 设置窗口可见
    visible: true
    // 设置窗口标题
    title: "多线程01 - 基础示例"

    // 使用Column布局，垂直排列子元素
    Column {
        // 将Column居中对齐到父元素（窗口）
        anchors.centerIn: parent
        // 设置子元素之间的间距
        spacing: 20

        // 定义一个按钮
        Button {
            // 设置按钮文本
            text: "开始耗时任务"
            // 定义按钮点击事件处理函数
            onClicked: {
                // 调用backend对象的startTask方法，开始任务
                backend.startTask()
                // 更新结果文本为“任务进行中...”
                resultText.text = "任务进行中..."
            }
        }

        // 定义一个文本元素，用于显示结果
        Text {
            // 设置文本元素的ID，用于在代码中引用
            id: resultText
            // 设置初始文本
            text: "等待结果..."
            // 设置字体大小
            font.pointSize: 18
        }
    }

    // 使用Connections对象来连接信号和槽
    Connections {
        // 设置目标对象为backend
        target: backend
        // 定义信号处理函数，当backend发出resultReady信号时调用
        function onResultReady(msg) {
            // 更新结果文本为信号传递的消息
            resultText.text = msg
        }
    }
}
