// CAN 通讯功能页面
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#ecf0f1"
    
    // 接收串口连接状态(如果需要)
    property bool isSerialConnected: false
    
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20

        Text {
            text: "CAN 通讯功能页面"
            font.pixelSize: 24
            color: "#2c3e50"
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: "CAN 总线配置和数据显示区域"
            font.pixelSize: 14
            color: "#7f8c8d"
            Layout.alignment: Qt.AlignHCenter
        }

        // 后续可以在这里添加 CAN 相关的控件
        // 例如: 波特率设置、数据发送、数据接收显示等
    }
}
