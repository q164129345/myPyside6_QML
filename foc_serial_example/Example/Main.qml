import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    visible: true
    width: 600
    height: 400
    title: "FOC上位机 - 多任务架构演示"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // 状态显示
        Rectangle {
            Layout.fillWidth: true
            height: 60
            color: "#f0f0f0"
            radius: 8

            ColumnLayout {
                anchors.centerIn: parent
                Text {
                    text: "连接状态: " + backend.status
                    font.pixelSize: 16
                    font.bold: true
                }
                Text {
                    text: "电机转速: " + backend.motorSpeed + " RPM"
                    font.pixelSize: 14
                    color: "#0066cc"
                }
            }
        }

        // 控制按钮
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Button {
                text: "启动通讯"
                Layout.fillWidth: true
                onClicked: backend.start_communication()
            }

            Button {
                text: "停止通讯"
                Layout.fillWidth: true
                onClicked: backend.stop_communication()
            }
        }

        // 转速控制
        GroupBox {
            title: "电机控制"
            Layout.fillWidth: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 10

                Text {
                    text: "目标转速: " + speedSlider.value + " RPM"
                }

                Slider {
                    id: speedSlider
                    Layout.fillWidth: true
                    from: 0
                    to: 3000
                    value: 1000
                    stepSize: 100
                }

                Button {
                    text: "设置转速"
                    Layout.alignment: Qt.AlignHCenter
                    onClicked: backend.set_motor_speed(speedSlider.value)
                }
            }
        }

        // 日志区域
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            border.color: "#cccccc"
            border.width: 1
            radius: 4

            ScrollView {
                anchors.fill: parent
                anchors.margins: 5

                Text {
                    text: "实时日志显示区域\n请查看控制台输出..."
                    font.pixelSize: 12
                    color: "#666666"
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
