import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    width: 900
    height: 750
    minimumWidth: 700
    minimumHeight: 600
    visible: true
    title: "serial03 - 基础收发数据"
    
    property bool isConnected: false
    property var portListModel: []
    property bool showHexFormat: false
    
    function getTimestamp() {
        return Qt.formatDateTime(new Date(), "hh:mm:ss.zzz")
    }
    
    function addLog(textArea, prefix, asciiData, hexData) {
        var data = showHexFormat ? hexData : asciiData
        textArea.text += "[" + getTimestamp() + "] " + prefix + data + "\n"
        textArea.cursorPosition = textArea.length
    }
    
    Component.onCompleted: backend.scanPorts()
    onClosing: if (isConnected) backend.closePort()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15
        
        Text {
            text: "串口收发数据测试"
            font { pixelSize: 22; bold: true }
            Layout.alignment: Qt.AlignHCenter
        }
        
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            spacing: 15
            
            GroupBox {
                title: "串口配置"
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                GridLayout {
                    anchors.fill: parent
                    columns: 2
                    rowSpacing: 10
                    columnSpacing: 10
                    
                    Text { text: "选择串口："; font.pixelSize: 13 }
                    ComboBox {
                        id: portComboBox
                        Layout.fillWidth: true
                        model: portListModel
                        textRole: "portName"
                        displayText: currentIndex >= 0 ? portListModel[currentIndex].portName + " - " + portListModel[currentIndex].description : "未找到串口"
                        enabled: !isConnected
                    }
                    
                    Text { text: "波特率："; font.pixelSize: 13 }
                    ComboBox {
                        id: baudRateComboBox
                        Layout.fillWidth: true
                        model: ["9600", "19200", "38400", "57600", "115200", "256000", "460800"]
                        enabled: !isConnected
                    }
                }
            }
            
            GroupBox {
                title: "连接控制"
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    
                    Row {
                        spacing: 10
                        Text { text: "连接状态："; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle {
                            id: statusIndicator
                            width: 18; height: 18; radius: 9
                            color: isConnected ? "#4CAF50" : "#9E9E9E"
                            border { color: isConnected ? "#2E7D32" : "#757575"; width: 2 }
                            anchors.verticalCenter: parent.verticalCenter
                            
                            SequentialAnimation {
                                running: isConnected
                                loops: Animation.Infinite
                                PropertyAnimation { target: statusIndicator; property: "opacity"; from: 1.0; to: 0.3; duration: 800 }
                                PropertyAnimation { target: statusIndicator; property: "opacity"; from: 0.3; to: 1.0; duration: 800 }
                            }
                        }
                        Text {
                            id: statusText
                            text: "未连接"
                            font { pixelSize: 13; bold: true }
                            color: isConnected ? "#4CAF50" : "#757575"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    
                    Row {
                        spacing: 10
                        Button {
                            text: "🔌 连接"
                            font.pixelSize: 13
                            enabled: !isConnected && portComboBox.currentIndex >= 0
                            width: 100
                            onClicked: backend.openPort(portListModel[portComboBox.currentIndex].portName, parseInt(baudRateComboBox.currentText))
                        }
                        Button {
                            text: "🔓 断开"
                            font.pixelSize: 13
                            enabled: isConnected
                            width: 100
                            onClicked: backend.closePort()
                        }
                    }
                }
            }
        }
        
        GroupBox {
            title: "数据发送"
            Layout.fillWidth: true
            
            RowLayout {
                anchors.fill: parent
                spacing: 10
                
                TextField {
                    id: sendTextField
                    Layout.fillWidth: true
                    placeholderText: sendFormatSwitch.checked ? "输入HEX数据 (如: 01 02 03)" : "输入要发送的文本"
                    font.pixelSize: 13
                    enabled: isConnected
                    Keys.onReturnPressed: sendButton.clicked()
                }
                
                Button {
                    id: sendButton
                    text: "📤 发送"
                    font.pixelSize: 13
                    enabled: isConnected && sendTextField.text.length > 0
                    Layout.preferredWidth: 100
                    onClicked: sendFormatSwitch.checked ? backend.sendHexData(sendTextField.text) : backend.sendData(sendTextField.text)
                }
            }
        }
        
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 300
            spacing: 15
            
            GroupBox {
                title: "发送历史"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 0
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 5
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOn
                        TextArea {
                            id: sendTextArea
                            readOnly: true
                            wrapMode: TextArea.Wrap
                            font { pixelSize: 11; family: "Consolas" }
                            text: "等待发送数据...\n"
                        }
                    }
                    Button {
                        text: "清空"
                        font.pixelSize: 11
                        Layout.alignment: Qt.AlignRight
                        Layout.preferredHeight: 25
                        onClicked: sendTextArea.text = ""
                    }
                }
            }
            
            GroupBox {
                title: "接收历史"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 0
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 5
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOn
                        TextArea {
                            id: receiveTextArea
                            readOnly: true
                            wrapMode: TextArea.Wrap
                            font { pixelSize: 11; family: "Consolas" }
                            text: "等待接收数据...\n"
                        }
                    }
                    Button {
                        text: "清空"
                        font.pixelSize: 11
                        Layout.alignment: Qt.AlignRight
                        Layout.preferredHeight: 25
                        onClicked: receiveTextArea.text = ""
                    }
                }
            }
        }
        
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            spacing: 15
            
            GroupBox {
                title: "设置"
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                GridLayout {
                    anchors.fill: parent
                    columns: 4
                    columnSpacing: 15
                    rowSpacing: 5
                    
                    Text { text: "发送格式："; font.pixelSize: 12; Layout.alignment: Qt.AlignVCenter }
                    Switch {
                        id: sendFormatSwitch
                        text: checked ? "HEX" : "ASCII"
                        font.pixelSize: 11
                        Layout.alignment: Qt.AlignVCenter
                    }
                    
                    Text { text: "显示格式："; font.pixelSize: 12; Layout.alignment: Qt.AlignVCenter }
                    Switch {
                        id: formatSwitch
                        text: showHexFormat ? "HEX" : "ASCII"
                        font.pixelSize: 11
                        checked: showHexFormat
                        Layout.alignment: Qt.AlignVCenter
                        onCheckedChanged: showHexFormat = checked
                    }
                }
            }
            
            GroupBox {
                title: "系统日志"
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 5
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AlwaysOn
                    
                    TextArea {
                        id: infoTextArea
                        readOnly: true
                        wrapMode: TextArea.Wrap
                        font { pixelSize: 10; family: "Consolas" }
                        text: "程序启动中，正在扫描串口...\n"
                    }
                }
            }
        }
    }
    
    Connections {
        target: backend
        
        function onPortsListChanged(portsList) {
            portListModel = portsList
            portComboBox.currentIndex = portsList.length > 0 ? 0 : -1
            infoTextArea.text += "[" + getTimestamp() + "] " + (portsList.length > 0 ? "扫描完成，找到 " + portsList.length + " 个串口" : "未找到可用的COM口") + "\n"
            infoTextArea.cursorPosition = infoTextArea.length
        }
        
        function onConnectionStatusChanged(connected, message) {
            isConnected = connected
            statusText.text = connected ? "已连接" : "未连接"
            infoTextArea.text += "[" + getTimestamp() + "] " + message + "\n"
            infoTextArea.cursorPosition = infoTextArea.length
            if (connected) {
                sendTextArea.text = ""
                receiveTextArea.text = ""
            }
        }
        
        function onErrorOccurred(errorMsg) {
            infoTextArea.text += "[" + getTimestamp() + "] ❌ 错误: " + errorMsg + "\n"
            infoTextArea.cursorPosition = infoTextArea.length
        }
        
        function onDataReceived(asciiData, hexData) {
            addLog(receiveTextArea, "<- ", asciiData, hexData)
        }
        
        function onDataSent(asciiData, hexData) {
            addLog(sendTextArea, "-> ", asciiData, hexData)
        }
    }
}
