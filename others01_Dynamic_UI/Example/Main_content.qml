import QtQuick
import QtQuick.Controls

Rectangle {
    width: 600
    height: 400
    
    gradient: Gradient {
        GradientStop { position: 0.0; color: "#667eea" }
        GradientStop { position: 1.0; color: "#764ba2" }
    }
    
    Column {
        anchors.centerIn: parent
        spacing: 20
        
        Text {
            text: "🔥 Loader 热重载示例"
            font.pixelSize: 36
            font.bold: true
            color: "white"
            anchors.horizontalCenter: parent.horizontalCenter
        }
        
        Text {
            text: "修改下面的按钮文字试试!"
            font.pixelSize: 16
            color: "white"
            anchors.horizontalCenter: parent.horizontalCenter
        }
        
        Button {
            text: "热重载成功"
            font.pixelSize: 18
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: {
                console.log("button!")
            }
        }
        
        // Button {
        //     text: "另一个按钮"
        //     font.pixelSize: 18
        //     anchors.horizontalCenter: parent.horizontalCenter
        //     onClicked: {
        //         console.log("另一个按钮被点击!")
        //     }
        // }

        Text {
            text: "保存后界面会立即刷新!"
            font.pixelSize: 14
            color: "#f0f0f0"
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
