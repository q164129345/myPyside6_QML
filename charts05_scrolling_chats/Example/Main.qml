/**
 * Charts05 - 实时滚动图表
 * 
 * 学习要点:
 * 1. Timer - 定时器自动添加数据
 * 2. series.remove(0) - 删除最旧的数据点
 * 3. 滑动窗口效果 - 保持固定数量的数据点
 * 4. X轴跟随滚动
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCharts

ApplicationWindow {
    visible: true
    width: 700
    height: 500
    title: "Charts05 - 实时滚动图表"

    // ========== 属性 ==========
    property int currentX: 0            // 当前X坐标
    property int currentY : 0           // 当前Y坐标
    property int maxPoints: 50          // 最多显示的数据点数量
    property bool isRunning: false      // 是否正在运行

    // ========== 定时器：自动添加数据 ==========
    Timer {
        id: dataTimer
        interval: 100           // 每100ms添加一个点 (10Hz)
        running: isRunning      // 由 isRunning 控制
        repeat: true            // 重复执行
        onTriggered: {
            // 生成模拟数据 (正弦波 + 噪声)
            currentY = 50 + 40 * Math.sin(currentX * 0.1) + (Math.random() - 0.5) * 10
            
            // 添加新数据点
            dataSeries.append(currentX, currentY)
            currentX++
            
            // 如果超过最大点数，删除最旧的点
            if (dataSeries.count > maxPoints) {
                dataSeries.remove(0)    // 删除第一个点（最旧的）
            }
            
            // 更新X轴范围（滚动效果）
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

        // ========== 图表区域 ==========
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
            }
        }

        // ========== 控制按钮区域 ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            Button {
                text: isRunning ? "暂停" : "开始"
                onClicked: {
                    isRunning = !isRunning
                }
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

            Item { Layout.fillWidth: true } // 占位，推挤右侧控件

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
                onValueChanged: {
                    dataTimer.interval = value
                }
            }

            Label {
                text: speedSlider.value + "ms"
            }
        }
    }
}