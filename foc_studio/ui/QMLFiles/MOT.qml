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
    property real motorTemp:      0.0
    property real mosTemp:        0.0
    property int  iqCurrent:      0
    property int  idCurrent:      0
    property int  errorCode:      0
    property int  enableState:    0

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // ── 控制面板 ──────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 72
            color: "white"
            border.color: "#bdc3c7"
            border.width: 1
            radius: 8

            Text {
                text: "控制"
                font.pixelSize: 12
                font.bold: true
                color: "#2c3e50"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 6
            }

            RowLayout {
                anchors {
                    top: parent.top
                    topMargin: 26
                    left: parent.left
                    leftMargin: 16
                    right: parent.right
                    rightMargin: 16
                    bottom: parent.bottom
                    bottomMargin: 8
                }
                spacing: 10

                Text {
                    text: "目标速度："
                    font.pixelSize: 13
                    color: "#2c3e50"
                    verticalAlignment: Text.AlignVCenter
                    Layout.alignment: Qt.AlignVCenter
                }

                TextField {
                    id: speedInput
                    implicitWidth: 110
                    Layout.alignment: Qt.AlignVCenter
                    placeholderText: "例如: 1500"
                    font.pixelSize: 13
                    horizontalAlignment: TextInput.AlignRight
                    enabled: root.isSerialConnected
                    validator: IntValidator {
                        bottom: -10000
                        top: 10000
                    }
                    background: Rectangle {
                        radius: 4
                        color: speedInput.enabled ? "white" : "#dde1e4"
                        border.color: speedInput.activeFocus ? "#3498db" : "#bdc3c7"
                        border.width: 1
                    }
                }

                Text {
                    text: "RPM"
                    font.pixelSize: 13
                    color: "#7f8c8d"
                    verticalAlignment: Text.AlignVCenter
                    Layout.alignment: Qt.AlignVCenter
                }

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
                               : "#bdc3c7"
                    }
                    onClicked: backend.setMotorControl(1, parseInt(speedInput.text))
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
                               : "#bdc3c7"
                    }
                    onClicked: backend.setMotorControl(0, 0)
                }
            }
        }

        // ── 监控界面 ──────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "white"
            border.color: "#bdc3c7"
            border.width: 1
            radius: 8

            Text {
                text: "监控界面"
                font.pixelSize: 12
                font.bold: true
                color: "#2c3e50"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 6
            }

            // 遥测项组件：标签+范围 / 数值框 / 单位
            component TelemetryRow: RowLayout {
                property string label:   ""
                property string range:   ""
                property string value:   "--"
                property string unit:    ""

                spacing: 10

                // 左：标签 + 范围
                Column {
                    spacing: 2
                    Layout.preferredWidth: 110
                    Text {
                        text: label
                        font.pixelSize: 13
                        color: "#2c3e50"
                    }
                    Text {
                        text: range
                        font.pixelSize: 10
                        color: "#95a5a6"
                    }
                }

                // 中：数值显示框
                Rectangle {
                    implicitWidth: 90
                    implicitHeight: 28
                    radius: 4
                    color: "#e8f4fd"
                    border.color: "#aed6f1"
                    border.width: 1

                    Text {
                        anchors {
                            verticalCenter: parent.verticalCenter
                            right: parent.right
                            rightMargin: 8
                        }
                        text: value
                        font.pixelSize: 13
                        font.bold: true
                        color: "#2980b9"
                    }
                }

                // 右：单位
                Text {
                    text: unit
                    font.pixelSize: 13
                    color: "#7f8c8d"
                    Layout.preferredWidth: 36
                }
            }

            ColumnLayout {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: 30
                    leftMargin: 16
                    rightMargin: 16
                }
                spacing: 12

                TelemetryRow {
                    label: "使能状态"
                    range: "(0/1)"
                    value: root.isSerialConnected ? (root.enableState !== 0 ? "已使能" : "未使能") : "--"
                    unit:  ""
                }

                TelemetryRow {
                    label: "转速"
                    range: "(-3000~3000)"
                    value: root.isSerialConnected ? root.currentSpeed.toString() : "--"
                    unit:  "RPM"
                }

                TelemetryRow {
                    label: "电流"
                    range: "(0~30.0)"
                    value: root.isSerialConnected ? root.currentCurrent.toFixed(2) : "--"
                    unit:  "A"
                }

                TelemetryRow {
                    label: "电机温度"
                    range: "(0.1 ℃)"
                    value: root.isSerialConnected ? root.motorTemp.toFixed(1) : "--"
                    unit:  "℃"
                }

                TelemetryRow {
                    label: "MOS温度"
                    range: "(0.1 ℃)"
                    value: root.isSerialConnected ? root.mosTemp.toFixed(1) : "--"
                    unit:  "℃"
                }

                TelemetryRow {
                    label: "Iq电流分量"
                    range: "(int16)"
                    value: root.isSerialConnected ? root.iqCurrent.toString() : "--"
                    unit:  ""
                }

                TelemetryRow {
                    label: "Id电流分量"
                    range: "(int16)"
                    value: root.isSerialConnected ? root.idCurrent.toString() : "--"
                    unit:  ""
                }
            }
        }

        // ── 电机故障信息 ──────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 72
            color: "white"
            border.color: "#bdc3c7"
            border.width: 1
            radius: 8

            Text {
                text: "电机故障信息"
                font.pixelSize: 12
                font.bold: true
                color: "#2c3e50"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 6
            }

            Text {
                anchors.centerIn: parent
                font.pixelSize: 13
                color: root.errorCode !== 0 ? "#e74c3c" : "#27ae60"
                text: root.isSerialConnected
                      ? (root.errorCode !== 0 ? "错误码: 0x" + root.errorCode.toString(16).toUpperCase() : "正常")
                      : "--"
            }
        }
    }

    // ── 遥测信号订阅 ──────────────────────────────────────────
    Connections {
        target: backend
        enabled: backend !== null

        function onSpeedUpdated(rpm)         { root.currentSpeed   = rpm   }
        function onMotorCurrentUpdated(amps) { root.currentCurrent = amps  }
        function onMotorTempUpdated(temp)    { root.motorTemp      = temp  }
        function onMosTempUpdated(temp)      { root.mosTemp        = temp  }
        function onIqIdUpdated(iq, idValue)  { root.iqCurrent      = iq; root.idCurrent = idValue }
        function onErrorCodeUpdated(code)    { root.errorCode      = code  }
        function onEnableStateUpdated(state) { root.enableState    = state }
    }
}
