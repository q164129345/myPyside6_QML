// 导入QtQuick模块，提供基本的QML元素
import QtQuick
// 导入QtQuick.Controls模块，提供UI控件
import QtQuick.Controls
// 导入QtQuick.Layouts模块，提供布局管理
import QtQuick.Layouts

// 定义主窗口
Window {
    width: 500
    height: 450
    visible: true
    title: "serial02 - 串口打开与关闭"
    
    // 窗口加载完成后自动扫描串口
    Component.onCompleted: {
        backend.scanPorts()
    }
    
    // 主布局容器
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20
        
        // ===== 标题区域 =====
        Text {
            text: "串口连接管理"
            font.pixelSize: 24
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }
        
        // ===== 串口选择区域 =====
        GroupBox {
            title: "串口配置"
            Layout.fillWidth: true
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 15
                
                // 串口选择行
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    
                    Text {
                        text: "选择串口："
                        font.pixelSize: 14
                        Layout.preferredWidth: 80
                    }
                    
                    ComboBox {
                        id: portComboBox
                        Layout.fillWidth: true
                        model: portListModel
                        textRole: "portName"
                        displayText: currentIndex >= 0 ? portListModel[currentIndex].portName + " - " + portListModel[currentIndex].description : "未找到串口"
                        enabled: !isConnected
                    }
                }
                
                // 波特率选择行
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    
                    Text {
                        text: "波特率："
                        font.pixelSize: 14
                        Layout.preferredWidth: 80
                    }
                    
                    ComboBox {
                        id: baudRateComboBox
                        Layout.fillWidth: true
                        model: ["9600", "19200", "38400", "57600", "115200"]
                        currentIndex: 0
                        enabled: !isConnected
                    }
                }
            }
        }
        
        // ===== 连接控制区域 =====
        GroupBox {
            title: "连接控制"
            Layout.fillWidth: true
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 15
                
                // 连接状态指示器
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 15
                    
                    Text {
                        text: "连接状态："
                        font.pixelSize: 14
                    }
                    
                    // 状态指示灯
                    Rectangle {
                        id: statusIndicator
                        width: 20
                        height: 20
                        radius: 10
                        color: isConnected ? "#4CAF50" : "#9E9E9E"  // 绿色：已连接，灰色：未连接
                        border.color: isConnected ? "#2E7D32" : "#757575"
                        border.width: 2
                        
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
                    
                    // 状态文本
                    Text {
                        id: statusText
                        text: "未连接"
                        font.pixelSize: 14
                        font.bold: true
                        color: isConnected ? "#4CAF50" : "#757575"
                    }
                }
                
                // 连接/断开按钮
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 15
                    
                    Button {
                        text: "🔌 连接"
                        font.pixelSize: 14
                        enabled: !isConnected && portComboBox.currentIndex >= 0
                        Layout.preferredWidth: 120
                        
                        onClicked: {
                            var selectedPort = portListModel[portComboBox.currentIndex]
                            var baudRate = parseInt(baudRateComboBox.currentText)
                            console.log("Connect to:", selectedPort.portName, "Baud:", baudRate)
                            backend.openPort(selectedPort.portName, baudRate)
                        }
                    }
                    
                    Button {
                        text: "🔓 断开连接"
                        font.pixelSize: 14
                        enabled: isConnected
                        Layout.preferredWidth: 120
                        
                        onClicked: {
                            backend.closePort()
                        }
                    }
                }
            }
        }
        
        // ===== 信息显示区域 =====
        GroupBox {
            title: "连接信息"
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            ScrollView {
                anchors.fill: parent
                clip: true
                
                TextArea {
                    id: infoTextArea
                    readOnly: true
                    wrapMode: TextArea.Wrap
                    font.pixelSize: 12
                    font.family: "Consolas"
                    text: "程序启动中，正在扫描串口...\n\n提示：\n1. 程序会自动扫描可用串口\n2. 选择串口和波特率\n3. 点击'连接'按钮打开串口\n4. 点击'断开连接'按钮关闭串口"
                }
            }
        }
    }
    
    // ===== 属性与函数 =====
    property bool isConnected: false
    property var portListModel: []
    
    function addInfoLog(message) {
        var timestamp = Qt.formatDateTime(new Date(), "hh:mm:ss")
        infoTextArea.text += "\n[" + timestamp + "] " + message
    }
    
    // ===== 信号连接 =====
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
        }
        
        // 当发生错误时
        function onErrorOccurred(errorMsg) {
            addInfoLog("❌ 错误: " + errorMsg)
        }
    }
    
    // 窗口关闭时断开串口
    onClosing: {
        if (isConnected) {
            backend.closePort()
        }
    }
}
