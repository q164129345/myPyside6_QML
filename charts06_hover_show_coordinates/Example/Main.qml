/**
 * Charts06 - 鼠标悬停显示坐标
 * 
 * 学习要点:
 * 1. LineSeries.onHovered - 鼠标悬停事件
 * 2. mapToPosition / mapToValue - 坐标转换
 * 3. 自定义 Tooltip 显示
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCharts

ApplicationWindow {
    visible: true
    width: 700
    height: 500
    title: "Charts06 - 鼠标悬停显示坐标"

    // ========== 属性 ==========
    property int currentX : 0
    property int currentY : 0
    property int maxPoints: 50
    property bool isRunning: false

    Timer {
        id: dataTimer
        interval: 100
        running: isRunning
        repeat: true
        onTriggered: {
            currentY = 50 + 40 * Math.sin(currentX * 0.1) + (Math.random() - 0.5) * 10
            dataSeries.append(currentX, currentY)
            currentX++
            
            if (dataSeries.count > maxPoints) {
                dataSeries.remove(0)
            }
            
            if (currentX > maxPoints) {
                axisX.min = currentX - maxPoints
                axisX.max = currentX
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        ChartView {
            id: chartView
            Layout.fillWidth: true
            Layout.fillHeight: true
            antialiasing: true

            ValueAxis {
                id: axisX
                min: 0
                max: maxPoints
                tickCount: 6
                titleText: "时间"
            }

            ValueAxis {
                id: axisY
                min: 0
                max: 100
                tickCount: 6
                titleText: "数值"
            }

            LineSeries {
                id: dataSeries
                name: "实时数据"
                color: "#4CAF50"
                width: 2
                axisX: axisX
                axisY: axisY

                // ========== 鼠标悬停事件 ==========
                onHovered: function(point, state) {
                    if (state) {
                        // 鼠标进入曲线区域
                        // 坐标转换(数据坐标->屏幕坐标)
                        // 1. point 是数据坐标，需要转换为屏幕坐标来放置 Tooltip
                        tooltip.x = chartView.mapToPosition(point, dataSeries).x + 10
                        //          ↑                                          ↑
                        //          转换函数                                   +10 是偏移量，避免遮挡鼠标
                        tooltip.y = chartView.mapToPosition(point, dataSeries).y - 40
                        //                                                     ↑
                        //                                                     -40 让 Tooltip 显示在点的上方
                        // 2. 设置 Tooltip 显示的文字
                        tooltipText.text = "X: " + point.x.toFixed(1) + "\nY: " + point.y.toFixed(1)
                        //                         ↑                    ↑
                        //                         保留1位小数           \n 换行
                        
                        // 3. 显示 Tooltip
                        tooltip.visible = true
                    } else {
                        // 鼠标离开曲线区域
                        tooltip.visible = false
                    }
                }
            }

            // ========== 自定义 Tooltip ==========
            Rectangle {
                id: tooltip
                visible: false
                width: 80
                height: 40
                color: "#333333"
                radius: 5
                border.color: "#4CAF50"
                border.width: 1
                z: 100

                Text {
                    id: tooltipText
                    anchors.centerIn: parent
                    color: "#ffffff"
                    font.pixelSize: 12
                }
            }
        }

        // ========== 控制按钮区域 ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            Button {
                text: isRunning ? "暂停" : "开始"
                onClicked: isRunning = !isRunning
            }

            Button {
                text: "清除"
                onClicked: {
                    isRunning = false
                    dataSeries.clear()
                    currentX = 0
                    axisX.min = 0
                    axisX.max = maxPoints
                }
            }

            Label {
                text: "数据点: " + dataSeries.count
            }

            Item { Layout.fillWidth: true }

            Label {
                text: "更新频率:"
            }

            Slider {
                id: speedSlider
                from: 50
                to: 500
                value: 100
                stepSize: 50
                Layout.preferredWidth: 150
                onValueChanged: dataTimer.interval = value
            }

            Label {
                text: speedSlider.value + "ms"
            }
        }
    }
}