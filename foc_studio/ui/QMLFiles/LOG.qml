// LOG 页面 - 显示 MCU 上报的日志消息 (CMD 0x73)
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// qmllint disable unqualified

Rectangle {
    id: root
    color: "#ecf0f1"

    property bool isSerialConnected: false
    property int maxLogCount: 500
    property bool infoAutoScroll: true
    property bool warnErrorAutoScroll: true

    // INFO 日志数据模型
    ListModel { id: infoModel }

    // WARN/ERROR 日志数据模型
    ListModel { id: warnErrorModel }

    function appendLog(level, message) {
        var now = Qt.formatDateTime(new Date(), "hh:mm:ss.zzz")
        var prefix = level === 0 ? "[INFO]" : (level === 1 ? "[WARN]" : "[ERROR]")
        var color = level === 0 ? "#ffffff" : (level === 1 ? "#f1c40f" : "#e74c3c")
        var text = now + " " + prefix + " " + message

        if (level === 0) {
            if (infoModel.count >= maxLogCount)
                infoModel.remove(0)
            infoModel.append({ logText: text, logColor: color })
            if (root.infoAutoScroll)
                Qt.callLater(infoListView.positionViewAtEnd)
        } else {
            if (warnErrorModel.count >= maxLogCount)
                warnErrorModel.remove(0)
            warnErrorModel.append({ logText: text, logColor: color })
            if (root.warnErrorAutoScroll)
                Qt.callLater(warnErrorListView.positionViewAtEnd)
        }
    }

    Connections {
        target: backend
        enabled: backend !== null
        function onLogMessageReceived(level, message) {
            root.appendLog(level, message)
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
                        onClicked: infoModel.clear()
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
                        onClicked: warnErrorModel.clear()
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
