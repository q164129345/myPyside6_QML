// 导入Qt Quick模块，提供基础的QML组件
import QtQuick
// 导入Qt Quick Controls模块，提供按钮等控件
import QtQuick.Controls
// 导入Qt Quick Layouts模块，提供布局管理
import QtQuick.Layouts

// 定义一个窗口组件
Window {
    width: 300      // 窗口宽度
    height: 200     // 窗口高度
    visible: true   // 窗口可见性
    title: "Hello World"  // 窗口标题

    // 定义一个只读属性，包含不同语言的问候语列表
    readonly property list<string> texts: ["Hallo Welt", "Hei maailma",
                                           "Hola Mundo", "Привет мир"]

    // 定义一个函数，用于随机设置文本
    function setText() {
        // 生成0-3之间的随机整数
        var i = Math.round(Math.random() * 3)
        // 将随机选择的文本赋值给text组件
        text.text = texts[i]
    }

    // 使用列布局管理器，垂直排列子组件
    ColumnLayout {
        anchors.fill:  parent  // 填充父组件的整个区域

        // 文本组件，显示问候语
        Text {
            id: text  // 组件ID，用于在其他地方引用
            text: "Hello World"  // 默认显示的文本
            Layout.alignment: Qt.AlignHCenter  // 在布局中水平居中对齐
        }
        
        // 按钮组件
        Button {
            text: "Click me"  // 按钮上显示的文字
            Layout.alignment: Qt.AlignHCenter  // 在布局中水平居中对齐
            onClicked:  setText()  // 点击事件处理：调用setText函数
        }
    }
}