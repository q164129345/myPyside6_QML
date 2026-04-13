// LOG 页面 - 显示 MCU 上报的日志消息 (CMD 0x73)
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// qmllint disable unqualified

Rectangle {
    id: root
    color: "#ecf0f1"

    property bool isSerialConnected: false
    property bool isPageActive: false
    property int maxLogCount: 500
    property int maxPendingLogCount: 200
    property int logFlushIntervalMs: 100
    property bool infoAutoScroll: true
    property bool warnErrorAutoScroll: true
    property var pendingLogs: []

    // INFO 日志数据模型
    ListModel { id: infoModel }

    // WARN/ERROR 日志数据模型
    ListModel { id: warnErrorModel }

    // 按批次写入模型，并把头部裁剪收敛成每批一次，避免达到上限后每条日志都整体搬移
    function appendLogsToModel(targetModel, entries) {
        if (entries.length === 0)
            return

        var overflowCount = targetModel.count + entries.length - root.maxLogCount
        if (overflowCount > 0)
            targetModel.remove(0, overflowCount)

        for (var index = 0; index < entries.length; index += 1) {
            targetModel.append(entries[index])
        }
    }

    // 先把高频日志积压到短队列，交给定时器批量刷入模型，降低主线程抖动
    function enqueueLog(level, message) {
        pendingLogs.push({
            level: level,
            message: message,
            timestampText: Qt.formatDateTime(new Date(), "hh:mm:ss.zzz")
        })

        if (pendingLogs.length >= maxPendingLogCount) {
            root.flushPendingLogs()
            return
        }

        if (!logFlushTimer.running)
            logFlushTimer.start()
    }

    // 清除模型时同步丢弃同类待刷新的日志，避免“清除”后旧队列又被补回界面。
    function clearLogs(targetLevel) {
        if (targetLevel === 0)
            infoModel.clear()
        else
            warnErrorModel.clear()

        var remainingLogs = []
        for (var index = 0; index < pendingLogs.length; index += 1) {
            var item = pendingLogs[index]
            var matchesInfo = targetLevel === 0 && item.level === 0
            var matchesWarnError = targetLevel !== 0 && item.level !== 0
            if (!matchesInfo && !matchesWarnError)
                remainingLogs.push(item)
        }
        pendingLogs = remainingLogs
    }

    // 批量刷新模型，并把自动滚动收敛成每批最多一次
    function flushPendingLogs() {
        if (pendingLogs.length === 0) {
            logFlushTimer.stop()
            return
        }

        var logsToFlush = pendingLogs
        pendingLogs = []
        var infoEntries = []
        var warnErrorEntries = []

        for (var index = 0; index < logsToFlush.length; index += 1) {
            var item = logsToFlush[index]
            var prefix = item.level === 0 ? "[INFO]" : (item.level === 1 ? "[WARN]" : "[ERROR]")
            var color = item.level === 0 ? "#ffffff" : (item.level === 1 ? "#f1c40f" : "#e74c3c")
            var entry = { logText: item.timestampText + " " + prefix + " " + item.message, logColor: color }
            if (item.level === 0)
                infoEntries.push(entry)
            else
                warnErrorEntries.push(entry)
        }

        appendLogsToModel(infoModel, infoEntries)
        appendLogsToModel(warnErrorModel, warnErrorEntries)

        if (root.isPageActive && root.infoAutoScroll && infoEntries.length > 0)
            infoListView.positionViewAtEnd()
        if (root.isPageActive && root.warnErrorAutoScroll && warnErrorEntries.length > 0)
            warnErrorListView.positionViewAtEnd()

        logFlushTimer.stop()
    }

    Timer {
        id: logFlushTimer
        interval: root.logFlushIntervalMs
        repeat: true
        running: false
        onTriggered: root.flushPendingLogs()
    }

    Connections {
        target: backend
        enabled: backend !== null
        function onLogMessageReceived(level, message) {
            root.enqueueLog(level, message)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // INFO 日志框（上半部分）
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#1e2b37"
            radius: 6

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4

                // 标题栏
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "INFO"
                        color: "#ffffff"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "自动滚动"
                        color: "#ffffff"
                        font.pixelSize: 12
                        font.bold: true
                        verticalAlignment: Text.AlignVCenter
                    }

                    Switch {
                        id: infoAutoScrollSwitch
                        checked: root.infoAutoScroll
                        onCheckedChanged: {
                            root.infoAutoScroll = checked
                            if (checked)
                                infoListView.positionViewAtEnd()
                        }
                    }

                    Button {
                        text: "清除"
                        implicitWidth: 50
                        implicitHeight: 22
                        font.pixelSize: 11
                        onClicked: root.clearLogs(0)
                    }
                }

                // 分隔线
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#2c3e50"
                }

                // 日志列表
                ListView {
                    id: infoListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: infoModel
                    clip: true
                    spacing: 1
                    reuseItems: true

                    delegate: Text {
                        width: infoListView.width
                        text: model.logText
                        color: model.logColor
                        font.pixelSize: 12
                        font.family: "Courier New"
                        font.bold: true
                        wrapMode: Text.WrapAnywhere
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: infoModel.count === 0
                        text: root.isSerialConnected ? "暂无 INFO 日志" : "串口未连接"
                        color: "#5a6a7a"
                        font.pixelSize: 13
                    }
                }
            }
        }

        // WARN/ERROR 日志框（下半部分）
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#1e2b37"
            radius: 6

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4

                // 标题栏
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "WARN / ERROR"
                        color: "#f1c40f"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "自动滚动"
                        color: "#f1c40f"
                        font.pixelSize: 12
                        font.bold: true
                        verticalAlignment: Text.AlignVCenter
                    }

                    Switch {
                        id: warnErrorAutoScrollSwitch
                        checked: root.warnErrorAutoScroll
                        onCheckedChanged: {
                            root.warnErrorAutoScroll = checked
                            if (checked)
                                warnErrorListView.positionViewAtEnd()
                        }
                    }

                    Button {
                        text: "清除"
                        implicitWidth: 50
                        implicitHeight: 22
                        font.pixelSize: 11
                        onClicked: root.clearLogs(1)
                    }
                }

                // 分隔线
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#2c3e50"
                }

                // 日志列表
                ListView {
                    id: warnErrorListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: warnErrorModel
                    clip: true
                    spacing: 1
                    reuseItems: true

                    delegate: Text {
                        width: warnErrorListView.width
                        text: model.logText
                        color: model.logColor
                        font.pixelSize: 12
                        font.family: "Courier New"
                        font.bold: true
                        wrapMode: Text.WrapAnywhere
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: warnErrorModel.count === 0
                        text: root.isSerialConnected ? "暂无 WARN / ERROR 日志" : "串口未连接"
                        color: "#5a6a7a"
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
