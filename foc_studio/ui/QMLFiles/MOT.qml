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

    // 遥测数据（由 Connections 更新）
    property int  currentSpeed:   0
    property real currentCurrent: 0.0

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── 顶部命令栏 ─────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 48
            color: '#345d5e'

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 16
                    rightMargin: 16
                    topMargin: 10
                    bottomMargin: 10
                }
                spacing: 10

                // 标签
                Text {
                    text: "目标速度："
                    font.pixelSize: 14
                    color: "#ecf0f1"
                    verticalAlignment: Text.AlignVCenter
                    Layout.alignment: Qt.AlignVCenter
                }

                // 转速输入框
                TextField {
                    id: speedInput
                    implicitWidth: 120
                    Layout.alignment: Qt.AlignVCenter
                    placeholderText: "例如: 1500"
                    font.pixelSize: 14
                    horizontalAlignment: TextInput.AlignRight
                    enabled: root.isSerialConnected
                    validator: IntValidator {
                        bottom: -10000
                        top: 10000
                    }
                    background: Rectangle {
                        radius: 4
                        color: speedInput.enabled ? "white" : "#45555f"
                        border.color: speedInput.activeFocus ? "#3498db" : "transparent"
                        border.width: 2
                    }
                }

                // 单位
                Text {
                    text: "RPM"
                    font.pixelSize: 14
                    color: "#bdc3c7"
                    verticalAlignment: Text.AlignVCenter
                    Layout.alignment: Qt.AlignVCenter
                }

                // 弹性空间 — 将按钮推到右侧
                Item { Layout.fillWidth: true }

                // 启动按钮
                Button {
                    id: startBtn
                    implicitWidth: 70
                    implicitHeight: 28
                    text: "启动"
                    Layout.alignment: Qt.AlignVCenter
                    enabled: root.isSerialConnected && speedInput.acceptableInput

                    contentItem: Text {
                        text: startBtn.text
                        font.pixelSize: 12
                        font.bold: true
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 5
                        color: startBtn.enabled
                               ? (startBtn.pressed ? "#1e8449" : "#27ae60")
                               : "#45555f"
                    }

                    onClicked: {
                        backend.setMotorControl(1, parseInt(speedInput.text))
                    }
                }

                // 停止按钮
                Button {
                    id: stopBtn
                    implicitWidth: 70
                    implicitHeight: 28
                    text: "停止"
                    Layout.alignment: Qt.AlignVCenter
                    enabled: root.isSerialConnected

                    contentItem: Text {
                        text: stopBtn.text
                        font.pixelSize: 12
                        font.bold: true
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 5
                        color: stopBtn.enabled
                               ? (stopBtn.pressed ? "#c0392b" : "#e74c3c")
                               : "#45555f"
                    }

                    onClicked: {
                        backend.setMotorControl(0, 0)
                    }
                }
            }
        }

        // ── 内容区 ─────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridLayout {
                anchors.centerIn: parent
                columns: 2
                rowSpacing: 16
                columnSpacing: 24

                // 转速行
                Text {
                    text: "转速"
                    font.pixelSize: 14
                    color: "#7f8c8d"
                }
                Text {
                    text: root.isSerialConnected ? root.currentSpeed + " RPM" : "--"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#2c3e50"
                    horizontalAlignment: Text.AlignRight
                    Layout.minimumWidth: 120
                }

                // 电流行
                Text {
                    text: "电流"
                    font.pixelSize: 14
                    color: "#7f8c8d"
                }
                Text {
                    text: root.isSerialConnected ? root.currentCurrent.toFixed(2) + " A" : "--"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#2c3e50"
                    horizontalAlignment: Text.AlignRight
                    Layout.minimumWidth: 120
                }
            }
        }
    }

    // ── 遥测信号订阅 ──────────────────────────────────────────
    Connections {
        target: backend
        enabled: backend !== null

        function onSpeedUpdated(rpm) {
            root.currentSpeed = rpm
        }
        function onMotorCurrentUpdated(amps) {
            root.currentCurrent = amps
        }
    }
}
