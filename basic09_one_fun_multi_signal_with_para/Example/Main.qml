import QtQuick
import QtQuick.Controls

Window {
    width: 320
    height: 240
    visible: true
    title: "信号与槽 06 - 一个槽响应多个信号"

    // 定义 countA 和 countB 属性，进行累加操作
    property int countA: 0
    property int countB: 0

    Column {
        anchors.centerIn: parent
        spacing: 10

        Button {
            text: "触发信号A"
            onClicked: {
                countA += 1  // 在 QML 中进行累加
                backend.signalA("A", countA)  // 发射信号并传递参数
            }
        }

        Button {
            text: "触发信号B"
            onClicked: {
                countB += 1  // 在 QML 中进行累加
                backend.signalB("B", countB)  // 发射信号并传递参数
            }
        }
    }
}