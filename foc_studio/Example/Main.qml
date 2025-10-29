// 导入QML基础模块 - 提供基本的QML类型如Item、Rectangle等
import QtQuick
// 导入控件模块 - 提供Button、TextField、ComboBox等UI控件
import QtQuick.Controls
// 导入布局模块 - 提供RowLayout、ColumnLayout等布局管理器
import QtQuick.Layouts

// Window - QML应用程序的主窗口
ApplicationWindow {
    // 窗口初始尺寸
    width: 900
    height: 750
    // 窗口最小尺寸限制
    minimumWidth: 700
    minimumHeight: 600
    // 窗口可见性
    visible: true
    // 窗口标题
    title: "FOC Studio"

}  // Window 结束
