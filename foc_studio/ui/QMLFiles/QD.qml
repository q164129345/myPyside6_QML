// QD 波形页面 —— Iq/Id 双曲线同图显示
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#ecf0f1"

    // qmllint disable unqualified

    // 页面职责：提供电机控制入口，并在同一坐标系内叠加显示 Iq/Id 电流波形
    property bool isSerialConnected: false
    property bool isPageActive: false
    property real currentIq: 0.0
    property real currentId: 0.0

    // 断开串口后复位当前值与波形（输入框由 MotorControlBar 自行清空）
    onIsSerialConnectedChanged: {
        if (!root.isSerialConnected) {
            root.currentIq = 0.0
            root.currentId = 0.0
            dqChart.reset()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        MotorControlBar {
            isSerialConnected: root.isSerialConnected
        }

        GraphPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 220
            title: "Iq / Id 波形"
            currentValueText: root.isSerialConnected && dqChart.totalSampleCount > 0
                              ? ("Iq: " + root.currentIq.toFixed(3) + " A  |  Id: " + root.currentId.toFixed(3) + " A")
                              : "--"

            TelemetryChart {
                id: dqChart
                anchors.fill: parent
                active: root.isPageActive
                seriesColors: ["#f1c40f", "#1abc9c"]
                defaultAxisMin: -0.5
                defaultAxisMax: 0.5
                axisMinSpan: 0.5
                axisPaddingMin: 0.1
                padBeyondZero: true
            }

            // 图例：标注 Iq/Id 对应的曲线颜色（叠加在波形右上角）
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 8
                anchors.rightMargin: 12
                implicitWidth: legendRow.implicitWidth + 16
                implicitHeight: legendRow.implicitHeight + 8
                color: "#262626"
                border.color: "#4a4a4a"
                border.width: 1
                radius: 4
                opacity: 0.85

                RowLayout {
                    id: legendRow
                    anchors.centerIn: parent
                    spacing: 12

                    RowLayout {
                        spacing: 5
                        Rectangle {
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 3
                            color: "#f1c40f"
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            text: "Iq"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#e8ecef"
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    RowLayout {
                        spacing: 5
                        Rectangle {
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 3
                            color: "#1abc9c"
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            text: "Id"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#e8ecef"
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: backend
        enabled: backend !== null && root.isPageActive

        // 后端 CMD 0x69 解析后通过 dqComponentsUpdated 分发 Iq/Id/Uq/Ud，此处仅用 Iq/Id
        function onDqComponentsUpdated(iq, id, uq, ud, timestampMs) {
            root.currentIq = iq
            root.currentId = id
            dqChart.pushSample(0, iq, timestampMs)
            dqChart.pushSample(1, id, timestampMs)
        }
    }
}
