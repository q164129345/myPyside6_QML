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
    property int maxLogLines: 500
    property int maxPendingLogCount: 200
    property int logFlushIntervalMs: 150
    property bool infoAutoScroll: true
    property bool warnErrorAutoScroll: true
    property var pendingLogs: []
    property var infoLogLines: []
    property var warnErrorLogLines: []

    // HTML 特殊字符转义，防止日志内容破坏 RichText 解析
    function escapeHtml(text) {
        return String(text)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
    }

    // 以有界数组保存日志源，避免从 RichText 控件反查换行导致裁剪状态失配
    function appendHtmlLines(existingLines, htmlLines) {
        if (htmlLines.length === 0)
            return existingLines

        var mergedLines = existingLines.concat(htmlLines)
        var overflow = mergedLines.length - root.maxLogLines
        if (overflow > 0)
            return mergedLines.slice(overflow)

        return mergedLines
    }

    // 将日志源数组渲染为 RichText 文本，保留跨行选择/复制能力
    function renderLogLines(textArea, logLines) {
        textArea.text = logLines.join("<br/>")
    }

    // 先把高频日志积压到短队列，交给定时器批量刷入视图，降低主线程抖动
    function enqueueLog(level, message) {
        pendingLogs.push({
            level: level,
            message: message,
            timestampText: Qt.formatDateTime(new Date(), "hh:mm:ss.zzz")
        })

        if (root.isPageActive && pendingLogs.length >= maxPendingLogCount) {
            root.flushPendingLogs()
            return
        }

        if (!root.isPageActive) {
            var overflowCount = pendingLogs.length - maxPendingLogCount
            if (overflowCount > 0)
                pendingLogs.splice(0, overflowCount)
            return
        }

        if (!logFlushTimer.running)
            logFlushTimer.start()
    }

    // 清除时同步丢弃同类待刷新的日志，避免"清除"后旧队列又被补回界面
    function clearLogs(targetLevel) {
        if (targetLevel === 0) {
            root.infoLogLines = []
            infoTextArea.clear()
        } else {
            root.warnErrorLogLines = []
            warnErrorTextArea.clear()
        }

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

    // 批量刷新视图，并把自动滚动收敛成每批最多一次
    function flushPendingLogs() {
        if (!root.isPageActive) {
            logFlushTimer.stop()
            return
        }

        if (pendingLogs.length === 0) {
            logFlushTimer.stop()
            return
        }

        var logsToFlush = pendingLogs
        pendingLogs = []
        var infoLines = []
        var warnErrorLines = []

        for (var index = 0; index < logsToFlush.length; index += 1) {
            var item = logsToFlush[index]
            var prefix = item.level === 0 ? "" : (item.level === 1 ? "[WARN] " : "[ERROR] ")
            var color = item.level === 0 ? "#ffffff" : (item.level === 1 ? "#f1c40f" : "#e74c3c")
            var plainLine = item.timestampText + " " + prefix + item.message
            var htmlLine = "<span style=\"color:" + color + ";\">" + root.escapeHtml(plainLine) + "</span>"
            if (item.level === 0)
                infoLines.push(htmlLine)
            else
                warnErrorLines.push(htmlLine)
        }

        if (infoLines.length > 0) {
            root.infoLogLines = root.appendHtmlLines(root.infoLogLines, infoLines)
            root.renderLogLines(infoTextArea, root.infoLogLines)
        }
        if (warnErrorLines.length > 0) {
            root.warnErrorLogLines = root.appendHtmlLines(root.warnErrorLogLines, warnErrorLines)
            root.renderLogLines(warnErrorTextArea, root.warnErrorLogLines)
        }

        if (root.isPageActive && root.infoAutoScroll && infoLines.length > 0) {
            infoTextArea.cursorPosition = infoTextArea.length
        }
        if (root.isPageActive && root.warnErrorAutoScroll && warnErrorLines.length > 0) {
            warnErrorTextArea.cursorPosition = warnErrorTextArea.length
        }

        logFlushTimer.stop()
    }

    Timer {
        id: logFlushTimer
        interval: root.logFlushIntervalMs
        repeat: false
        running: false
        onTriggered: root.flushPendingLogs()
    }

    onIsPageActiveChanged: {
        if (!root.isPageActive) {
            logFlushTimer.stop()
            return
        }

        if (pendingLogs.length > 0 && !logFlushTimer.running)
            logFlushTimer.start()
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
                                infoTextArea.cursorPosition = infoTextArea.length
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

                // 日志显示（可跨行选择/复制）
                ScrollView {
                    id: infoScrollView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    TextArea {
                        id: infoTextArea
                        readOnly: true
                        selectByMouse: true
                        selectByKeyboard: true
                        persistentSelection: true
                        wrapMode: TextEdit.WrapAnywhere
                        textFormat: TextEdit.RichText
                        color: "#ffffff"
                        font.pixelSize: 12
                        font.family: "Courier New"
                        font.bold: true
                        background: null
                        selectionColor: "#3b5770"
                        selectedTextColor: "#ffffff"
                        placeholderText: root.isSerialConnected ? "暂无 INFO 日志" : "串口未连接"
                        placeholderTextColor: "#5a6a7a"
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
                                warnErrorTextArea.cursorPosition = warnErrorTextArea.length
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

                // 日志显示（可跨行选择/复制）
                ScrollView {
                    id: warnErrorScrollView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    TextArea {
                        id: warnErrorTextArea
                        readOnly: true
                        selectByMouse: true
                        selectByKeyboard: true
                        persistentSelection: true
                        wrapMode: TextEdit.WrapAnywhere
                        textFormat: TextEdit.RichText
                        color: "#f1c40f"
                        font.pixelSize: 12
                        font.family: "Courier New"
                        font.bold: true
                        background: null
                        selectionColor: "#3b5770"
                        selectedTextColor: "#ffffff"
                        placeholderText: root.isSerialConnected ? "暂无 WARN / ERROR 日志" : "串口未连接"
                        placeholderTextColor: "#5a6a7a"
                    }
                }
            }
        }
    }
}
