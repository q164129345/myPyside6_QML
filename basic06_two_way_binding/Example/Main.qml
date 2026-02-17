// 导入QML基础模块，包含基本的QML元素
import QtQuick 2.15
// 导入Qt控件模块，包含Button等界面控件
import QtQuick.Controls 2.15

// qmllint disable unqualified

// 应用程序主窗口
ApplicationWindow {
    visible: true          // 窗口可见
    width: 400            // 窗口宽度为400像素
    height: 300           // 窗口高度为300像素
    title: qsTr("双向绑定实验")  // 窗口标题，qsTr用于国际化

    Column {
        anchors.centerIn: parent
        spacing: 10

        // 显示 Python 属性 count
        Text {
            id: countText
            text: "当前计数: " + backend.count
            font.pointSize: 16
        }

        Button {
            text: "QML -> Python: 增加"
            onClicked: backend.count = backend.count + 1
        }

        Button {
            text: "Python -> QML: 重置为0"
            onClicked: backend.count = 0
        }
    }
}
