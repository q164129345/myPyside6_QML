// 波形卡片：统一标题、当前值与波形容器外观
// 默认子内容放入图表容器（graphContainer），由页面塞入 TelemetryChart 等。
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: panel

    // qmllint disable unqualified

    property string title: ""
    property string currentValueText: "--"
    default property alias graphContent: graphContainer.data

    Layout.fillWidth: true
    implicitHeight: 250
    color: "white"
    border.color: "#bdc3c7"
    border.width: 1
    radius: 8

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: panel.title
                font.pixelSize: 12
                font.bold: true
                color: "#2c3e50"
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: panel.currentValueText
                font.pixelSize: 12
                font.bold: true
                color: "#2980b9"
            }
        }

        Item {
            id: graphContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
