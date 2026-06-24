// CHT 波形页面 —— 速度 / 电流实时波形
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#ecf0f1"

    // qmllint disable unqualified

    // 页面职责：提供电机控制入口，并展示速度/电流实时波形
    property bool isSerialConnected: false
    property bool isPageActive: false
    property int currentSpeed: 0
    property real currentCurrent: 0.0

    // 断开串口后复位当前值与波形（输入框由 MotorControlBar 自行清空）
    onIsSerialConnectedChanged: {
        if (!root.isSerialConnected) {
            root.currentSpeed = 0
            root.currentCurrent = 0.0
            speedChart.reset()
            currentChart.reset()
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
            title: "速度波形"
            currentValueText: root.isSerialConnected && speedChart.totalSampleCount > 0
                              ? (root.currentSpeed.toString() + " RPM")
                              : "--"

            TelemetryChart {
                id: speedChart
                anchors.fill: parent
                active: root.isPageActive
                seriesColors: ["#0731ee"]
                defaultAxisMin: -3000.0
                defaultAxisMax: 3000.0
                axisMinSpan: 200.0
                axisPaddingMin: 30.0
            }
        }

        GraphPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 220
            title: "电流波形"
            currentValueText: root.isSerialConnected && currentChart.totalSampleCount > 0
                              ? (root.currentCurrent.toFixed(3) + " A")
                              : "--"

            TelemetryChart {
                id: currentChart
                anchors.fill: parent
                active: root.isPageActive
                seriesColors: ["#dff708"]
                defaultAxisMin: 0.0
                defaultAxisMax: 0.4
                axisMinSpan: 0.4
                axisPaddingMin: 0.1
            }
        }
    }

    Connections {
        target: backend
        enabled: backend !== null && root.isPageActive

        // 后端信号驱动页面状态与曲线刷新，保持 UI 不接触协议层
        function onSpeedUpdated(rpm, timestampMs) {
            root.currentSpeed = rpm
            speedChart.pushSample(0, rpm, timestampMs)
        }

        function onMotorCurrentUpdated(amps, timestampMs) {
            root.currentCurrent = amps
            currentChart.pushSample(0, amps, timestampMs)
        }
    }
}
