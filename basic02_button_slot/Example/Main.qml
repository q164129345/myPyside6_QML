import QtQuick 2.15
import QtQuick.Controls 2.15

ApplicationWindow {
    visible: true
    width: 400
    height: 300
    title: qsTr("Hello PySide6 + QML")

    Button {
        text: "Click Me"
        anchors.centerIn: parent
        onClicked: backend.print_something()
    }
}
