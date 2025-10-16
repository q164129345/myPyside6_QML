// 导入QtQuick模块，提供基本的QML元素
import QtQuick
// 导入QtQuick.Controls模块，提供UI控件
import QtQuick.Controls
// 导入QtQuick.Layouts模块，提供布局管理
import QtQuick.Layouts

// 定义主窗口
Window {
    // ===== 窗口基本属性 =====
    width: 900
    height: 750
    visible: true
    title: "serial03 - 基础收发数据"
    
    // ===== 自定义属性 =====
    property bool isConnected: false
    property var portListModel: []
    property bool showHexFormat: false  // 切换显示格式（false=ASCII, true=HEX）
    
    // ===== 自定义函数 =====
    function addInfoLog(message) {
        var timestamp = Qt.formatDateTime(new Date(), "hh:mm:ss.zzz")
        infoTextArea.text += "[" + timestamp + "] " + message + "\n"
        // 自动滚动到底部
        Qt.callLater(function() {
            if (infoScrollView.ScrollBar.vertical) {
                infoScrollView.ScrollBar.vertical.position = 1.0 - infoScrollView.ScrollBar.vertical.size
            }
        })
    }
    
    function addSendLog(asciiData, hexData) {
        var timestamp = Qt.formatDateTime(new Date(), "hh:mm:ss.zzz")
        var displayData = showHexFormat ? hexData : asciiData
        sendTextArea.text += "[" + timestamp + "] 📤 " + displayData + "\n"
        // 强制滚动到底部
        Qt.callLater(function() {
            sendScrollView.ScrollBar.vertical.position = 1.0 - sendScrollView.ScrollBar.vertical.size
        })
    }
    
    function addReceiveLog(asciiData, hexData) {
        var timestamp = Qt.formatDateTime(new Date(), "hh:mm:ss.zzz")
        var displayData = showHexFormat ? hexData : asciiData
        receiveTextArea.text += "[" + timestamp + "] 📥 " + displayData + "\n"
        // 强制滚动到底部
        Qt.callLater(function() {
            receiveScrollView.ScrollBar.vertical.position = 1.0 - receiveScrollView.ScrollBar.vertical.size
        })
    }
    
    // ===== 生命周期处理 =====
    // 窗口加载完成后自动扫描串口
    Component.onCompleted: {
        backend.scanPorts()
    }
    
    // 窗口关闭时断开串口
    onClosing: {
        if (isConnected) {
            backend.closePort()
        }
    }

    // ===== UI 布局 =====
    // 主布局容器
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15
        
        // ===== 标题区域 =====
        Text {
            text: "串口收发数据测试"
            font.pixelSize: 22
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }
        
        // ===== 串口配置与连接控制区域（横向布局）=====
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            spacing: 15
            
            // 串口配置
            GroupBox {
                title: "串口配置"
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                GridLayout {
                    anchors.fill: parent
                    columns: 2
                    rowSpacing: 10
                    columnSpacing: 10
                    
                    Text {
                        text: "选择串口："
                        font.pixelSize: 13
                    }
                    
                    ComboBox {
                        id: portComboBox
                        Layout.fillWidth: true
                        model: portListModel
                        textRole: "portName"
                        displayText: currentIndex >= 0 ? portListModel[currentIndex].portName + " - " + portListModel[currentIndex].description : "未找到串口"
                        enabled: !isConnected
                    }
                    
                    Text {
                        text: "波特率："
                        font.pixelSize: 13
                    }
                    
                    ComboBox {
                        id: baudRateComboBox
                        Layout.fillWidth: true
                        model: ["9600", "19200", "38400", "57600", "115200", "256000", "460800"]
                        currentIndex: 0
                        enabled: !isConnected
                    }
                }
            }
            
            // 连接控制
            GroupBox {
                title: "连接控制"
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    
                    // 连接状态指示器
                    Row {
                        spacing: 10
                        
                        Text {
                            text: "连接状态："
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        // 状态指示灯
                        Rectangle {
                            id: statusIndicator
                            width: 18
                            height: 18
                            radius: 9
                            color: isConnected ? "#4CAF50" : "#9E9E9E"
                            border.color: isConnected ? "#2E7D32" : "#757575"
                            border.width: 2
                            anchors.verticalCenter: parent.verticalCenter
                            
                            // 闪烁动画（连接时）
                            SequentialAnimation {
                                running: isConnected
                                loops: Animation.Infinite
                                
                                PropertyAnimation {
                                    target: statusIndicator
                                    property: "opacity"
                                    from: 1.0
                                    to: 0.3
                                    duration: 800
                                }
                                PropertyAnimation {
                                    target: statusIndicator
                                    property: "opacity"
                                    from: 0.3
                                    to: 1.0
                                    duration: 800
                                }
                            }
                        }
                        
                        Text {
                            id: statusText
                            text: "未连接"
                            font.pixelSize: 13
                            font.bold: true
                            color: isConnected ? "#4CAF50" : "#757575"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    
                    // 连接/断开按钮
                    Row {
                        spacing: 10
                        
                        Button {
                            text: "🔌 连接"
                            font.pixelSize: 13
                            enabled: !isConnected && portComboBox.currentIndex >= 0
                            width: 100
                            
                            onClicked: {
                                var selectedPort = portListModel[portComboBox.currentIndex]
                                var baudRate = parseInt(baudRateComboBox.currentText)
                                backend.openPort(selectedPort.portName, baudRate)
                            }
                        }
                        
                        Button {
                            text: "🔓 断开"
                            font.pixelSize: 13
                            enabled: isConnected
                            width: 100
                            
                            onClicked: {
                                backend.closePort()
                            }
                        }
                    }
                }
            }
        }
        
        // ===== 数据发送区域 =====
        GroupBox {
            title: "数据发送"
            Layout.fillWidth: true
            
            // 发送输入框和按钮
            RowLayout {
                anchors.fill: parent
                spacing: 10
                
                TextField {
                    id: sendTextField
                    Layout.fillWidth: true
                    placeholderText: sendFormatSwitch.checked ? "输入HEX数据 (如: 01 02 03)" : "输入要发送的文本"
                    font.pixelSize: 13
                    enabled: isConnected
                    
                    // 按下回车键发送
                    Keys.onReturnPressed: {
                        sendButton.clicked()
                    }
                }
                
                Button {
                    id: sendButton
                    text: "📤 发送"
                    font.pixelSize: 13
                    enabled: isConnected && sendTextField.text.length > 0
                    Layout.preferredWidth: 100
                    
                    onClicked: {
                        if (sendFormatSwitch.checked) {
                            backend.sendHexData(sendTextField.text)
                        } else {
                            backend.sendData(sendTextField.text)
                        }
                        // 发送后保留输入框内容，方便重复发送
                        // sendTextField.text = ""  // 注释掉自动清空
                    }
                }
            }
        }
        
        // ===== 数据显示区域（发送/接收）=====
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 200
            spacing: 15
            
            // 发送历史
            GroupBox {
                title: "发送历史"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 0  // 强制平分空间
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 5
                    
                    ScrollView {
                        id: sendScrollView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOn
                        
                        TextArea {
                            id: sendTextArea
                            readOnly: true
                            wrapMode: TextArea.Wrap
                            font.pixelSize: 11
                            font.family: "Consolas"
                            text: "等待发送数据...\n"
                            width: sendScrollView.width
                        }
                    }
                    
                    Button {
                        text: "清空"
                        font.pixelSize: 11
                        Layout.alignment: Qt.AlignRight
                        Layout.preferredHeight: 25
                        onClicked: {
                            sendTextArea.text = ""
                        }
                    }
                }
            }
            
            // 接收历史
            GroupBox {
                title: "接收历史"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 0  // 强制平分空间
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 5
                    
                    ScrollView {
                        id: receiveScrollView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOn
                        
                        TextArea {
                            id: receiveTextArea
                            readOnly: true
                            wrapMode: TextArea.Wrap
                            font.pixelSize: 11
                            font.family: "Consolas"
                            text: "等待接收数据...\n"
                            width: receiveScrollView.width
                        }
                    }
                    
                    Button {
                        text: "清空"
                        font.pixelSize: 11
                        Layout.alignment: Qt.AlignRight
                        Layout.preferredHeight: 25
                        onClicked: {
                            receiveTextArea.text = ""
                        }
                    }
                }
            }
        }
        
        // ===== 控制区域 =====
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            spacing: 15
            
            // 设置区域
            GroupBox {
                title: "设置"
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                GridLayout {
                    anchors.fill: parent
                    columns: 4
                    columnSpacing: 15
                    rowSpacing: 5
                    
                    // 发送格式
                    Text {
                        text: "发送格式："
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignVCenter
                    }
                    
                    Switch {
                        id: sendFormatSwitch
                        text: checked ? "HEX" : "ASCII"
                        font.pixelSize: 11
                        checked: false  // 默认 ASCII
                        Layout.alignment: Qt.AlignVCenter
                        onCheckedChanged: {
                            addInfoLog("切换发送格式为: " + (checked ? "HEX" : "ASCII"))
                        }
                    }
                    
                    // 显示格式
                    Text {
                        text: "显示格式："
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignVCenter
                    }
                    
                    Switch {
                        id: formatSwitch
                        text: showHexFormat ? "HEX" : "ASCII"
                        font.pixelSize: 11
                        checked: showHexFormat
                        Layout.alignment: Qt.AlignVCenter
                        onCheckedChanged: {
                            showHexFormat = checked
                            addInfoLog("切换显示格式为: " + (checked ? "HEX" : "ASCII"))
                        }
                    }
                }
            }
            
            // 日志信息区域
            GroupBox {
                title: "系统日志"
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 0
                    
                    ScrollView {
                        id: infoScrollView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOn
                        
                        TextArea {
                            id: infoTextArea
                            readOnly: true
                            wrapMode: TextArea.Wrap
                            font.pixelSize: 10
                            font.family: "Consolas"
                            text: "程序启动中，正在扫描串口...\n"
                            width: infoScrollView.width
                        }
                    }
                }
            }
        }
    }
    
    // ===== 后端信号连接 =====
    Connections {
        target: backend
        
        // 当串口列表更新时
        function onPortsListChanged(portsList) {
            portListModel = portsList
            portComboBox.model = portsList
            
            if (portsList.length > 0) {
                portComboBox.currentIndex = 0
                addInfoLog("扫描完成，找到 " + portsList.length + " 个串口")
            } else {
                portComboBox.currentIndex = -1
                addInfoLog("未找到可用的COM口")
            }
        }
        
        // 当连接状态改变时
        function onConnectionStatusChanged(connected, message) {
            isConnected = connected
            statusText.text = connected ? "已连接" : "未连接"
            addInfoLog(message)
            
            if (connected) {
                sendTextArea.text = ""
                receiveTextArea.text = ""
            }
        }
        
        // 当发生错误时
        function onErrorOccurred(errorMsg) {
            addInfoLog("❌ 错误: " + errorMsg)
        }
        
        // 当接收到数据时
        function onDataReceived(asciiData, hexData) {
            addReceiveLog(asciiData, hexData)
        }
        
        // 当发送数据时
        function onDataSent(asciiData, hexData) {
            addSendLog(asciiData, hexData)
        }
    }
    
}
