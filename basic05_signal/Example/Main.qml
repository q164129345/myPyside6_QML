// 导入QML基础模块，包含基本的QML元素
import QtQuick 2.15
// 导入Qt控件模块，包含Button等界面控件
import QtQuick.Controls 2.15

// 应用程序主窗口
ApplicationWindow {
    visible: true          // 窗口可见
    width: 400            // 窗口宽度为400像素
    height: 300           // 窗口高度为300像素
    title: qsTr("Python主动更新 -> QML显示")  // 窗口标题，qsTr用于国际化

    Label {
        id: label
        anchors.centerIn: parent  // 标签居中显示
        text: "等待Python消息..."    // 标签初始文本内容
    }

    // 绑定Python信号
    Connections {
        target: backend  // 连接到名为backend的Python对象
        function onMessageChanged(msg) {
            label.text = msg  // 更新标签文本为传递的新文本
        }
    }




}
