// 通用实时遥测图表组件
// 自包含一个 GraphsView（含主题、X/Y 轴、1~2 条 LineSeries），并封装：
//   - 高频样本批缓冲（refreshIntervalMs 定时 flush）
//   - min/max 包络抽稀（渲染点数与上报速率解耦，保留尖峰）
//   - Y 轴低频自适应、X 轴帧驱动平滑滚动
// 页面通过 pushSample(seriesIndex, value, timestampMs) 喂数据，通过 reset() 清空。
import QtGraphs
import QtQuick

Item {
    id: root

    // qmllint disable unqualified

    // ---- 公开配置 ----
    property bool active: false                      // 页面是否激活，驱动定时器启停
    property int timeWindowMs: 10000                 // 可视时间窗（毫秒）
    property int refreshIntervalMs: 50               // UI 批刷新周期（毫秒）
    property int axisRefreshIntervalMs: 250          // Y 轴自适应最低刷新间隔
    property int axisIdleGraceMs: 200                // 超过此静默则冻结横轴滚动
    property int targetPointsPerSeries: 600          // 抽稀目标点数（约绘图区像素宽）
    property var seriesColors: ["#0731ee"]           // 长度 1 或 2，决定启用几条曲线与颜色

    // Y 轴自适应参数
    property real defaultAxisMin: -1.0
    property real defaultAxisMax: 1.0
    property real axisMinSpan: 1.0                   // 最小量程，避免噪声放大
    property real axisPaddingRatio: 0.15
    property real axisPaddingMin: 0.1
    property bool clampToZero: true                  // 量程始终包含 0 基线
    property bool padBeyondZero: false               // 留白是否允许越过 0（双极性曲线设 true）

    // 主题颜色
    property color backgroundColor: "#262626"
    property color gridMainColor: "#4a4a4a"
    property color gridSubColor: "#333333"
    property color axisLabelColor: "#a8b0b8"

    // 只读：当前已绘制样本总数（供页面判断是否显示 "--"）
    readonly property int totalSampleCount: root._sampleCount

    // ---- 内部状态 ----
    property int _seriesCount: Math.min(2, root.seriesColors.length)
    property real _bucketMs: root.timeWindowMs / Math.max(1, root.targetPointsPerSeries)
    property var _pending: [[], []]                  // 每条曲线的原始待入样本
    property var _samples: [[], []]                  // 每条曲线已绘制（抽稀后）的点
    property var _buckets: [null, null]              // 每条曲线当前开放的时间桶
    property int _sampleCount: 0
    property double chartStartTimestampMs: 0         // X=0 对应的会话起点
    property double latestTimestampMs: 0
    property double lastAxisRefreshTimestampMs: 0
    property double _smoothAxisMs: 0.0

    property real axisMinSeconds: 0.0
    property real axisMaxSeconds: timeWindowMs / 1000.0
    property real yAxisMin: defaultAxisMin
    property real yAxisMax: defaultAxisMax

    // ---- 公开方法 ----
    // 追加一个采样点（高频调用，仅入缓冲，不立即绘制）
    function pushSample(seriesIndex, value, timestampMs) {
        if (seriesIndex < 0 || seriesIndex >= root._seriesCount)
            return
        root._pending[seriesIndex].push({ "timestamp": timestampMs, "value": value })
        root.scheduleFlush()
    }

    // 清空全部缓存与曲线，回到初始量程
    function reset() {
        root._pending = [[], []]
        root._samples = [[], []]
        root._buckets = [null, null]
        root._sampleCount = 0
        root.chartStartTimestampMs = 0
        root.latestTimestampMs = 0
        root.lastAxisRefreshTimestampMs = 0
        root._smoothAxisMs = 0.0
        root.axisMinSeconds = 0.0
        root.axisMaxSeconds = root.timeWindowMs / 1000.0
        root.yAxisMin = root.defaultAxisMin
        root.yAxisMax = root.defaultAxisMax
        series0.clear()
        series1.clear()
        chartRefreshTimer.stop()
        axisFrameAnimation.stop()
    }

    // ---- 内部实现 ----
    function _seriesAt(index) {
        return index === 0 ? series0 : series1
    }

    // 会话内毫秒时间戳换算成 X 坐标（秒）
    function sampleToXValue(timestampMs) {
        return (timestampMs - root.chartStartTimestampMs) / 1000.0
    }

    // 仅存在新样本时启动一次性刷新定时器，避免前台空转
    function scheduleFlush() {
        if (root.active && !chartRefreshTimer.running)
            chartRefreshTimer.start()
    }

    // 关闭一条曲线当前开放的时间桶：按时间序把 min/max 包络点追加进曲线
    function _closeBucket(seriesIndex) {
        var bucket = root._buckets[seriesIndex]
        if (bucket === null || !bucket.has)
            return

        var series = root._seriesAt(seriesIndex)
        var samples = root._samples[seriesIndex]
        var first
        var second
        // 同值或单点桶只产生一个点；否则按时间戳先后输出两点，保持 X 单调
        if (bucket.minTs === bucket.maxTs || bucket.minValue === bucket.maxValue) {
            first = { "timestamp": bucket.minTs, "value": bucket.minValue }
            second = null
        } else if (bucket.minTs <= bucket.maxTs) {
            first = { "timestamp": bucket.minTs, "value": bucket.minValue }
            second = { "timestamp": bucket.maxTs, "value": bucket.maxValue }
        } else {
            first = { "timestamp": bucket.maxTs, "value": bucket.maxValue }
            second = { "timestamp": bucket.minTs, "value": bucket.minValue }
        }

        first.xValue = root.sampleToXValue(first.timestamp)
        samples.push(first)
        series.append(first.xValue, first.value)
        if (second !== null) {
            second.xValue = root.sampleToXValue(second.timestamp)
            samples.push(second)
            series.append(second.xValue, second.value)
        }
        bucket.has = false
    }

    // 把一条曲线缓冲里的样本按时间桶聚合成 min/max 包络
    function _flushSeries(seriesIndex) {
        var pending = root._pending[seriesIndex]
        if (pending.length === 0)
            return

        for (var i = 0; i < pending.length; i += 1) {
            var sample = pending[i]
            var bucketIndex = Math.floor((sample.timestamp - root.chartStartTimestampMs) / root._bucketMs)
            var bucket = root._buckets[seriesIndex]

            if (bucket === null || !bucket.has || bucket.index !== bucketIndex) {
                root._closeBucket(seriesIndex)
                root._buckets[seriesIndex] = {
                    "index": bucketIndex,
                    "has": true,
                    "minValue": sample.value,
                    "minTs": sample.timestamp,
                    "maxValue": sample.value,
                    "maxTs": sample.timestamp
                }
            } else {
                if (sample.value < bucket.minValue) {
                    bucket.minValue = sample.value
                    bucket.minTs = sample.timestamp
                }
                if (sample.value > bucket.maxValue) {
                    bucket.maxValue = sample.value
                    bucket.maxTs = sample.timestamp
                }
            }
        }
        root._pending[seriesIndex] = []
    }

    // 仅从历史窗口头部移除过期点，复杂度与新增点数一致
    function _trimSeriesHead(seriesIndex, minTimestamp) {
        var samples = root._samples[seriesIndex]
        var removeCount = 0
        while (removeCount < samples.length && samples[removeCount].timestamp < minTimestamp)
            removeCount += 1
        if (removeCount <= 0)
            return
        samples.splice(0, removeCount)
        root._seriesAt(seriesIndex).removeMultiple(0, removeCount)
    }

    // 定时批刷新：抽稀入图 + 修剪过期 + 推进横轴 + 低频刷新 Y 轴
    function flush() {
        if (!root.active) {
            chartRefreshTimer.stop()
            return
        }

        var latest = root.latestTimestampMs
        var earliest = Number.POSITIVE_INFINITY
        var hasNew = false
        for (var s = 0; s < root._seriesCount; s += 1) {
            var pending = root._pending[s]
            if (pending.length > 0) {
                hasNew = true
                if (pending[0].timestamp < earliest)
                    earliest = pending[0].timestamp
                var lastTs = pending[pending.length - 1].timestamp
                if (lastTs > latest)
                    latest = lastTs
            }
        }

        if (!hasNew) {
            chartRefreshTimer.stop()
            return
        }

        if (root.chartStartTimestampMs <= 0)
            root.chartStartTimestampMs = earliest

        for (var k = 0; k < root._seriesCount; k += 1)
            root._flushSeries(k)

        root.latestTimestampMs = latest
        var minTimestamp = root.latestTimestampMs - root.timeWindowMs
        var total = 0
        for (var t = 0; t < root._seriesCount; t += 1) {
            root._trimSeriesHead(t, minTimestamp)
            total += root._samples[t].length
        }
        root._sampleCount = total

        root.ensureAxisScrollRunning()
        root.maybeRefreshAxisRanges(false)
        chartRefreshTimer.stop()
    }

    // ---- 横轴平滑滚动（帧驱动，避免 Date.now() 的步进抖动） ----
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

    function tickAxisWindow() {
        if (!root.active || root.chartStartTimestampMs <= 0 || root.latestTimestampMs <= 0) {
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

        if (root._smoothAxisMs <= 0 || root._smoothAxisMs < root.latestTimestampMs - 1000)
            root._smoothAxisMs = root.latestTimestampMs

        root._smoothAxisMs += Math.min(axisFrameAnimation.frameTime * 1000.0, 50.0)
        root.updateTimeAxisWindow(root._smoothAxisMs)
    }

    function ensureAxisScrollRunning() {
        if (root.active && root.chartStartTimestampMs > 0 && root.latestTimestampMs > 0
                && !axisFrameAnimation.running) {
            axisFrameAnimation.start()
        }
    }

    // ---- Y 轴低频自适应 ----
    function _valueExceedsAxis(value) {
        return value < root.yAxisMin || value > root.yAxisMax
    }

    function maybeRefreshAxisRanges(forceRefresh) {
        if (root.latestTimestampMs <= 0) {
            root.yAxisMin = root.defaultAxisMin
            root.yAxisMax = root.defaultAxisMax
            return
        }

        var due = root.latestTimestampMs - root.lastAxisRefreshTimestampMs >= root.axisRefreshIntervalMs
        var shouldRefresh = forceRefresh || root.lastAxisRefreshTimestampMs <= 0 || due
        if (!shouldRefresh) {
            // 即便未到刷新周期，最新值超出当前量程时也立即重算
            for (var s = 0; s < root._seriesCount; s += 1) {
                var samples = root._samples[s]
                if (samples.length > 0 && root._valueExceedsAxis(samples[samples.length - 1].value)) {
                    shouldRefresh = true
                    break
                }
            }
        }
        if (!shouldRefresh)
            return

        root._recomputeYAxis()
        root.lastAxisRefreshTimestampMs = root.latestTimestampMs
    }

    function _recomputeYAxis() {
        var minValue = Number.POSITIVE_INFINITY
        var maxValue = Number.NEGATIVE_INFINITY
        for (var s = 0; s < root._seriesCount; s += 1) {
            var samples = root._samples[s]
            for (var i = 0; i < samples.length; i += 1) {
                var v = samples[i].value
                if (v < minValue) minValue = v
                if (v > maxValue) maxValue = v
            }
        }

        if (minValue === Number.POSITIVE_INFINITY) {
            root.yAxisMin = root.defaultAxisMin
            root.yAxisMax = root.defaultAxisMax
            return
        }

        var axisMin = minValue
        var axisMax = maxValue
        if (root.clampToZero) {
            if (axisMin > 0) axisMin = 0
            if (axisMax < 0) axisMax = 0
        }

        var span = axisMax - axisMin
        if (span < root.axisMinSpan) {
            // 单极性曲线不允许留白越过 0 时，最小量程从 0 基线向数据方向展开。
            if (root.clampToZero && !root.padBeyondZero && axisMin >= 0) {
                axisMin = 0
                axisMax = root.axisMinSpan
            } else if (root.clampToZero && !root.padBeyondZero && axisMax <= 0) {
                axisMin = -root.axisMinSpan
                axisMax = 0
            } else {
                var center = (axisMin + axisMax) / 2.0
                axisMin = center - root.axisMinSpan / 2.0
                axisMax = center + root.axisMinSpan / 2.0
                if (root.clampToZero) {
                    if (axisMin > 0) axisMin = 0
                    if (axisMax < 0) axisMax = 0
                }
            }
            span = axisMax - axisMin
        }

        var pad = Math.max(span * root.axisPaddingRatio, root.axisPaddingMin)
        var newMin = axisMin - pad
        var newMax = axisMax + pad
        if (!root.padBeyondZero) {
            if (axisMin >= 0) newMin = Math.max(0, newMin)
            if (axisMax <= 0) newMax = Math.min(0, newMax)
        }

        root.yAxisMin = newMin
        root.yAxisMax = newMax
    }

    onActiveChanged: {
        if (!root.active) {
            chartRefreshTimer.stop()
            root.reset()
            return
        }
        root.ensureAxisScrollRunning()
        for (var s = 0; s < root._seriesCount; s += 1) {
            if (root._pending[s].length > 0) {
                root.scheduleFlush()
                break
            }
        }
    }

    Timer {
        id: chartRefreshTimer
        interval: root.refreshIntervalMs
        repeat: false
        running: false
        onTriggered: root.flush()
    }

    FrameAnimation {
        id: axisFrameAnimation
        running: false
        onTriggered: root.tickAxisWindow()
    }

    GraphsView {
        anchors.fill: parent

        theme: GraphsTheme {
            colorScheme: GraphsTheme.ColorScheme.Dark
            backgroundColor: root.backgroundColor
            plotAreaBackgroundColor: root.backgroundColor
            grid.mainColor: root.gridMainColor
            grid.subColor: root.gridSubColor
            axisX.labelTextColor: root.axisLabelColor
            axisY.labelTextColor: root.axisLabelColor
        }

        axisX: ValueAxis {
            min: root.axisMinSeconds
            max: root.axisMaxSeconds
        }
        axisY: ValueAxis {
            min: root.yAxisMin
            max: root.yAxisMax
        }

        LineSeries {
            id: series0
            color: root.seriesColors.length > 0 ? root.seriesColors[0] : "transparent"
        }
        LineSeries {
            id: series1
            visible: root._seriesCount > 1
            color: root.seriesColors.length > 1 ? root.seriesColors[1] : "transparent"
        }
    }
}
