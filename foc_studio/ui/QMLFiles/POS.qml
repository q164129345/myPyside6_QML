// POS 位置传感器监控页面（霍尔编码器 / 绝对式编码器 / 增量式编码器）
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#ecf0f1"

    // qmllint disable unqualified

    property bool isSerialConnected: false
    property bool isPageActive: false

    // 霍尔编码器
    property int hallA: 0
    property int hallB: 0
    property int hallC: 0
    property int hallState: 0
    property int electricSector: -1
    property bool hallTelemetryAvailable: false

    // 绝对式编码器（协议 CMD 0x75，后端尚未实现解析；以下属性名为与后端约定的契约占位）
    property int absPulseCounter: 0
    property int absCpr: 0
    property bool absTelemetryAvailable: false

    function syncCachedBackendState() {
        if (backend === null)
            return

        root.hallA = backend.hallA
        root.hallB = backend.hallB
        root.hallC = backend.hallC
        root.hallState = backend.hallState
        root.electricSector = backend.electricSector
        root.hallTelemetryAvailable = backend.hallTelemetryAvailable

        root.absPulseCounter = backend.absEncoderPulseCounter
        root.absCpr = backend.absEncoderCpr
        root.absTelemetryAvailable = backend.absEncoderTelemetryAvailable
    }

    function formatValue(value, available) {
        return available ? value.toString() : "--"
    }

    function statusText() {
        if (!root.isSerialConnected)
            return "串口未连接"
        if (!root.hallTelemetryAvailable)
            return "等待 HALL 数据"
        return "正在接收 HALL 数据"
    }

    onIsPageActiveChanged: {
        if (root.isPageActive)
            root.syncCachedBackendState()
    }

    Component.onCompleted: {
        root.syncCachedBackendState()
    }

    component HallLedIndicator: Rectangle {
        id: indicator
        property string label: ""
        property int stateValue: 0
        property bool available: false

        implicitWidth: 150
        implicitHeight: 150
        radius: 8
        color: "white"
        border.color: "#bdc3c7"
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: indicator.label
                font.pixelSize: 15
                font.bold: true
                color: "#2c3e50"
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 36
                height: 36
                radius: 18
                color: !indicator.available ? "#b2bec3" : (indicator.stateValue !== 0 ? "#2ecc71" : "#5d6d7e")
                border.color: !indicator.available ? "#95a5a6" : (indicator.stateValue !== 0 ? "#27ae60" : "#34495e")
                border.width: 2

                Rectangle {
                    width: 15
                    height: 15
                    radius: 7.5
                    anchors.centerIn: parent
                    color: !indicator.available ? "#dfe6e9" : (indicator.stateValue !== 0 ? "#a9f5bc" : "#85929e")
                    opacity: 0.8
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: indicator.available ? indicator.stateValue.toString() : "--"
                font.pixelSize: 24
                font.bold: true
                color: indicator.available ? "#2c3e50" : "#95a5a6"
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                text: indicator.available
                      ? (indicator.stateValue !== 0 ? "高电平" : "低电平")
                      : "无数据"
                font.pixelSize: 12
                color: "#7f8c8d"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }

    component ValueDisplay: Rectangle {
        id: display
        property string label: ""
        property string value: "--"

        implicitWidth: 240
        implicitHeight: 110
        radius: 8
        color: "white"
        border.color: "#bdc3c7"
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            Text {
                text: display.label
                font.pixelSize: 14
                font.bold: true
                color: "#2c3e50"
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 6
                color: "#e8f4fd"
                border.color: "#aed6f1"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: display.value
                    font.pixelSize: 28
                    font.bold: true
                    color: "#2980b9"
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 64
            radius: 8
            color: "white"
            border.color: "#bdc3c7"
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4

                Text {
                    text: "位置传感器监控"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#2c3e50"
                }

                Text {
                    text: root.isSerialConnected ? "串口已连接" : "串口未连接"
                    font.pixelSize: 12
                    color: root.isSerialConnected ? "#27ae60" : "#7f8c8d"
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: hallGroupLayout.implicitHeight + 32
            radius: 8
            color: "white"
            border.color: "#bdc3c7"
            border.width: 1

            ColumnLayout {
                id: hallGroupLayout
                anchors.fill: parent
                anchors.margins: 16
                spacing: 18

                Text {
                    text: "霍尔编码器"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#2c3e50"
                }

                Text {
                    text: root.statusText()
                    font.pixelSize: 12
                    color: root.hallTelemetryAvailable ? "#27ae60" : "#7f8c8d"
                }

                Text {
                    text: "霍尔原始电平"
                    font.pixelSize: 13
                    font.bold: true
                    color: "#2c3e50"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    HallLedIndicator {
                        Layout.fillWidth: true
                        label: "HALL A"
                        stateValue: root.hallA
                        available: root.hallTelemetryAvailable
                    }

                    HallLedIndicator {
                        Layout.fillWidth: true
                        label: "HALL B"
                        stateValue: root.hallB
                        available: root.hallTelemetryAvailable
                    }

                    HallLedIndicator {
                        Layout.fillWidth: true
                        label: "HALL C"
                        stateValue: root.hallC
                        available: root.hallTelemetryAvailable
                    }
                }

                Text {
                    text: "霍尔推导状态"
                    font.pixelSize: 13
                    font.bold: true
                    color: "#2c3e50"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    ValueDisplay {
                        Layout.fillWidth: true
                        label: "hall_state"
                        value: root.formatValue(root.hallState, root.hallTelemetryAvailable)
                    }

                    ValueDisplay {
                        Layout.fillWidth: true
                        label: "electric_sector"
                        value: root.formatValue(root.electricSector, root.hallTelemetryAvailable)
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: absGroupLayout.implicitHeight + 32
            radius: 8
            color: "white"
            border.color: "#bdc3c7"
            border.width: 1

            ColumnLayout {
                id: absGroupLayout
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Text {
                    text: "绝对式编码器"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#2c3e50"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    ValueDisplay {
                        Layout.fillWidth: true
                        label: "PPR (cpr)"
                        value: root.formatValue(root.absCpr, root.absTelemetryAvailable)
                    }

                    ValueDisplay {
                        Layout.fillWidth: true
                        label: "单圈值 (pulse_counter)"
                        value: root.formatValue(root.absPulseCounter, root.absTelemetryAvailable)
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: incGroupLayout.implicitHeight + 32
            radius: 8
            color: "white"
            border.color: "#bdc3c7"
            border.width: 1

            ColumnLayout {
                id: incGroupLayout
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Text {
                    text: "增量式编码器（协议待补充）"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#2c3e50"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    ValueDisplay {
                        Layout.fillWidth: true
                        label: "PPR"
                        value: "--"
                    }

                    ValueDisplay {
                        Layout.fillWidth: true
                        label: "单圈值"
                        value: "--"
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "当前协议未定义增量式编码器数据帧，待后续补充后接入"
                    font.pixelSize: 12
                    color: "#7f8c8d"
                    wrapMode: Text.WordWrap
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    Connections {
        target: backend
        // 仅在页面激活时监听缓存变化；页面重新显示时再主动补齐一次缓存。
        enabled: backend !== null && root.isPageActive

        function onHallTelemetryChanged() {
            root.syncCachedBackendState()
        }

        function onAbsEncoderTelemetryChanged() {
            root.syncCachedBackendState()
        }
    }
}
