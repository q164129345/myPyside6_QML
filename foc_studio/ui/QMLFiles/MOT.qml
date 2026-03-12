// MOT 电机控制页面
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#ecf0f1"

    // qmllint disable unqualified

    property bool isSerialConnected: false

    property int currentSpeed: 0
    property real currentCurrent: 0.0
    property real motorTemp: 0.0
    property real mosTemp: 0.0
    property real iqCurrent: 0.0
    property real idCurrent: 0.0
    property real uqVoltage: 0.0
    property real udVoltage: 0.0
    property int errorCode: 0
    property int enableState: 0
    property string mcuSoftwareVersion: "0.0.0.0"

    component InputField: Rectangle {
        id: control
        property alias text: input.text
        property alias validator: input.validator
        property string placeholderText: ""
        property int fontPixelSize: 13
        property int horizontalAlignment: TextInput.AlignLeft
        readonly property bool acceptableInput: input.acceptableInput

        implicitWidth: 110
        implicitHeight: 28
        radius: 4
        color: control.enabled ? "white" : "#dde1e4"
        border.color: input.activeFocus ? "#3498db" : "#bdc3c7"
        border.width: 1

        Text {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            text: control.placeholderText
            font.pixelSize: control.fontPixelSize
            color: "#95a5a6"
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: control.horizontalAlignment
            visible: input.text.length === 0
        }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            font.pixelSize: control.fontPixelSize
            color: control.enabled ? "#2c3e50" : "#7f8c8d"
            enabled: control.enabled
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: control.horizontalAlignment
            selectByMouse: control.enabled
            clip: true
        }
    }

    component ActionButton: Rectangle {
        id: control
        property string text: ""
        property color normalColor: "#27ae60"
        property color pressedColor: normalColor
        signal clicked()

        implicitWidth: 70
        implicitHeight: 28
        radius: 5
        color: control.enabled
               ? (buttonArea.pressed ? control.pressedColor : control.normalColor)
               : "#bdc3c7"

        Text {
            anchors.centerIn: parent
            text: control.text
            font.pixelSize: 12
            font.bold: true
            color: "white"
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            enabled: control.enabled
            cursorShape: control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: control.clicked()
        }
    }

    component TelemetryRow: RowLayout {
        property string label: ""
        property string range: ""
        property string value: "--"
        property string unit: ""

        spacing: 10

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

        Rectangle {
            implicitWidth: 90
            implicitHeight: 28
            radius: 4
            color: "#e8f4fd"
            border.color: "#aed6f1"
            border.width: 1

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 8
                text: value
                font.pixelSize: 13
                font.bold: true
                color: "#2980b9"
            }
        }

        Text {
            text: unit
            font.pixelSize: 13
            color: "#7f8c8d"
            Layout.preferredWidth: 36
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

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
                anchors.top: parent.top
                anchors.topMargin: 26
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                spacing: 10

                Text {
                    text: "目标速度:"
                    font.pixelSize: 13
                    color: "#2c3e50"
                    verticalAlignment: Text.AlignVCenter
                    Layout.alignment: Qt.AlignVCenter
                }

                InputField {
                    id: speedInput
                    Layout.alignment: Qt.AlignVCenter
                    placeholderText: "例如: 1500"
                    horizontalAlignment: TextInput.AlignRight
                    enabled: root.isSerialConnected
                    validator: IntValidator {
                        bottom: -10000
                        top: 10000
                    }
                }

                Text {
                    text: "RPM"
                    font.pixelSize: 13
                    color: "#7f8c8d"
                    verticalAlignment: Text.AlignVCenter
                    Layout.alignment: Qt.AlignVCenter
                }

                Item {
                    Layout.fillWidth: true
                }

                ActionButton {
                    id: startBtn
                    text: "启动"
                    Layout.alignment: Qt.AlignVCenter
                    enabled: root.isSerialConnected && speedInput.acceptableInput
                    normalColor: "#27ae60"
                    pressedColor: "#1e8449"
                    onClicked: backend.setMotorControl(1, parseInt(speedInput.text))
                }

                ActionButton {
                    id: stopBtn
                    text: "停止"
                    Layout.alignment: Qt.AlignVCenter
                    enabled: root.isSerialConnected
                    normalColor: "#e74c3c"
                    pressedColor: "#c0392b"
                    onClicked: backend.setMotorControl(0, 0)
                }
            }
        }

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

            ColumnLayout {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 30
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                TelemetryRow {
                    label: "\u8f6f\u4ef6\u7248\u672c"
                    range: "(main.sub.mini.fixed)"
                    value: root.mcuSoftwareVersion
                    unit: ""
                }

                TelemetryRow {
                    label: "使能状态"
                    range: "(0/1)"
                    value: root.isSerialConnected ? (root.enableState !== 0 ? "已使能" : "未使能") : "--"
                    unit: ""
                }

                TelemetryRow {
                    label: "转速"
                    range: "(-3000~3000)"
                    value: root.isSerialConnected ? root.currentSpeed.toString() : "--"
                    unit: "RPM"
                }

                TelemetryRow {
                    label: "电流"
                    range: "(0~30.0)"
                    value: root.isSerialConnected ? root.currentCurrent.toFixed(3) : "--"
                    unit: "A"
                }

                TelemetryRow {
                    label: "电机温度"
                    range: "(0.1 ℃)"
                    value: root.isSerialConnected ? root.motorTemp.toFixed(1) : "--"
                    unit: "℃"
                }

                TelemetryRow {
                    label: "MOS温度"
                    range: "(0.1 ℃)"
                    value: root.isSerialConnected ? root.mosTemp.toFixed(1) : "--"
                    unit: "℃"
                }

                TelemetryRow {
                    label: "Iq电流分量"
                    range: "(-32.768~32.767)"
                    value: root.isSerialConnected ? root.iqCurrent.toFixed(3) : "--"
                    unit: "A"
                }

                TelemetryRow {
                    label: "Id电流分量"
                    range: "(-32.768~32.767)"
                    value: root.isSerialConnected ? root.idCurrent.toFixed(3) : "--"
                    unit: "A"
                }

                TelemetryRow {
                    label: "Uq电压分量"
                    range: "(-32.768~32.767)"
                    value: root.isSerialConnected ? root.uqVoltage.toFixed(3) : "--"
                    unit: "V"
                }

                TelemetryRow {
                    label: "Ud电压分量"
                    range: "(-32.768~32.767)"
                    value: root.isSerialConnected ? root.udVoltage.toFixed(3) : "--"
                    unit: "V"
                }
            }
        }

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

    Connections {
        target: backend
        enabled: backend !== null

        function onSpeedUpdated(rpm)         { root.currentSpeed = rpm }
        function onMotorCurrentUpdated(amps) { root.currentCurrent = amps }
        function onMotorTempUpdated(temp)    { root.motorTemp = temp }
        function onMosTempUpdated(temp)      { root.mosTemp = temp }
        function onDqComponentsUpdated(iq, idValue, uq, ud) {
            root.iqCurrent = iq
            root.idCurrent = idValue
            root.uqVoltage = uq
            root.udVoltage = ud
        }
        function onErrorCodeUpdated(code)    { root.errorCode = code }
        function onEnableStateUpdated(state) { root.enableState = state }
        function onMcuSoftwareVersionUpdated(versionText) { root.mcuSoftwareVersion = versionText }
    }
}
