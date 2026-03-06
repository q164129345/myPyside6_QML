// MOT 电机控制页面
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#ecf0f1"

    // qmllint disable unqualified

    // 接收串口连接状态
    property bool isSerialConnected: false

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 24

        Text {
            text: "MOT 电机控制页面"
            font.pixelSize: 24
            color: "#2c3e50"
            Layout.alignment: Qt.AlignHCenter
        }

        // 转速控制区域
        RowLayout {
            spacing: 12
            Layout.alignment: Qt.AlignHCenter

            Text {
                text: "目标转速："
                font.pixelSize: 14
                color: "#2c3e50"
                verticalAlignment: Text.AlignVCenter
            }

            TextField {
                id: speedInput
                implicitWidth: 130
                placeholderText: "例如: 1500"
                font.pixelSize: 14
                horizontalAlignment: TextInput.AlignRight
                validator: IntValidator {
                    bottom: -10000
                    top: 10000
                }
            }

            Text {
                text: "RPM"
                font.pixelSize: 14
                color: "#2c3e50"
                verticalAlignment: Text.AlignVCenter
            }

            // 启动按钮
            Button {
                id: startBtn
                implicitWidth: 80
                implicitHeight: 36
                text: "启动"
                enabled: root.isSerialConnected && speedInput.acceptableInput

                contentItem: Text {
                    text: startBtn.text
                    font.pixelSize: 14
                    font.bold: true
                    color: startBtn.enabled ? "white" : "#aaaaaa"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    radius: 5
                    color: startBtn.enabled
                           ? (startBtn.pressed ? "#1e8449" : "#27ae60")
                           : "#bdc3c7"
                }

                onClicked: {
                    backend.setMotorControl(1, parseInt(speedInput.text))
                }
            }

            // 停止按钮
            Button {
                id: stopBtn
                implicitWidth: 80
                implicitHeight: 36
                text: "停止"
                enabled: root.isSerialConnected

                contentItem: Text {
                    text: stopBtn.text
                    font.pixelSize: 14
                    font.bold: true
                    color: stopBtn.enabled ? "white" : "#aaaaaa"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    radius: 5
                    color: stopBtn.enabled
                           ? (stopBtn.pressed ? "#c0392b" : "#e74c3c")
                           : "#bdc3c7"
                }

                onClicked: {
                    backend.setMotorControl(0, 0)
                }
            }
        }
    }
}
