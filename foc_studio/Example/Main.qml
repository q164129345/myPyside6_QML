// 导入QML基础模块 - 提供基本的QML类型如Item、Rectangle等
import QtQuick
// 导入控件模块 - 提供Button、TextField、ComboBox等UI控件
import QtQuick.Controls
// 导入布局模块 - 提供RowLayout、ColumnLayout等布局管理器
import QtQuick.Layouts

// Window - QML应用程序的主窗口
ApplicationWindow {
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

    // 主布局 - 水平布局
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // 左侧按钮栏
        Rectangle {
            Layout.preferredWidth: 60
            Layout.fillHeight: true
            color: "#2c3e50"  // 深蓝灰色背景

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 5

                // SYS 按钮
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: currentPage === "SYS" ? "#3498db" : "#34495e"
                    radius: 5

                    Column {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: "SYS"
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            currentPage = "SYS"
                        }
                    }
                }

                // CAN 按钮
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: currentPage === "CAN" ? "#3498db" : "#34495e"
                    radius: 5

                    Column {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: "CAN"
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            currentPage = "CAN"
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
                currentIndex: currentPage === "SYS" ? 0 : 1

                // SYS 页面
                Rectangle {
                    color: "#ecf0f1"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "SYS 系统功能页面"
                        font.pixelSize: 24
                        color: "#2c3e50"
                    }
                }

                // CAN 页面
                Rectangle {
                    color: "#ecf0f1"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "CAN 通讯功能页面"
                        font.pixelSize: 24
                        color: "#2c3e50"
                    }
                }
            }
        }
    }

}  // Window 结束
