// 电机控制卡：目标速度输入 + 启动/停止，CHT/QD 页共用
// 启动/停止直接调用 backend.setMotorControl(enable, speed)；断开串口时清空输入。
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: control

    // qmllint disable unqualified

    property bool isSerialConnected: false

    Layout.fillWidth: true
    implicitHeight: 72
    color: "white"
    border.color: "#bdc3c7"
    border.width: 1
    radius: 8

    onIsSerialConnectedChanged: {
        if (!control.isSerialConnected)
            speedInput.text = ""
    }

    // 输入框组件：用于目标速度输入
    component InputField: Rectangle {
        id: field
        property alias text: input.text
        property alias validator: input.validator
        property string placeholderText: ""
        property int fontPixelSize: 13
        property int horizontalAlignment: TextInput.AlignLeft
        readonly property bool acceptableInput: input.acceptableInput

        implicitWidth: 110
        implicitHeight: 28
        radius: 4
        color: field.enabled ? "white" : "#dde1e4"
        border.color: input.activeFocus ? "#3498db" : "#bdc3c7"
        border.width: 1

        Text {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            text: field.placeholderText
            font.pixelSize: field.fontPixelSize
            color: "#95a5a6"
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: field.horizontalAlignment
            visible: input.text.length === 0
        }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            font.pixelSize: field.fontPixelSize
            color: field.enabled ? "#2c3e50" : "#7f8c8d"
            enabled: field.enabled
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: field.horizontalAlignment
            selectByMouse: field.enabled
            clip: true
        }
    }

    // 操作按钮组件：统一启动/停止按钮样式和点击行为
    component ActionButton: Rectangle {
        id: button
        property string text: ""
        property color normalColor: "#27ae60"
        property color pressedColor: normalColor
        signal clicked()

        implicitWidth: 70
        implicitHeight: 28
        radius: 5
        color: button.enabled
               ? (buttonArea.pressed ? button.pressedColor : button.normalColor)
               : "#bdc3c7"

        Text {
            anchors.centerIn: parent
            text: button.text
            font.pixelSize: 12
            font.bold: true
            color: "white"
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            enabled: button.enabled
            cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.clicked()
        }
    }

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
            enabled: control.isSerialConnected
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
            text: "启动"
            Layout.alignment: Qt.AlignVCenter
            enabled: control.isSerialConnected && speedInput.acceptableInput
            normalColor: "#27ae60"
            pressedColor: "#1e8449"
            onClicked: backend.setMotorControl(1, parseInt(speedInput.text))
        }

        ActionButton {
            text: "停止"
            Layout.alignment: Qt.AlignVCenter
            enabled: control.isSerialConnected
            normalColor: "#e74c3c"
            pressedColor: "#c0392b"
            onClicked: backend.setMotorControl(0, 0)
        }
    }
}
