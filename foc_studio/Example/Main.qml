// 导入QML基础模块 - 提供基本的QML类型如Item、Rectangle等
import QtQuick
// 导入控件模块 - 提供Button、TextField、ComboBox等UI控件
import QtQuick.Controls
// 导入布局模块 - 提供RowLayout、ColumnLayout等布局管理器
import QtQuick.Layouts

// Window - QML应用程序的主窗口
Window {
    // 窗口初始尺寸
    width: 900
    height: 750
    // 窗口最小尺寸限制
    minimumWidth: 700
    minimumHeight: 600
    // 窗口可见性
    visible: true
    // 窗口标题
    title: "serial03 - 基础收发数据"
    
    // === 自定义属性 ===
    // property关键字用于声明自定义属性，可以在整个QML文件中访问
    
    // 串口连接状态标志
    property bool isConnected: false
    // 串口列表数据模型（使用var类型存储JavaScript数组）
    property var portListModel: []
    // 显示格式开关（false=ASCII, true=HEX）
    property bool showHexFormat: false
    
    // === 自定义函数 ===
    
    /**
     * 获取当前时间戳
     * @return 格式化的时间字符串 "时:分:秒.毫秒"
     * Qt.formatDateTime() - Qt提供的日期时间格式化函数
     */
    function getTimestamp() {
        return Qt.formatDateTime(new Date(), "hh:mm:ss.zzz")
    }
    
    /**
     * 添加日志到文本区域
     * @param textArea - 目标TextArea控件
     * @param prefix - 前缀标记（如 "-> " 表示发送，"<- " 表示接收）
     * @param asciiData - ASCII格式的数据
     * @param hexData - HEX格式的数据
     * 
     * 三元运算符: condition ? value_if_true : value_if_false
     * 字符串拼接使用 + 操作符
     */
    function addLog(textArea, prefix, asciiData, hexData) {
        var data = showHexFormat ? hexData : asciiData  // 根据格式开关选择显示格式
        textArea.text += "[" + getTimestamp() + "] " + prefix + data + "\n"
        textArea.cursorPosition = textArea.length  // 滚动到末尾
    }
    
    // === 生命周期信号处理 ===
    // Component.onCompleted - 组件加载完成时触发
    // 启动时自动扫描可用串口
    Component.onCompleted: backend.scanPorts()
    
    // onClosing - 窗口关闭时触发
    // 如果串口已连接，先关闭串口再退出
    onClosing: if (isConnected) backend.closePort()

    // === 主界面布局 === 
    // ColumnLayout - 垂直列布局，子元素从上到下排列
    ColumnLayout {
        // anchors.fill - 填充满父元素（Window）
        anchors.fill: parent
        // 内边距 - 距离窗口边缘15像素
        anchors.margins: 15
        // 子元素之间的间距
        spacing: 15
        
        // 标题文本
        Text {
            text: "串口收发数据测试，一个简单的串口助手"
            // font对象：使用花括号{}组合多个属性
            font { pixelSize: 22; bold: true }
            // Layout.alignment - 在布局中的对齐方式（水平居中）
            Layout.alignment: Qt.AlignHCenter
        }
        
        // === 第一行：串口配置和连接控制 ===
        // RowLayout - 水平行布局，子元素从左到右排列
        RowLayout {
            Layout.fillWidth: true        // 填满父布局的宽度
            Layout.preferredHeight: 120   // 首选高度120像素
            spacing: 15
            
            // GroupBox - 分组框，用于组织相关控件
            GroupBox {
                title: "串口配置"
                Layout.fillWidth: true    // 在RowLayout中平分宽度
                Layout.fillHeight: true
                
                // GridLayout - 网格布局，适合表单式界面
                GridLayout {
                    anchors.fill: parent
                    columns: 2            // 2列布局（标签列 + 控件列）
                    rowSpacing: 10        // 行间距
                    columnSpacing: 10     // 列间距
                    
                    // 第1行：串口选择
                    Text { text: "选择串口："; font.pixelSize: 13 }
                    
                    // ComboBox - 下拉选择框
                    ComboBox {
                        id: portComboBox             // id用于在QML中引用该控件
                        Layout.fillWidth: true
                        model: portListModel         // 数据模型绑定
                        textRole: "portName"         // 指定显示哪个字段
                        // displayText - 自定义显示文本（显示端口名和描述）
                        displayText: currentIndex >= 0 ? portListModel[currentIndex].portName + " - " + portListModel[currentIndex].description : "未找到串口"
                        enabled: !isConnected        // 连接时禁用（!表示取反）
                    }
                    
                    // 第2行：波特率选择
                    Text { text: "波特率："; font.pixelSize: 13 }
                    ComboBox {
                        id: baudRateComboBox
                        Layout.fillWidth: true
                        // model可以直接使用JavaScript数组
                        model: ["9600", "19200", "38400", "57600", "115200", "256000", "460800"]
                        enabled: !isConnected
                    }
                }
            }
            
            // 连接控制分组
            GroupBox {
                title: "连接控制"
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    
                    // 连接状态显示行
                    // Row - 简单的水平布局（不支持Layout属性）
                    Row {
                        spacing: 10
                        Text { text: "连接状态："; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                        
                        // Rectangle - 矩形，用作状态指示灯
                        Rectangle {
                            id: statusIndicator
                            width: 18; height: 18
                            radius: 9  // radius设为宽度的一半，形成圆形
                            // 根据连接状态改变颜色（绿色=连接，灰色=未连接）
                            color: isConnected ? "#4CAF50" : "#9E9E9E"
                            // border对象：边框配置
                            border { color: isConnected ? "#2E7D32" : "#757575"; width: 2 }
                            anchors.verticalCenter: parent.verticalCenter
                            
                            // SequentialAnimation - 顺序动画
                            SequentialAnimation {
                                running: isConnected      // 仅在连接时运行动画
                                loops: Animation.Infinite // 无限循环
                                // PropertyAnimation - 属性动画（透明度淡入淡出效果）
                                PropertyAnimation { target: statusIndicator; property: "opacity"; from: 1.0; to: 0.3; duration: 800 }
                                PropertyAnimation { target: statusIndicator; property: "opacity"; from: 0.3; to: 1.0; duration: 800 }
                            }
                        }
                        
                        // 状态文本
                        Text {
                            id: statusText
                            text: "未连接"
                            font { pixelSize: 13; bold: true }
                            // 动态颜色绑定
                            color: isConnected ? "#4CAF50" : "#757575"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    
                    // 控制按钮行
                    Row {
                        spacing: 10
                        
                        // Button - 按钮控件
                        Button {
                            text: "🔌 连接"
                            font.pixelSize: 13
                            // 逻辑与运算：&& 两个条件都满足才启用
                            enabled: !isConnected && portComboBox.currentIndex >= 0
                            width: 100
                            // onClicked - 点击事件处理
                            // 调用Python后端的openPort方法，传递串口名和波特率
                            onClicked: backend.openPort(portListModel[portComboBox.currentIndex].portName, parseInt(baudRateComboBox.currentText))
                        }
                        Button {
                            text: "🔓 断开"
                            font.pixelSize: 13
                            enabled: isConnected
                            width: 100
                            // 调用Python后端的closePort方法
                            onClicked: backend.closePort()
                        }
                    }
                }
            }
        }
        
        // === 第二行：数据发送区域 ===
        GroupBox {
            title: "数据发送"
            Layout.fillWidth: true
            
            RowLayout {
                anchors.fill: parent
                spacing: 10
                
                // TextField - 单行文本输入框
                TextField {
                    id: sendTextField
                    Layout.fillWidth: true
                    // placeholderText - 占位符文本（提示文字）
                    // 根据发送格式开关显示不同的提示
                    placeholderText: sendFormatSwitch.checked ? "输入HEX数据 (如: 01 02 03)" : "输入要发送的文本"
                    font.pixelSize: 13
                    enabled: isConnected
                    // Keys.onReturnPressed - 回车键事件
                    // clicked()方法模拟点击发送按钮
                    Keys.onReturnPressed: sendButton.clicked()
                }
                
                Button {
                    id: sendButton
                    text: "📤 发送"
                    font.pixelSize: 13
                    // 连接状态且输入非空时才启用
                    enabled: isConnected && sendTextField.text.length > 0
                    Layout.preferredWidth: 100
                    // 根据格式开关调用不同的发送方法
                    onClicked: sendFormatSwitch.checked ? backend.sendHexData(sendTextField.text) : backend.sendData(sendTextField.text)
                }
            }
        }
        
        // === 第三行：收发数据历史显示区域 ===
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 300
            spacing: 15
            
            // 发送历史分组
            GroupBox {
                title: "发送历史"
                Layout.fillWidth: true
                Layout.fillHeight: true
                // Layout.preferredWidth: 0 配合fillWidth，实现平分宽度
                Layout.preferredWidth: 0
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 5
                    
                    // ScrollView - 可滚动视图容器
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true  // 裁剪超出边界的内容
                        // 滚动条策略
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff  // 隐藏水平滚动条
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOn     // 始终显示垂直滚动条
                        
                        // TextArea - 多行文本区域
                        TextArea {
                            id: sendTextArea
                            readOnly: true           // 只读
                            wrapMode: TextArea.Wrap  // 自动换行
                            // font.family - 使用等宽字体便于查看数据
                            font { pixelSize: 11; family: "Consolas" }
                            text: "等待发送数据...\n"
                        }
                    }
                    
                    // 清空按钮
                    Button {
                        text: "清空"
                        font.pixelSize: 11
                        Layout.alignment: Qt.AlignRight  // 右对齐
                        Layout.preferredHeight: 25
                        // 清空文本区域内容
                        onClicked: sendTextArea.text = ""
                    }
                }
            }
            
            // 接收历史分组（结构与发送历史相同）
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
        
        // === 第四行：设置和系统日志 ===
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            spacing: 15
            
            // 设置分组
            GroupBox {
                title: "设置"
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                GridLayout {
                    anchors.fill: parent
                    columns: 4  // 4列：标签1 + 开关1 + 标签2 + 开关2
                    columnSpacing: 15
                    rowSpacing: 5
                    
                    Text { text: "发送格式："; font.pixelSize: 12; Layout.alignment: Qt.AlignVCenter }
                    // Switch - 开关控件
                    Switch {
                        id: sendFormatSwitch
                        // 动态显示当前状态
                        text: checked ? "HEX" : "ASCII"
                        font.pixelSize: 11
                        Layout.alignment: Qt.AlignVCenter
                        // 当发送格式改变时，同步更新显示格式
                        onCheckedChanged: showHexFormat = checked
                    }
                    
                    Text { text: "显示格式："; font.pixelSize: 12; Layout.alignment: Qt.AlignVCenter }
                    Switch {
                        id: formatSwitch
                        text: showHexFormat ? "HEX" : "ASCII"
                        font.pixelSize: 11
                        // 双向绑定：初始值来自showHexFormat
                        checked: showHexFormat
                        Layout.alignment: Qt.AlignVCenter
                        // onCheckedChanged - checked属性改变时触发
                        // 更新全局showHexFormat属性
                        onCheckedChanged: showHexFormat = checked
                    }
                }
            }
            
            // 系统日志分组
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
                    
                    // 系统信息日志区域
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
    }  // ColumnLayout 结束
    
    // === Python后端信号连接 ===
    /**
     * Connections - 连接对象，用于接收Python后端发送的信号
     * target - 指定信号源对象（backend是Python中注册的QML对象）
     * 
     * Python信号命名规则：
     * - Python中定义 someSignal = Signal()
     * - QML中处理函数命名为 onSomeSignal（on + 首字母大写的信号名）
     */
    Connections {
        target: backend  // 绑定到Python的backend对象
        
        /**
         * 串口列表改变信号处理
         * @param portsList - Python传来的串口列表数组
         * 
         * 对应Python信号：portsListChanged.emit(ports_list)
         */
        function onPortsListChanged(portsList) {
            portListModel = portsList  // 更新串口列表模型
            // 自动选择第一个串口，如果没有串口则设为-1
            portComboBox.currentIndex = portsList.length > 0 ? 0 : -1
            // 添加日志
            infoTextArea.text += "[" + getTimestamp() + "] " + (portsList.length > 0 ? "扫描完成，找到 " + portsList.length + " 个串口" : "未找到可用的COM口") + "\n"
            infoTextArea.cursorPosition = infoTextArea.length
        }
        
        /**
         * 连接状态改变信号处理
         * @param connected - 连接状态（true/false）
         * @param message - 状态消息
         * 
         * 对应Python信号：connectionStatusChanged.emit(status, msg)
         */
        function onConnectionStatusChanged(connected, message) {
            isConnected = connected  // 更新连接状态
            statusText.text = connected ? "已连接" : "未连接"
            infoTextArea.text += "[" + getTimestamp() + "] " + message + "\n"
            infoTextArea.cursorPosition = infoTextArea.length
            // 连接成功时清空收发历史
            if (connected) {
                sendTextArea.text = ""
                receiveTextArea.text = ""
            }
        }
        
        /**
         * 错误发生信号处理
         * @param errorMsg - 错误消息
         * 
         * 对应Python信号：errorOccurred.emit(error_msg)
         */
        function onErrorOccurred(errorMsg) {
            infoTextArea.text += "[" + getTimestamp() + "] ❌ 错误: " + errorMsg + "\n"
            infoTextArea.cursorPosition = infoTextArea.length
        }
        
        /**
         * 数据接收信号处理
         * @param asciiData - ASCII格式数据
         * @param hexData - HEX格式数据
         * 
         * 对应Python信号：dataReceived.emit(ascii_data, hex_data)
         */
        function onDataReceived(asciiData, hexData) {
            addLog(receiveTextArea, "<- ", asciiData, hexData)
        }
        
        /**
         * 数据发送信号处理
         * @param asciiData - ASCII格式数据
         * @param hexData - HEX格式数据
         * 
         * 对应Python信号：dataSent.emit(ascii_data, hex_data)
         */
        function onDataSent(asciiData, hexData) {
            addLog(sendTextArea, "-> ", asciiData, hexData)
        }
    }
}  // Window 结束
