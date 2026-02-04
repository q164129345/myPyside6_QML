// SYS 系统功能页面
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#ecf0f1"
    
    // 接收串口连接状态
    property bool isSerialConnected: false
    
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20

        Text {
            text: "SYS 系统功能页面"
            font.pixelSize: 24
            color: "#2c3e50"
            Layout.alignment: Qt.AlignHCenter
        }

        // 串口状态显示
        Text {
            text: root.isSerialConnected ? "串口状态: 已连接 ✓" : "串口状态: 未连接"
            font.pixelSize: 16
            color: root.isSerialConnected ? "#27ae60" : "#e74c3c"
            Layout.alignment: Qt.AlignHCenter
        }

        // 测试按钮
        RowLayout {
            spacing: 10
            Layout.alignment: Qt.AlignHCenter

            Button {
                text: "连接串口 (测试)"
                enabled: !root.isSerialConnected
                onClicked: {
                    // 这里使用一个测试端口,您需要根据实际情况修改
                    serialBackend.openPort("COM4", 115200)
                }
            }

            Button {
                text: "断开串口"
                enabled: root.isSerialConnected
                onClicked: {
                    serialBackend.closePort()
                }
            }
        }
    }
}
