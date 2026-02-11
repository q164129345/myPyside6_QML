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

    // 接收串口连接状态
    property bool isSerialConnected: false
    property var portListModel: []  // 存储串口列表
    
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20

        Text {
            text: "SYS 系统功能页面"
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

        // 连接/断开按钮
        RowLayout {
            spacing: 10
            Layout.alignment: Qt.AlignHCenter

            Button {
                text: "连接串口"
                enabled: !root.isSerialConnected && portComboBox.currentIndex >= 0
                onClicked: {
                    var selectedPort = root.portListModel[portComboBox.currentIndex]
                    serialBackend.openPort(selectedPort.portName, root.baudRate)
                }
            }

            Button {
                text: "断开串口"
                enabled: root.isSerialConnected
                onClicked: {
                    serialBackend.closePort()
                }
            }
        }
    }

    // 监听串口列表变化
    Connections {
        target: serialBackend
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
        root.portListModel = serialBackend.portsList
        if (serialBackend.portsList.length > 0) {
            portComboBox.currentIndex = -1  // 不自动选择
        }
    }
}
