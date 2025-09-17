// 导入QML基础模块，包含基本的QML元素
import QtQuick 2.15
// 导入Qt控件模块，包含Button等界面控件
import QtQuick.Controls 2.15

// 应用程序主窗口
ApplicationWindow {
    visible: true          // 窗口可见
    width: 400            // 窗口宽度为400像素
    height: 300           // 窗口高度为300像素
    title: qsTr("QML 调用 Python 返回值")  // 窗口标题，qsTr用于国际化

    // Column布局：垂直排列子元素
    Column {
        anchors.centerIn: parent  // 将Column布局锚定到父元素（窗口）的中心
        spacing: 20              // 子元素之间的垂直间距为20像素

        // 文本输入框：用于输入用户名字
        TextField {
            id: inputName                    // 给输入框设置唯一标识符，便于引用
            placeholderText: "输入名字"      // 当输入框为空时显示的提示文本
            width: 200                      // 输入框宽度为200像素
        }

        // 按钮：点击后调用Python函数并显示返回值
        Button {
            text: "点我问候"                 // 按钮显示的文本
            onClicked: {                    // 点击事件处理器
                // 调用 Python 后端的方法，传入输入框的文本作为参数
                // backend.greet() 返回一个字符串消息
                let msg = backend.greet(inputName.text)
                // 将返回的消息设置到输出标签的文本中
                outputLabel.text = msg
            }
        }

        // 标签：用于显示Python函数返回的结果
        Label {
            id: outputLabel                // 给标签设置唯一标识符，便于引用
            text: "等待点击按钮..."         // 初始显示的文本
        }
    }
}
