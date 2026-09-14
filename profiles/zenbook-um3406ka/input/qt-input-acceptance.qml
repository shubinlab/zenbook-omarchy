import QtQuick
import QtQuick.Controls

ApplicationWindow {
    visible: true
    width: 640
    height: 240
    title: "Qt Input Acceptance " + input.text

    TextField {
        id: input
        anchors.centerIn: parent
        width: parent.width - 64
        placeholderText: "Wayland Qt input"
        focus: true

        onTextChanged: console.log("VALUE=" + text)
    }
}
