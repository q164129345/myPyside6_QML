// SYS 系统功能页面
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#ecf0f1"
    
    // qmllint disable unqualified

    // 串口波特率
    readonly property int baudRate: 460800
    readonly property string softwareVersion: "v0.0.0.5"

    // 接收串口连接状态
    property bool isSerialConnected: false
    property var portListModel: []  // 存储串口列表
    
    property int txFrameCountTotal: backend ? backend.txFrameCountTotal : 0
    property int rxFrameCountTotal: backend ? backend.rxFrameCountTotal : 0
    property int txBytesTotal: backend ? backend.txBytesTotal : 0
    property int rxBytesTotal: backend ? backend.rxBytesTotal : 0
    property int txBytesPerSec: backend ? backend.txBytesPerSec : 0
    property int rxBytesPerSec: backend ? backend.rxBytesPerSec : 0
    property int rxCrcErrorCount: backend ? backend.rxCrcErrorCount : 0
    property int rxInvalidFrameCount: backend ? backend.rxInvalidFrameCount : 0

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        Text {
            font.pixelSize: 24
            color: "#2c3e50"
            Layout.alignment: Qt.AlignHCenter
        }

        // 串口状态显示
        Text {
            text: root.isSerialConnected ? "串口状态: 已连接 ✓" : "串口状态: 未连接"
            font.pixelSize: 16
            color: root.isSerialConnected ? "#27ae60" : "#e74c3c"
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: "软件版本: " + root.softwareVersion
            font.pixelSize: 14
            color: "#2c3e50"
            Layout.alignment: Qt.AlignHCenter
        }

        // 串口选择区域
        RowLayout {
            spacing: 10
            Layout.alignment: Qt.AlignHCenter

            Text {
                text: "选择串口："
                font.pixelSize: 14
                color: "#2c3e50"
            }

            ComboBox {
                id: portComboBox
                width: 450
                model: root.portListModel
                textRole: "portName"
                enabled: !root.isSerialConnected
                
                displayText: {
                    if (root.portListModel.length === 0) {
                        return "未找到串口"
                    } else if (currentIndex < 0) {
                        return "请选择串口"
                    } else {
                        return root.portListModel[currentIndex].portName + " - " + root.portListModel[currentIndex].description
                    }
                }
                
                delegate: ItemDelegate {
                    width: 250
                    text: modelData.portName + " - " + modelData.description
                    highlighted: portComboBox.highlightedIndex === index
                }
                
                popup: Popup {
                    width: 250
                    implicitHeight: contentItem.implicitHeight
                    padding: 1
                    
                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        width: 250
                        model: portComboBox.popup.visible ? portComboBox.delegateModel : null
                        currentIndex: portComboBox.highlightedIndex
                        ScrollIndicator.vertical: ScrollIndicator { }
                    }
                }
            }
        }

        // 手动添加串口区域
        RowLayout {
            spacing: 10
            Layout.alignment: Qt.AlignHCenter

            Text {
                text: "或手动输入："
                font.pixelSize: 14
                color: "#2c3e50"
            }

            TextField {
                id: manualPortInput
                width: 350
                placeholderText: "例如: /dev/tty.usbserial-0001 或 /dev/ttys001"
                enabled: !root.isSerialConnected
                font.pixelSize: 13
                
                onAccepted: {
                    if (text.trim() !== "") {
                        backend.addManualPort(text.trim())
                        text = ""  // 清空输入框
                    }
                }
            }

            Button {
                text: "添加"
                enabled: !root.isSerialConnected && manualPortInput.text.trim() !== ""
                onClicked: {
                    if (manualPortInput.text.trim() !== "") {
                        backend.addManualPort(manualPortInput.text.trim())
                        manualPortInput.text = ""  // 清空输入框
                    }
                }
            }
        }

        // 连接/断开按钮
        RowLayout {
            spacing: 10
            Layout.alignment: Qt.AlignHCenter

            Button {
                text: "连接串口"
                enabled: !root.isSerialConnected && portComboBox.currentIndex >= 0
                onClicked: {
                    var selectedPort = root.portListModel[portComboBox.currentIndex]
                    backend.connectSerial(selectedPort.portName, root.baudRate)
                }
            }

            Button {
                text: "断开串口"
                enabled: root.isSerialConnected
                onClicked: {
                    backend.disconnectSerial()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            color: "white"
            radius: 8
            border.color: "#bdc3c7"
            border.width: 1
            implicitHeight: 200

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Text {
                    text: "串口统计"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#2c3e50"
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 32
                    rowSpacing: 8

                    Text {
                        text: "发送总帧数: " + root.txFrameCountTotal
                        font.pixelSize: 13
                        color: "#2c3e50"
                    }

                    Text {
                        text: "接收总帧数: " + root.rxFrameCountTotal
                        font.pixelSize: 13
                        color: "#2c3e50"
                    }

                    Text {
                        text: "发送总字节: " + root.txBytesTotal
                        font.pixelSize: 13
                        color: "#2c3e50"
                    }

                    Text {
                        text: "接收总字节: " + root.rxBytesTotal
                        font.pixelSize: 13
                        color: "#2c3e50"
                    }

                    Text {
                        text: "发送速率: " + root.txBytesPerSec + " B/s"
                        font.pixelSize: 13
                        color: "#2c3e50"
                    }

                    Text {
                        text: "接收速率: " + root.rxBytesPerSec + " B/s"
                        font.pixelSize: 13
                        color: "#2c3e50"
                    }

                    Text {
                        text: "CRC错误数: " + root.rxCrcErrorCount
                        font.pixelSize: 13
                        color: root.rxCrcErrorCount > 0 ? "#e67e22" : "#2c3e50"
                    }

                    Text {
                        text: "无效帧数: " + root.rxInvalidFrameCount
                        font.pixelSize: 13
                        color: root.rxInvalidFrameCount > 0 ? "#e74c3c" : "#2c3e50"
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }

    // 监听串口列表变化
    Connections {
        target: backend
        function onPortsListChanged(portsList) {
            root.portListModel = portsList
            // 如果有多个串口，不自动选择，让用户手动选择
            if (portsList.length > 0) {
                portComboBox.currentIndex = -1  // 不自动选择，显示"请选择串口"
            }
        }
    }
    
    // 初始化时获取串口列表
    Component.onCompleted: {
        if (backend) {
            root.portListModel = backend.portsList
            if (backend.portsList.length > 0) {
                portComboBox.currentIndex = -1  // 不自动选择
            }
        }
    }
}
