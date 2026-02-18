// 导入QML基础模块 - 提供基本的QML类型如Item、Rectangle等
import QtQuick
// 导入控件模块 - 提供Button、TextField、ComboBox等UI控件
import QtQuick.Controls
// 导入布局模块 - 提供RowLayout、ColumnLayout等布局管理器
import QtQuick.Layouts

// qmllint disable unqualified

// Window - QML应用程序的主窗口
ApplicationWindow {
    id: root

    // 窗口初始尺寸
    width: 900
    height: 750
    // 窗口最小尺寸限制
    minimumWidth: 700
    minimumHeight: 600
    // 窗口可见性
    visible: true
    // 窗口标题
    title: "FOC Studio"

    // 当前选中的页面
    property string currentPage: "SYS"
        
    // 串口连接状态 - 直接绑定到后端属性（serialBackend 从 Python setContextProperty 注入）
    property bool isSerialConnected: serialBackend ? serialBackend.isConnected : false

    // 监听串口连接状态变化消息
    Connections {
        target: serialBackend
        enabled: serialBackend !== null
        function onConnectionStatusChanged(connected, message) {
            console.log("Serial status:", connected, message)
        }
    }

    // 主布局 - 水平布局
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // 左侧按钮栏
        Rectangle {
            Layout.preferredWidth: 40
            Layout.fillHeight: true
            color: "#2c3e50"  // 深蓝灰色背景

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 5

                // 串口状态指示灯
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: "transparent"

                    // 圆形指示灯
                    Rectangle {
                        id: statusIndicator
                        width: 25
                        height: 25
                        radius: 12.5
                        anchors.centerIn: parent
                        color: root.isSerialConnected ? "#2ecc71" : "#7f8c8d"  // 绿色:已连接, 灰色:未连接
                        border.color: root.isSerialConnected ? "#27ae60" : "#5a6469"
                        border.width: 2

                        // 呼吸灯动画 - 仅在连接时生效
                        SequentialAnimation on opacity {
                            running: root.isSerialConnected
                            loops: Animation.Infinite
                            
                            NumberAnimation {
                                from: 1.0
                                to: 0.3
                                duration: 1000
                                easing.type: Easing.InOutQuad
                            }
                            NumberAnimation {
                                from: 0.3
                                to: 1.0
                                duration: 1000
                                easing.type: Easing.InOutQuad
                            }
                        }

                        // 未连接时恢复完全不透明
                        opacity: root.isSerialConnected ? 1.0 : 0.5
                    }
                }

                // SYS 按钮
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: root.currentPage === "SYS" ? "#3498db" : "#34495e"
                    radius: 5

                    Column {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: "SYS"
                            color: "white"
                            font.pixelSize: 10
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentPage = "SYS"
                        }
                    }
                }

                // CAN 按钮
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: root.currentPage === "CAN" ? "#3498db" : "#34495e"
                    radius: 5

                    Column {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: "CAN"
                            color: "white"
                            font.pixelSize: 10
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentPage = "CAN"
                        }
                    }
                }

                // 占位符 - 将按钮推到顶部
                Item {
                    Layout.fillHeight: true
                }
            }
        }

        // 右侧内容区域
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#ecf0f1"  // 浅灰色背景

            // 使用 StackLayout 来切换不同的页面
            StackLayout {
                anchors.fill: parent
                currentIndex: root.currentPage === "SYS" ? 0 : 1

                // SYS 页面 - 使用独立的组件
                SYS {
                    isSerialConnected: root.isSerialConnected
                }
            }
        }
    }

}  // Window 结束
