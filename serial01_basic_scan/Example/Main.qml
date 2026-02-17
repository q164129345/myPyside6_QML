// 导入QtQuick模块，提供基本的QML元素
import QtQuick
// 导入QtQuick.Controls模块，提供UI控件
import QtQuick.Controls
// 导入QtQuick.Layouts模块，提供布局管理
import QtQuick.Layouts

// qmllint disable unqualified

// 定义主窗口
Window {
    width: 700
    height: 500
    visible: true
    title: "serial01 - 串口扫描与基本信息"
    
    // 主布局容器
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15
        
        // ===== 标题区域 =====
        Text {
            text: "串口扫描工具"
            font.pixelSize: 24
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }
        
        // ===== 操作按钮区域 =====
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 15
            
            Button {
                text: "🔍 扫描串口"
                font.pixelSize: 14
                onClicked: {
                    statusText.text = "正在扫描..."
                    statusText.color = "#2196F3"  // 蓝色
                    backend.scanPorts()
                }
            }
            
            Button {
                text: "🗑️ 清空列表"
                font.pixelSize: 14
                onClicked: {
                    portListModel.clear()
                    statusText.text = "列表已清空"
                    statusText.color = "#9E9E9E"  // 灰色
                }
            }
        }
        
        // ===== 状态信息 =====
        Text {
            id: statusText
            text: "点击 '扫描串口' 开始"
            font.pixelSize: 14
            color: "#666666"
            Layout.alignment: Qt.AlignHCenter
        }
        
        // ===== 分隔线 =====
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#E0E0E0"
        }
        
        // ===== 串口列表标题 =====
        Text {
            text: "检测到的串口设备："
            font.pixelSize: 16
            font.bold: true
        }
        
        // ===== 串口列表视图 =====
        ListView {
            id: portListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 10
            
            // 列表模型
            model: ListModel {
                id: portListModel
            }
            
            // 列表项委托
            delegate: Rectangle {
                width: portListView.width
                height: 80
                border.color: "#BDBDBD"
                border.width: 1
                radius: 8
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 15
                    
                    // 图标
                    Text {
                        text: "📌"
                        font.pixelSize: 20
                    }
                    
                    // 串口信息
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        
                        // 端口名称
                        Text {
                            text: model.portName
                            font.pixelSize: 18
                            font.bold: true
                            color: "#1976D2"
                        }
                        
                        // 描述信息
                        Text {
                            text: model.description || "无描述"
                            font.pixelSize: 13
                            color: "#757575"
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                    }
                    
                    // 可用标签
                    Rectangle {
                        width: 60
                        height: 25
                        color: "#4CAF50"
                        radius: 12
                        
                        Text {
                            anchors.centerIn: parent
                            text: "可用"
                            color: "white"
                            font.pixelSize: 12
                        }
                    }
                }
            }
            
            // 空状态提示
            Text {
                visible: portListModel.count === 0
                anchors.centerIn: parent
                text: "暂无串口设备\n\n💡 请连接串口设备后点击 '扫描串口'"
                font.pixelSize: 14
                color: "#9E9E9E"
                horizontalAlignment: Text.AlignHCenter
            }
            
            // 滚动条
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
        }

    }
    
    // ===== 信号连接 =====
    Connections {
        target: backend
        
        // 当串口列表更新时
        function onPortsListChanged(portsList) {
            // 清空现有列表
            portListModel.clear()
            
            // 添加新的串口信息
            for (var i = 0; i < portsList.length; i++) {
                portListModel.append(portsList[i])
            }
        }
        
        // 当状态更新时
        function onStatusChanged(status) {
            statusText.text = status
            
            // 根据状态设置颜色
            if (status.includes("找到")) {
                statusText.color = "#4CAF50"  // 绿色 - 成功
            } else if (status.includes("未检测到")) {
                statusText.color = "#FF9800"  // 橙色 - 警告
            }
        }
    }
}
