/**
 * Charts01 - 最简单的图表入门
 * 
 * 学习要点:
 * 1. import QtCharts - 导入图表模块
 * 2. ChartView - 图表的容器
 * 3. LineSeries - 折线图数据系列
 * 4. XYPoint - 数据点 (x, y)
 */

import QtQuick
import QtQuick.Controls
import QtCharts  // 导入图表模块

ApplicationWindow {
    visible: true
    width: 600
    height: 400
    title: "Charts01 - 最简单的折线图"

    // ChartView 是图表的容器
    ChartView {
        anchors.fill: parent    // 填满整个窗口
        antialiasing: true      // 抗锯齿，让线条更平滑

        // LineSeries 是折线图的数据系列
        LineSeries {
            name: "我的第一条曲线"  // 图例中显示的名称
            
            // XYPoint 定义数据点 (x坐标, y坐标)
            XYPoint { x: 0; y: 0 }
            XYPoint { x: 1; y: 2 }
            XYPoint { x: 2; y: 1 }
            XYPoint { x: 3; y: 4 }
            XYPoint { x: 4; y: 3 }
            XYPoint { x: 5; y: 5 }
        }
    }
}