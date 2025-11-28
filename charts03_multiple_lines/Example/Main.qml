/**
 * Charts03 - 多条曲线显示
 * 
 * 学习要点:
 * 1. 在 ChartView 中添加多个 LineSeries
 * 2. 每条曲线设置不同的颜色和名称
 * 3. 使用 ValueAxis 自定义坐标轴范围（重要！）
 * 4. 所有曲线必须绑定同一个坐标轴才能正确显示
 */

import QtQuick
import QtQuick.Controls
import QtCharts

ApplicationWindow {
    visible: true
    width: 600
    height: 400
    title: "Charts03 - 多条曲线显示"

    ChartView {
        anchors.fill: parent
        antialiasing: true

        // ========== 自定义坐标轴（关键！如果没有自定义坐标轴，曲线显示不正确）==========
        ValueAxis {
            id: axisX
            min: 0
            max: 5
            tickCount: 6
        }

        ValueAxis {
            id: axisY
            min: 0
            max: 70         // 范围要包含所有数据 (20-60)
            tickCount: 8
        }

        // ========== 第一条曲线：温度 ==========
        LineSeries {
            name: "温度"
            color: "#F44336"
            width: 2
            axisX: axisX    // 绑定X轴
            axisY: axisY    // 绑定Y轴

            XYPoint { x: 0; y: 20 }
            XYPoint { x: 1; y: 25 }
            XYPoint { x: 2; y: 23 }
            XYPoint { x: 3; y: 28 }
            XYPoint { x: 4; y: 26 }
            XYPoint { x: 5; y: 30 }
        }

        // ========== 第二条曲线：湿度 ==========
        LineSeries {
            name: "湿度"
            color: "#2196F3"
            width: 2
            axisX: axisX    // 绑定X轴
            axisY: axisY    // 绑定Y轴

            XYPoint { x: 0; y: 60 }
            XYPoint { x: 1; y: 55 }
            XYPoint { x: 2; y: 58 }
            XYPoint { x: 3; y: 50 }
            XYPoint { x: 4; y: 52 }
            XYPoint { x: 5; y: 48 }
        }

        // ========== 第三条曲线：气压 ==========
        LineSeries {
            name: "气压"
            color: "#4CAF50"
            width: 2
            axisX: axisX    // 绑定X轴
            axisY: axisY    // 绑定Y轴

            XYPoint { x: 0; y: 40 }
            XYPoint { x: 1; y: 42 }
            XYPoint { x: 2; y: 38 }
            XYPoint { x: 3; y: 45 }
            XYPoint { x: 4; y: 43 }
            XYPoint { x: 5; y: 47 }
        }
    }
}