// CHT 波形页面
import QtGraphs
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
    property int chartRefreshIntervalMs: 50
    property int timeWindowMs: 5000
    property var speedSamples: []
    property var currentSamples: []
    property var pendingSpeedSamples: []
    property var pendingCurrentSamples: []
    property double latestTimestampMs: 0
    property real speedAxisMinValue: -3000.0
    property real speedAxisMaxValue: 3000.0
    property real currentAxisMinValue: 0.0
    property real currentAxisMaxValue: 0.4

    // 根据最新样本时间裁剪历史点，保证绑定能看到数组已更新
    function trimSamples(samples, latestTimestampMs) {
        var minTimestamp = latestTimestampMs - root.timeWindowMs
        var trimmed = []
        for (var index = 0; index < samples.length; index += 1) {
            var sample = samples[index]
            if (sample.timestamp >= minTimestamp)
                trimmed.push(sample)
        }
        return trimmed
    }

    // 将时间戳样本转换成图表坐标，并重建对应曲线
    function rebuildSeries(series, samples, latestTimestampMs) {
        series.clear()
        for (var index = 0; index < samples.length; index += 1) {
            var sample = samples[index]
            var xValue = (sample.timestamp - latestTimestampMs + root.timeWindowMs) / 1000.0
            series.append(xValue, sample.value)
        }
    }

    // 将高频遥测先缓存成批，等下一次定时刷新时统一并入曲线
    function enqueueTelemetry(isSpeedSample, value) {
        var sample = { "timestamp": Date.now(), "value": value }
        if (isSpeedSample)
            root.pendingSpeedSamples.push(sample)
        else
            root.pendingCurrentSamples.push(sample)

        root.scheduleFlushPendingTelemetry()
    }

    // 仅在存在新遥测时启动刷新定时器，避免图表页前台空转。
    function scheduleFlushPendingTelemetry() {
        if (root.isPageActive && !chartRefreshTimer.running)
            chartRefreshTimer.start()
    }

    // 固定刷新频率读取最近一次遥测值，把高频信号收敛为可控的 UI 刷新节奏
    function flushPendingTelemetry() {
        if (!root.isPageActive)
            return

        var latestTimestampMs = root.latestTimestampMs
        var hasNewSamples = false

        if (root.pendingSpeedSamples.length > 0) {
            latestTimestampMs = Math.max(
                        latestTimestampMs,
                        root.pendingSpeedSamples[root.pendingSpeedSamples.length - 1].timestamp)
            root.speedSamples = root.speedSamples.concat(root.pendingSpeedSamples)
            root.pendingSpeedSamples = []
            hasNewSamples = true
        }

        if (root.pendingCurrentSamples.length > 0) {
            latestTimestampMs = Math.max(
                        latestTimestampMs,
                        root.pendingCurrentSamples[root.pendingCurrentSamples.length - 1].timestamp)
            root.currentSamples = root.currentSamples.concat(root.pendingCurrentSamples)
            root.pendingCurrentSamples = []
            hasNewSamples = true
        }

        if (!hasNewSamples) {
            chartRefreshTimer.stop()
            return
        }

        root.latestTimestampMs = latestTimestampMs
        root.refreshCharts()
        chartRefreshTimer.stop()
    }

    // 使用统一时间轴同步刷新两张图，避免波形时间窗口错位
    function refreshCharts() {
        if (!root.isPageActive || root.latestTimestampMs <= 0) {
            speedSeries.clear()
            currentSeries.clear()
            root.updateSpeedAxisRange([])
            root.updateCurrentAxisRange([])
            return
        }

        root.speedSamples = root.trimSamples(root.speedSamples, root.latestTimestampMs)
        root.currentSamples = root.trimSamples(root.currentSamples, root.latestTimestampMs)
        root.rebuildSeries(speedSeries, root.speedSamples, root.latestTimestampMs)
        root.rebuildSeries(currentSeries, root.currentSamples, root.latestTimestampMs)
        root.updateSpeedAxisRange(root.speedSamples)
        root.updateCurrentAxisRange(root.currentSamples)
    }

    // 根据最近 5 秒转速样本自适应 Y 轴，兼顾低速电机与高速电机的显示分辨率
    function updateSpeedAxisRange(samples) {
        if (samples.length === 0) {
            root.speedAxisMinValue = -3000.0
            root.speedAxisMaxValue = 3000.0
            return
        }

        var minValue = samples[0].value
        var maxValue = samples[0].value
        for (var index = 1; index < samples.length; index += 1) {
            var sampleValue = samples[index].value
            minValue = Math.min(minValue, sampleValue)
            maxValue = Math.max(maxValue, sampleValue)
        }

        var axisMin = minValue
        var axisMax = maxValue

        if (axisMin >= 0)
            axisMin = 0
        else if (axisMax <= 0)
            axisMax = 0

        var span = axisMax - axisMin
        var minimumSpan = 200.0
        if (span < minimumSpan) {
            if (axisMin >= 0) {
                axisMax = axisMin + minimumSpan
            } else if (axisMax <= 0) {
                axisMin = axisMax - minimumSpan
            } else {
                var centerValue = (axisMin + axisMax) / 2.0
                axisMin = centerValue - minimumSpan / 2.0
                axisMax = centerValue + minimumSpan / 2.0
            }
            span = axisMax - axisMin
        }

        var padding = Math.max(span * 0.15, 30.0)
        if (axisMin >= 0)
            axisMin = Math.max(0, axisMin - padding)
        else
            axisMin = axisMin - padding

        if (axisMax <= 0)
            axisMax = Math.min(0, axisMax + padding)
        else
            axisMax = axisMax + padding

        root.speedAxisMinValue = axisMin
        root.speedAxisMaxValue = axisMax
    }

    // 根据最近 5 秒电流样本自适应 Y 轴，兼顾 0A 基线与小电流可读性
    function updateCurrentAxisRange(samples) {
        if (samples.length === 0) {
            root.currentAxisMinValue = 0.0
            root.currentAxisMaxValue = 0.3
            return
        }

        var minValue = samples[0].value
        var maxValue = samples[0].value
        for (var index = 1; index < samples.length; index += 1) {
            var sampleValue = samples[index].value
            minValue = Math.min(minValue, sampleValue)
            maxValue = Math.max(maxValue, sampleValue)
        }

        var axisMin = minValue
        var axisMax = maxValue

        if (axisMin >= 0)
            axisMin = 0
        else if (axisMax <= 0)
            axisMax = 0

        var span = axisMax - axisMin
        var minimumSpan = 0.4
        if (span < minimumSpan) {
            if (axisMin >= 0) {
                axisMax = axisMin + minimumSpan
            } else if (axisMax <= 0) {
                axisMin = axisMax - minimumSpan
            } else {
                var centerValue = (axisMin + axisMax) / 2.0
                axisMin = centerValue - minimumSpan / 2.0
                axisMax = centerValue + minimumSpan / 2.0
            }
            span = axisMax - axisMin
        }

        var padding = Math.max(span * 0.15, 0.1)
        if (axisMin >= 0)
            axisMin = Math.max(0, axisMin - padding)
        else
            axisMin = axisMin - padding

        if (axisMax <= 0)
            axisMax = Math.min(0, axisMax + padding)
        else
            axisMax = axisMax + padding

        root.currentAxisMinValue = axisMin
        root.currentAxisMaxValue = axisMax
    }

    // 断开串口后清空控制输入与波形缓存，避免显示旧会话数据
    function resetCharts() {
        root.speedSamples = []
        root.currentSamples = []
        root.pendingSpeedSamples = []
        root.pendingCurrentSamples = []
        root.latestTimestampMs = 0
        root.speedAxisMinValue = -3000.0
        root.speedAxisMaxValue = 3000.0
        root.currentAxisMinValue = 0.0
        root.currentAxisMaxValue = 0.4
        speedSeries.clear()
        currentSeries.clear()
    }

    Timer {
        id: chartRefreshTimer
        interval: root.chartRefreshIntervalMs
        repeat: true
        running: false
        onTriggered: root.flushPendingTelemetry()
    }

    onIsSerialConnectedChanged: {
        if (!root.isSerialConnected) {
            speedInput.text = ""
            root.currentSpeed = 0
            root.currentCurrent = 0.0
            root.resetCharts()
        }
    }

    onIsPageActiveChanged: {
        if (!root.isPageActive) {
            chartRefreshTimer.stop()
            root.resetCharts()
            return
        }

        if (root.pendingSpeedSamples.length > 0 || root.pendingCurrentSamples.length > 0)
            root.scheduleFlushPendingTelemetry()
    }

    // 输入框组件：用于目标速度输入
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

    // 操作按钮组件：统一启动/停止按钮样式和点击行为
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

    // 波形卡片组件：统一标题、当前值和波形容器外观
    component GraphPanel: Rectangle {
        id: panel
        property string title: ""
        property string currentValueText: "--"
        default property alias graphContent: graphContainer.data

        Layout.fillWidth: true
        implicitHeight: 250
        color: "white"
        border.color: "#bdc3c7"
        border.width: 1
        radius: 8

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: panel.title
                    font.pixelSize: 12
                    font.bold: true
                    color: "#2c3e50"
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: panel.currentValueText
                    font.pixelSize: 12
                    font.bold: true
                    color: "#2980b9"
                }
            }

            Item {
                id: graphContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
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
                    text: "启动"
                    Layout.alignment: Qt.AlignVCenter
                    enabled: root.isSerialConnected && speedInput.acceptableInput
                    normalColor: "#27ae60"
                    pressedColor: "#1e8449"
                    onClicked: backend.setMotorControl(1, parseInt(speedInput.text))
                }

                ActionButton {
                    text: "停止"
                    Layout.alignment: Qt.AlignVCenter
                    enabled: root.isSerialConnected
                    normalColor: "#e74c3c"
                    pressedColor: "#c0392b"
                    onClicked: backend.setMotorControl(0, 0)
                }
            }
        }

        GraphPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 220
            title: "速度波形"
            currentValueText: root.isSerialConnected && root.speedSamples.length > 0
                              ? (root.currentSpeed.toString() + " RPM")
                              : "--"

            GraphsView {
                anchors.fill: parent
                theme: GraphsTheme {
                    colorScheme: GraphsTheme.ColorScheme.Dark
                    backgroundColor: "#262626"
                    plotAreaBackgroundColor: "#262626"
                    grid.mainColor: "#4a4a4a"
                    grid.subColor: "#333333"
                    axisX.labelTextColor: "#a8b0b8"
                    axisY.labelTextColor: "#a8b0b8"
                }
                axisX: ValueAxis {
                    id: speedAxisX
                    min: 0
                    max: root.timeWindowMs / 1000.0
                }
                axisY: ValueAxis {
                    id: speedAxisY
                    min: root.speedAxisMinValue
                    max: root.speedAxisMaxValue
                }

                LineSeries {
                    id: speedSeries
                    color: '#0731ee'
                }
            }
        }

        GraphPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 220
            title: "电流波形"
            currentValueText: root.isSerialConnected && root.currentSamples.length > 0
                              ? (root.currentCurrent.toFixed(3) + " A")
                              : "--"

            GraphsView {
                anchors.fill: parent
                theme: GraphsTheme {
                    colorScheme: GraphsTheme.ColorScheme.Dark
                    backgroundColor: "#262626"
                    plotAreaBackgroundColor: "#262626"
                    grid.mainColor: "#4a4a4a"
                    grid.subColor: "#333333"
                    axisX.labelTextColor: "#a8b0b8"
                    axisY.labelTextColor: "#a8b0b8"
                }
                axisX: ValueAxis {
                    id: currentAxisX
                    min: 0
                    max: root.timeWindowMs / 1000.0
                }
                axisY: ValueAxis {
                    id: currentAxisY
                    min: root.currentAxisMinValue
                    max: root.currentAxisMaxValue
                }

                LineSeries {
                    id: currentSeries
                    color: '#dff708'
                }
            }
        }
    }

    Connections {
        target: backend
        enabled: backend !== null && root.isPageActive

        // 后端信号驱动页面状态与曲线刷新，保持 UI 不接触协议层
        function onSpeedUpdated(rpm) {
            root.currentSpeed = rpm
            root.enqueueTelemetry(true, rpm)
        }

        function onMotorCurrentUpdated(amps) {
            root.currentCurrent = amps
            root.enqueueTelemetry(false, amps)
        }
    }
}
