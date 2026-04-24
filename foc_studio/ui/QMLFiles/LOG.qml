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
    property int infoLineCount: 0
    property int warnErrorLineCount: 0

    // HTML 特殊字符转义，防止日志内容破坏 RichText 解析
    function escapeHtml(text) {
        return String(text)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
    }

    // 以 HTML 行的形式批量追加到 TextArea，超出上限时按行裁剪头部
    function appendHtmlLines(textArea, htmlLines, currentCount) {
        if (htmlLines.length === 0)
            return currentCount

        for (var i = 0; i < htmlLines.length; i += 1) {
            textArea.append(htmlLines[i])
        }

        var newCount = currentCount + htmlLines.length
        var overflow = newCount - root.maxLogLines

        if (overflow > 0) {
            var plain = textArea.getText(0, textArea.length)
            var cutIndex = 0
            for (var j = 0; j < overflow; j += 1) {
                var nl = plain.indexOf("\n", cutIndex)
                if (nl < 0) {
                    cutIndex = plain.length
                    break
                }
                cutIndex = nl + 1
            }
            if (cutIndex > 0)
                textArea.remove(0, cutIndex)
            newCount = Math.max(0, newCount - overflow)
        }

        return newCount
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
            infoTextArea.clear()
            root.infoLineCount = 0
        } else {
            warnErrorTextArea.clear()
            root.warnErrorLineCount = 0
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
            var prefix = item.level === 0 ? "[INFO]" : (item.level === 1 ? "[WARN]" : "[ERROR]")
            var color = item.level === 0 ? "#ffffff" : (item.level === 1 ? "#f1c40f" : "#e74c3c")
            var plainLine = item.timestampText + " " + prefix + " " + item.message
            var htmlLine = "<span style=\"color:" + color + ";\">" + root.escapeHtml(plainLine) + "</span>"
            if (item.level === 0)
                infoLines.push(htmlLine)
            else
                warnErrorLines.push(htmlLine)
        }

        root.infoLineCount = root.appendHtmlLines(infoTextArea, infoLines, root.infoLineCount)
        root.warnErrorLineCount = root.appendHtmlLines(warnErrorTextArea, warnErrorLines, root.warnErrorLineCount)

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
