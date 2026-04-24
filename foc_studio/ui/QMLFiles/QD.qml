// QD 波形页面 —— Iq/Id 双曲线同图显示
import QtGraphs
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
    property int chartRefreshIntervalMs: 50
    property int axisRefreshIntervalMs: 250
    property int axisIdleGraceMs: 200
    property int timeWindowMs: 5000
    property var iqSamples: []
    property var idSamples: []
    property var pendingIqSamples: []
    property var pendingIdSamples: []
    property int iqSampleCount: 0
    property int idSampleCount: 0
    property double chartStartTimestampMs: 0
    property double latestTimestampMs: 0
    property double lastAxisRefreshTimestampMs: 0
    property double _smoothAxisMs: 0.0
    property real axisMinSeconds: 0.0
    property real axisMaxSeconds: timeWindowMs / 1000.0
    property real dqAxisMinValue: -0.5
    property real dqAxisMaxValue: 0.5

    // 将会话内毫秒时间戳换算成图表 X 坐标，避免每次刷新都重写整条曲线
    function sampleToXValue(timestampMs) {
        return (timestampMs - root.chartStartTimestampMs) / 1000.0
    }

    // 将待刷新的样本增量追加到曲线尾部，避免 clear + append 全量重建
    function appendPendingSamples(samples, pendingSamples, series) {
        if (pendingSamples.length === 0)
            return false

        for (var index = 0; index < pendingSamples.length; index += 1) {
            var sample = pendingSamples[index]
            sample.xValue = root.sampleToXValue(sample.timestamp)
            samples.push(sample)
            series.append(sample.xValue, sample.value)
        }
        return true
    }

    // 仅从历史窗口头部移除过期点，保持图表更新复杂度与新增样本数一致
    function trimSeriesHead(samples, series, minTimestamp) {
        var removeCount = 0

        while (removeCount < samples.length && samples[removeCount].timestamp < minTimestamp)
            removeCount += 1

        if (removeCount <= 0)
            return

        samples.splice(0, removeCount)
        series.removeMultiple(0, removeCount)
    }

    // X 轴改为独立时钟平滑滑动，避免跟随样本批量到达而偶发跳动
    function updateTimeAxisWindow(referenceTimestampMs) {
        if (referenceTimestampMs <= 0 || root.chartStartTimestampMs <= 0) {
            root.axisMinSeconds = 0.0
            root.axisMaxSeconds = root.timeWindowMs / 1000.0
            return
        }

        var latestSeconds = root.sampleToXValue(referenceTimestampMs)
        var windowSeconds = root.timeWindowMs / 1000.0
        var axisMax = Math.max(windowSeconds, latestSeconds)
        root.axisMinSeconds = Math.max(0.0, axisMax - windowSeconds)
        root.axisMaxSeconds = axisMax
    }

    // 使用帧时间（frameTime）平滑推进横轴，避免 Date.now() 在 Windows 上
    // 约 15ms 步进精度导致的轴标签跳动；若遥测停止则冻结窗口。
    function tickAxisWindow() {
        if (!root.isPageActive || root.chartStartTimestampMs <= 0 || root.latestTimestampMs <= 0) {
            root._smoothAxisMs = 0.0
            axisFrameAnimation.stop()
            return
        }

        var nowMs = Date.now()
        if (nowMs - root.latestTimestampMs > root.axisIdleGraceMs) {
            root.updateTimeAxisWindow(root.latestTimestampMs)
            root._smoothAxisMs = 0.0
            axisFrameAnimation.stop()
            return
        }

        // 首次启动或动画重启后重新锚定；过于滞后时也重新锚定（不向后跳）
        if (root._smoothAxisMs <= 0 || root._smoothAxisMs < root.latestTimestampMs - 1000)
            root._smoothAxisMs = root.latestTimestampMs

        // frameTime 由 vsync 驱动，无 Date.now() 的 15ms 步进抖动
        // 限制单帧最大步进（防止动画重启后首帧 frameTime 过大导致的前跳）
        root._smoothAxisMs += Math.min(axisFrameAnimation.frameTime * 1000.0, 50.0)

        root.updateTimeAxisWindow(root._smoothAxisMs)
    }

    // 页面激活且已有样本时启动横轴帧动画，保证窗口推进节奏与显示刷新同步
    function ensureAxisScrollRunning() {
        if (root.isPageActive && root.chartStartTimestampMs > 0 && root.latestTimestampMs > 0
                && !axisFrameAnimation.running) {
            axisFrameAnimation.start()
        }
    }

    // 当前值超出坐标轴时立即重算，正常情况下按较低频率更新 Y 轴
    function shouldRefreshAxis(latestValue, axisMin, axisMax) {
        return latestValue < axisMin || latestValue > axisMax
    }

    // 将 Y 轴的全量扫描降到低频执行，减少图表布局与重绘抖动
    function maybeRefreshAxisRanges(forceRefresh) {
        if (root.latestTimestampMs <= 0) {
            root.updateDqAxisRange([], [])
            return
        }

        var shouldRefresh = forceRefresh
                            || root.lastAxisRefreshTimestampMs <= 0
                            || root.latestTimestampMs - root.lastAxisRefreshTimestampMs >= root.axisRefreshIntervalMs
                            || root.shouldRefreshAxis(root.currentIq, root.dqAxisMinValue, root.dqAxisMaxValue)
                            || root.shouldRefreshAxis(root.currentId, root.dqAxisMinValue, root.dqAxisMaxValue)
        if (!shouldRefresh)
            return

        root.updateDqAxisRange(root.iqSamples, root.idSamples)
        root.lastAxisRefreshTimestampMs = root.latestTimestampMs
    }

    // 将高频遥测先缓存成批，等下一次定时刷新时统一并入曲线
    function enqueueTelemetry(seriesKind, value, timestampMs) {
        var sample = { "timestamp": timestampMs, "value": value }
        if (seriesKind === "iq")
            root.pendingIqSamples.push(sample)
        else
            root.pendingIdSamples.push(sample)

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

        if (root.pendingIqSamples.length > 0) {
            latestTimestampMs = Math.max(
                        latestTimestampMs,
                        root.pendingIqSamples[root.pendingIqSamples.length - 1].timestamp)
            hasNewSamples = true
        }

        if (root.pendingIdSamples.length > 0) {
            latestTimestampMs = Math.max(
                        latestTimestampMs,
                        root.pendingIdSamples[root.pendingIdSamples.length - 1].timestamp)
            hasNewSamples = true
        }

        if (!hasNewSamples) {
            chartRefreshTimer.stop()
            return
        }

        if (root.chartStartTimestampMs <= 0) {
            var earliestTimestampMs = latestTimestampMs
            if (root.pendingIqSamples.length > 0)
                earliestTimestampMs = Math.min(earliestTimestampMs, root.pendingIqSamples[0].timestamp)
            if (root.pendingIdSamples.length > 0)
                earliestTimestampMs = Math.min(earliestTimestampMs, root.pendingIdSamples[0].timestamp)
            root.chartStartTimestampMs = earliestTimestampMs
        }

        root.appendPendingSamples(root.iqSamples, root.pendingIqSamples, iqSeries)
        root.appendPendingSamples(root.idSamples, root.pendingIdSamples, idSeries)
        root.pendingIqSamples = []
        root.pendingIdSamples = []
        root.latestTimestampMs = latestTimestampMs
        var minTimestamp = root.latestTimestampMs - root.timeWindowMs
        root.trimSeriesHead(root.iqSamples, iqSeries, minTimestamp)
        root.trimSeriesHead(root.idSamples, idSeries, minTimestamp)
        root.iqSampleCount = root.iqSamples.length
        root.idSampleCount = root.idSamples.length
        root.ensureAxisScrollRunning()
        root.maybeRefreshAxisRanges(false)
        chartRefreshTimer.stop()
    }

    // 根据最近 5 秒 Iq/Id 样本联合自适应 Y 轴，保证 0 基线始终可见
    function updateDqAxisRange(iqSamples, idSamples) {
        var totalLength = iqSamples.length + idSamples.length
        if (totalLength === 0) {
            root.dqAxisMinValue = -0.5
            root.dqAxisMaxValue = 0.5
            return
        }

        var minValue = Number.POSITIVE_INFINITY
        var maxValue = Number.NEGATIVE_INFINITY

        for (var i = 0; i < iqSamples.length; i += 1) {
            var iqValue = iqSamples[i].value
            if (iqValue < minValue) minValue = iqValue
            if (iqValue > maxValue) maxValue = iqValue
        }
        for (var j = 0; j < idSamples.length; j += 1) {
            var idValue = idSamples[j].value
            if (idValue < minValue) minValue = idValue
            if (idValue > maxValue) maxValue = idValue
        }

        var axisMin = minValue
        var axisMax = maxValue

        // 0 基线始终包含在可视区内，便于观察电流符号
        if (axisMin > 0) axisMin = 0
        if (axisMax < 0) axisMax = 0

        var span = axisMax - axisMin
        var minimumSpan = 0.5
        if (span < minimumSpan) {
            var centerValue = (axisMin + axisMax) / 2.0
            axisMin = centerValue - minimumSpan / 2.0
            axisMax = centerValue + minimumSpan / 2.0
            // 重新修正 0 基线
            if (axisMin > 0) axisMin = 0
            if (axisMax < 0) axisMax = 0
            span = axisMax - axisMin
        }

        var padding = Math.max(span * 0.15, 0.1)
        axisMin = axisMin - padding
        axisMax = axisMax + padding

        root.dqAxisMinValue = axisMin
        root.dqAxisMaxValue = axisMax
    }

    // 断开串口后清空控制输入与波形缓存，避免显示旧会话数据
    function resetCharts() {
        root.iqSamples = []
        root.idSamples = []
        root.pendingIqSamples = []
        root.pendingIdSamples = []
        root.iqSampleCount = 0
        root.idSampleCount = 0
        root.chartStartTimestampMs = 0
        root.latestTimestampMs = 0
        root.lastAxisRefreshTimestampMs = 0
        root._smoothAxisMs = 0.0
        root.axisMinSeconds = 0.0
        root.axisMaxSeconds = root.timeWindowMs / 1000.0
        root.dqAxisMinValue = -0.5
        root.dqAxisMaxValue = 0.5
        iqSeries.clear()
        idSeries.clear()
        axisFrameAnimation.stop()
    }

    Timer {
        id: chartRefreshTimer
        interval: root.chartRefreshIntervalMs
        repeat: false
        running: false
        onTriggered: root.flushPendingTelemetry()
    }

    FrameAnimation {
        id: axisFrameAnimation
        running: false
        onTriggered: root.tickAxisWindow()
    }

    onIsSerialConnectedChanged: {
        if (!root.isSerialConnected) {
            speedInput.text = ""
            root.currentIq = 0.0
            root.currentId = 0.0
            root.resetCharts()
        }
    }

    onIsPageActiveChanged: {
        if (!root.isPageActive) {
            chartRefreshTimer.stop()
            root.resetCharts()
            return
        }

        root.ensureAxisScrollRunning()
        if (root.pendingIqSamples.length > 0 || root.pendingIdSamples.length > 0)
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
            title: "Iq / Id 波形"
            currentValueText: root.isSerialConnected && (root.iqSampleCount > 0 || root.idSampleCount > 0)
                              ? ("Iq: " + root.currentIq.toFixed(3) + " A  |  Id: " + root.currentId.toFixed(3) + " A")
                              : "--"

            Item {
                anchors.fill: parent

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
                        id: dqAxisX
                        min: root.axisMinSeconds
                        max: root.axisMaxSeconds
                    }
                    axisY: ValueAxis {
                        id: dqAxisY
                        min: root.dqAxisMinValue
                        max: root.dqAxisMaxValue
                    }

                    LineSeries {
                        id: iqSeries
                        color: '#f1c40f'
                    }

                    LineSeries {
                        id: idSeries
                        color: '#1abc9c'
                    }
                }

                // 图例：标注 Iq/Id 对应的曲线颜色
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
    }

    Connections {
        target: backend
        enabled: backend !== null && root.isPageActive

        // 后端 CMD 0x69 解析后通过 dqComponentsUpdated 分发 Iq/Id/Uq/Ud，此处仅用 Iq/Id
        function onDqComponentsUpdated(iq, id, uq, ud, timestampMs) {
            root.currentIq = iq
            root.currentId = id
            root.enqueueTelemetry("iq", iq, timestampMs)
            root.enqueueTelemetry("id", id, timestampMs)
        }
    }
}
