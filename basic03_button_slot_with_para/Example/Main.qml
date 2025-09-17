// 导入QML基础模块，包含基本的QML元素
import QtQuick 2.15
// 导入Qt控件模块，包含Button等界面控件
import QtQuick.Controls 2.15

// 应用程序主窗口
ApplicationWindow {
    visible: true          // 窗口可见
    width: 400            // 窗口宽度为400像素
    height: 300           // 窗口高度为300像素
    title: qsTr("Hello PySide6 + QML")  // 窗口标题，qsTr用于国际化

    // Row布局：水平排列子元素
    Row {
        anchors.centerIn: parent  // 将Row布局锚定到父元素（窗口）的中心
        spacing: 20              // 子元素之间的间距为20像素
        
        // 第一个按钮
        Button {
            id: btn1             // 给按钮设置唯一标识符，便于引用
            text: "button1"      // 按钮显示的文本
            onClicked: {         // 点击事件处理器
                // 调用Python后端的方法，传递参数
                backend.print_button1("button1 clicked")
                // 修改按钮文本为"clicked"
                btn1.text = "clicked"
            }
        }

        // 第二个按钮
        Button {
            id: btn2             // 给按钮设置唯一标识符
            text: "button2"      // 按钮显示的文本
            onClicked: {         // 点击事件处理器
                // 调用Python后端的方法，传递参数
                backend.print_button2("button2 clicked")
                // 修改按钮文本为"clicked"
                btn2.text = "clicked"
            }
        }
    }
}
