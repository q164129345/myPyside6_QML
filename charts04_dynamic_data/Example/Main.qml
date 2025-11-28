/**
 * Charts04 - 动态添加数据
 * 
 * 学习要点:
 * 1. series.append(x, y) - 动态添加数据点
 * 2. series.clear() - 清除所有数据
 * 3. series.count - 获取数据点数量
 * 4. 使用按钮触发数据操作
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCharts

ApplicationWindow {
    visible: true
    width: 700
    height: 500
    title: "Charts04 - 动态添加数据"

    // 记录当前X坐标
    property int currentX: 0

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

            // ========== 自定义坐标轴 ==========
            ValueAxis {
                id: axisX
                min: 0
                max: 10
                tickCount: 11
                titleText: "X 轴"
            }

            ValueAxis {
                id: axisY
                min: 0
                max: 100
                tickCount: 6
                titleText: "Y 轴"
            }

            LineSeries {
                id: dataSeries
                name: "动态数据"
                color: "#2196F3"
                width: 2
                axisX: axisX
                axisY: axisY
                // 初始没有数据点，通过按钮动态添加
            }
        }

        // ========== 控制按钮区域 ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Button {
                text: "添加随机点"
                onClicked: {
                    // 生成随机Y值 (0-100)
                    var randomY = Math.random() * 100
                    
                    // 动态添加数据点
                    dataSeries.append(currentX, randomY)
                    
                    // X坐标递增
                    currentX++
                    
                    // 如果超出X轴范围，自动扩展
                    if (currentX > axisX.max) {
                        axisX.max = currentX + 5
                    }
                    
                    console.log("添加点: (" + (currentX-1) + ", " + randomY.toFixed(1) + ")")
                }
            }

            Button {
                text: "添加5个点"
                onClicked: {
                    for (var i = 0; i < 5; i++) {
                        var randomY = Math.random() * 100
                        dataSeries.append(currentX, randomY)
                        currentX++
                    }
                    if (currentX > axisX.max) {
                        axisX.max = currentX + 5
                    }
                }
            }

            Button {
                text: "清除数据"
                onClicked: {
                    dataSeries.clear()  // 清除所有数据点
                    currentX = 0        // 重置X坐标
                    axisX.max = 10      // 重置X轴范围
                    console.log("数据已清除")
                }
            }

            // 显示当前数据点数量
            Label {
                text: "数据点数量: " + dataSeries.count
                font.pixelSize: 14
            }
        }
    }
}