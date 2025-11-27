// 导入QML基础模块 - 提供基本的QML类型如Item、Rectangle等
import QtQuick
// 导入控件模块 - 提供Button、TextField、ComboBox等UI控件
import QtQuick.Controls
// 导入布局模块 - 提供RowLayout、ColumnLayout等布局管理器
import QtQuick.Layouts
// 导入图表模块 - 提供ChartView、LineSeries等图表组件
import QtCharts

// Window - QML应用程序的主窗口
ApplicationWindow {
    id: root
    visible: true
    width: 900
    height: 600
    title: "Real time motor variables"
    color: "#1e1e1e"

    // 数据相关属性
    property int timeWindow: 300        // X轴时间窗口（显示最近300个点）
    property int currentTime: 0         // 当前时间点
    property bool isRunning: false      // 是否正在运行
    property bool isPaused: false       // 是否暂停
    property int downsample: 500        // 降采样值

    // 模拟数据生成定时器
    Timer {
        id: dataTimer
        interval: 50  // 20Hz更新率
        running: isRunning && !isPaused
        repeat: true
        onTriggered: {
            currentTime++
            
            // 生成模拟数据 (可以替换为实际的电机数据)
            var t = currentTime * 0.05
            var target = generateTargetSignal(t)
            var velocity = target + (Math.random() - 0.5) * 10  // 添加一些噪声
            var angle = Math.sin(t * 0.5) * 10

            // 添加数据点
            if (targetCheckbox.checked) targetSeries.append(currentTime, target)
            if (velCheckbox.checked) velocitySeries.append(currentTime, velocity)
            if (angleCheckbox.checked) angleSeries.append(currentTime, angle)

            // 移除超出时间窗口的旧数据点
            removeOldPoints(targetSeries)
            removeOldPoints(velocitySeries)
            removeOldPoints(angleSeries)

            // 更新X轴范围（滚动效果）
            axisX.min = currentTime - timeWindow
            axisX.max = currentTime
        }
    }

    // 生成目标信号（模拟方波）
    function generateTargetSignal(t) {
        var period = 4.0  // 周期
        var phase = t % period
        if (phase < 1) return 0
        else if (phase < 2) return 100
        else if (phase < 3) return -100
        else return 0
    }

    // 移除旧数据点
    function removeOldPoints(series) {
        while (series.count > 0 && series.at(0).x < currentTime - timeWindow) {
            series.remove(0)
        }
    }

    // 清除所有数据
    function clearAllData() {
        targetSeries.clear()
        velocitySeries.clear()
        angleSeries.clear()
        vqSeries.clear()
        vdSeries.clear()
        cqSeries.clear()
        cdSeries.clear()
        currentTime = 0
        axisX.min = -timeWindow
        axisX.max = 0
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // 标题
        Label {
            text: "Real time motor variables:"
            color: "#ffffff"
            font.pixelSize: 14
        }

        // 图表区域
        ChartView {
            id: chartView
            Layout.fillWidth: true
            Layout.fillHeight: true
            antialiasing: true
            backgroundColor: "#000000"
            legend.visible: true
            legend.alignment: Qt.AlignTop | Qt.AlignLeft
            legend.labelColor: "#ffffff"
            legend.font.pixelSize: 10

            // X轴 - 时间
            ValueAxis {
                id: axisX
                min: -timeWindow
                max: 0
                tickCount: 7
                labelFormat: "%.0f"
                labelsColor: "#aaaaaa"
                gridLineColor: "#333333"
                lineVisible: true
            }

            // Y轴 - 数值
            ValueAxis {
                id: axisY
                min: -120
                max: 120
                tickCount: 13
                labelFormat: "%.0f"
                labelsColor: "#aaaaaa"
                gridLineColor: "#333333"
                lineVisible: true
            }

            // Target 曲线 - 红色
            LineSeries {
                id: targetSeries
                name: "Target"
                color: "#ff0000"
                width: 2
                axisX: axisX
                axisY: axisY
            }

            // Velocity 曲线 - 橙色
            LineSeries {
                id: velocitySeries
                name: "Velocity [rad/sec]"
                color: "#ffa500"
                width: 2
                axisX: axisX
                axisY: axisY
            }

            // Angle 曲线 - 绿色
            LineSeries {
                id: angleSeries
                name: "Angle [rad]"
                color: "#00ff00"
                width: 2
                axisX: axisX
                axisY: axisY
            }

            // Vq 曲线 - 蓝色
            LineSeries {
                id: vqSeries
                name: "Vq"
                color: "#00bfff"
                width: 2
                axisX: axisX
                axisY: axisY
                visible: vqCheckbox.checked
            }

            // Vd 曲线 - 紫色
            LineSeries {
                id: vdSeries
                name: "Vd"
                color: "#9400d3"
                width: 2
                axisX: axisX
                axisY: axisY
                visible: vdCheckbox.checked
            }

            // Cq 曲线 - 黄色
            LineSeries {
                id: cqSeries
                name: "Cq"
                color: "#ffff00"
                width: 2
                axisX: axisX
                axisY: axisY
                visible: cqCheckbox.checked
            }

            // Cd 曲线 - 棕色
            LineSeries {
                id: cdSeries
                name: "Cd"
                color: "#8b4513"
                width: 2
                axisX: axisX
                axisY: axisY
                visible: cdCheckbox.checked
            }
        }

        // 控制栏
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            color: "#2d2d2d"
            radius: 5

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 15

                // Stop 按钮
                Button {
                    id: stopBtn
                    text: "Stop"
                    icon.source: ""
                    Layout.preferredWidth: 80
                    onClicked: {
                        isRunning = false
                        isPaused = false
                        clearAllData()
                    }
                    background: Rectangle {
                        color: stopBtn.pressed ? "#555" : "#3d3d3d"
                        radius: 4
                        border.color: "#ff4444"
                        border.width: 1
                    }
                    contentItem: RowLayout {
                        spacing: 5
                        Rectangle {
                            width: 12
                            height: 12
                            radius: 6
                            color: "#ff4444"
                        }
                        Text {
                            text: "Stop"
                            color: "#ffffff"
                        }
                    }
                }

                // Pause 按钮
                Button {
                    id: pauseBtn
                    Layout.preferredWidth: 80
                    onClicked: {
                        if (!isRunning) {
                            isRunning = true
                            isPaused = false
                        } else {
                            isPaused = !isPaused
                        }
                    }
                    background: Rectangle {
                        color: pauseBtn.pressed ? "#555" : "#3d3d3d"
                        radius: 4
                        border.color: "#4488ff"
                        border.width: 1
                    }
                    contentItem: RowLayout {
                        spacing: 5
                        Rectangle {
                            width: 12
                            height: 12
                            color: "#4488ff"
                        }
                        Text {
                            text: isPaused ? "Resume" : (isRunning ? "Pause" : "Start")
                            color: "#ffffff"
                        }
                    }
                }

                // 分隔线
                Rectangle {
                    width: 1
                    Layout.fillHeight: true
                    color: "#555"
                }

                // 复选框组
                RowLayout {
                    spacing: 10

                    CheckBox {
                        id: targetCheckbox
                        checked: true
                        text: "Target"
                        contentItem: Text {
                            text: parent.text
                            color: "#ff0000"
                            leftPadding: parent.indicator.width + 5
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    CheckBox {
                        id: vqCheckbox
                        checked: false
                        text: "Vq"
                        contentItem: Text {
                            text: parent.text
                            color: "#00bfff"
                            leftPadding: parent.indicator.width + 5
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    CheckBox {
                        id: vdCheckbox
                        checked: false
                        text: "Vd"
                        contentItem: Text {
                            text: parent.text
                            color: "#9400d3"
                            leftPadding: parent.indicator.width + 5
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    CheckBox {
                        id: cqCheckbox
                        checked: false
                        text: "Cq"
                        contentItem: Text {
                            text: parent.text
                            color: "#ffff00"
                            leftPadding: parent.indicator.width + 5
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    CheckBox {
                        id: cdCheckbox
                        checked: false
                        text: "Cd"
                        contentItem: Text {
                            text: parent.text
                            color: "#8b4513"
                            leftPadding: parent.indicator.width + 5
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    CheckBox {
                        id: velCheckbox
                        checked: true
                        text: "Vel"
                        contentItem: Text {
                            text: parent.text
                            color: "#ffa500"
                            leftPadding: parent.indicator.width + 5
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    CheckBox {
                        id: angleCheckbox
                        checked: true
                        text: "Angle"
                        contentItem: Text {
                            text: parent.text
                            color: "#00ff00"
                            leftPadding: parent.indicator.width + 5
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                // 分隔线
                Rectangle {
                    width: 1
                    Layout.fillHeight: true
                    color: "#555"
                }

                // Downsample 输入
                RowLayout {
                    spacing: 5
                    Label {
                        text: "Downsample"
                        color: "#ffffff"
                    }
                    TextField {
                        id: downsampleField
                        Layout.preferredWidth: 60
                        text: downsample.toString()
                        color: "#ffffff"
                        background: Rectangle {
                            color: "#3d3d3d"
                            border.color: "#555"
                            radius: 3
                        }
                        onTextChanged: {
                            var val = parseInt(text)
                            if (!isNaN(val) && val > 0) {
                                downsample = val
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }
}