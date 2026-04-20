// TUNE 电机参数调试页面
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#ecf0f1"

    // qmllint disable unqualified

    // 串口连接状态由主窗口传入，用于控制整个调参页面的可操作状态
    property bool isSerialConnected: false
    // 当前页面是否处于激活态，用于在切到 TUNE 时自动触发一次读取
    property bool isPageActive: false
    // 本地占位参数，在后端参数接口尚未接入时用于驱动 UI
    property var fallbackControlParams: createDefaultParams()
    // 当前值始终代表 MCU 回读值（本期可能是占位值）
    property var currentControlParams: cloneParams(fallbackControlParams)
    // 编辑草稿与当前值分离，避免用户输入时直接改动回读值
    property var draftControlParams: cloneParams(fallbackControlParams)
    // 参数是否已获取到有效回读结果
    property bool controlParamsAvailable: false
    // 参数同步是否正在进行中
    property bool controlParamsBusy: false
    // 最近一次读写操作的状态文案
    property string controlParamsLastStatus: "未读取，当前显示本地占位参数"
    // 是否处于后端未接入的演示模式
    property bool demoMode: true
    // 用于在程序修改草稿时刷新各行输入框
    property int draftRevision: 0
    // 读取/应用流程中是否持续让编辑草稿跟随后端回读
    property bool keepDraftSyncedToBackend: true
    // 参数行数据模型，用于生成速度环与电流环的 10 行控件
    readonly property var parameterFields: [
        { "fieldKey": "kp", "label": "Kp", "unit": "" },
        { "fieldKey": "ki", "label": "Ki", "unit": "" },
        { "fieldKey": "kd", "label": "Kd", "unit": "" },
        { "fieldKey": "ramp", "label": "Ramp", "unit": "output/s" },
        { "fieldKey": "tf", "label": "Tf", "unit": "s" }
    ]
    // 电机限幅参数行数据模型，用于生成 voltage_limit 与 current_limit 的 2 行控件
    readonly property var motorLimitFields: [
        { "fieldKey": "voltage_limit", "label": "Voltage Limit", "unit": "V" },
        { "fieldKey": "current_limit", "label": "Current Limit", "unit": "A" }
    ]
    // 页面上的参数分组定义，统一驱动三张卡片渲染
    readonly property var parameterGroups: [
        { "groupKey": "speedLoop", "title": "速度环参数", "fields": parameterFields },
        { "groupKey": "currentLoop", "title": "电流环参数", "fields": parameterFields },
        { "groupKey": "motorLimits", "title": "电机限幅参数", "fields": motorLimitFields }
    ]

    // 生成 UI 占位参数，保证在后端接口未就绪时页面可完整演示
    function createDefaultParams() {
        return {
            "speedLoop": { "kp": 0.350, "ki": 12.000, "kd": 0.000, "ramp": 0.000, "tf": 0.010 },
            "currentLoop": { "kp": 0.180, "ki": 8.500, "kd": 0.000, "ramp": 0.000, "tf": 0.005 },
            "motorLimits": { "voltage_limit": 12.000, "current_limit": 5.000 }
        }
    }

    // 深拷贝参数对象，避免编辑草稿与当前值共享引用
    function cloneParams(params) {
        return JSON.parse(JSON.stringify(params))
    }

    // 将后端返回的对象归一化到页面需要的固定结构
    function normalizeParams(params) {
        var defaults = createDefaultParams()
        var source = params || {}
        var normalized = cloneParams(defaults)

        for (var groupIndex = 0; groupIndex < parameterGroups.length; groupIndex++) {
            var groupKey = parameterGroups[groupIndex].groupKey
            var sourceGroup = source[groupKey] || {}
            var fields = parameterGroups[groupIndex].fields

            for (var fieldIndex = 0; fieldIndex < fields.length; fieldIndex++) {
                var fieldKey = fields[fieldIndex].fieldKey
                if (typeof sourceGroup[fieldKey] !== "undefined" && sourceGroup[fieldKey] !== null) {
                    var numericValue = Number(sourceGroup[fieldKey])
                    normalized[groupKey][fieldKey] = isNaN(numericValue) ? defaults[groupKey][fieldKey] : numericValue
                }
            }
        }

        return normalized
    }

    // 安全读取未来 backend 的预留属性，避免接口未接入时页面报错
    function readBackendMember(name) {
        if (!backend) {
            return { "exists": false, "value": undefined }
        }

        try {
            var memberValue = backend[name]
            return { "exists": typeof memberValue !== "undefined", "value": memberValue }
        } catch (error) {
            return { "exists": false, "value": undefined }
        }
    }

    // 安全检查未来 backend 是否已暴露预留方法
    function hasBackendMethod(name) {
        if (!backend) {
            return false
        }

        try {
            return typeof backend[name] === "function"
        } catch (error) {
            return false
        }
    }

    // 从 backend 同步参数状态；若接口未接入则回退到本地占位数据
    function syncFromBackend(resetDraft) {
        var paramsInfo = readBackendMember("controlParams")
        var availableInfo = readBackendMember("controlParamsAvailable")
        var busyInfo = readBackendMember("controlParamsBusy")
        var statusInfo = readBackendMember("controlParamsLastStatus")
        var backendReady = paramsInfo.exists || availableInfo.exists || busyInfo.exists || statusInfo.exists
                           || hasBackendMethod("queryControlParams")
                           || hasBackendMethod("applyControlParams")
                           || hasBackendMethod("saveCurrentTuneParamsToFlash")

        demoMode = !backendReady
        currentControlParams = normalizeParams(paramsInfo.exists ? paramsInfo.value : fallbackControlParams)
        controlParamsAvailable = availableInfo.exists ? Boolean(availableInfo.value) : false
        controlParamsBusy = busyInfo.exists ? Boolean(busyInfo.value) : false

        if (statusInfo.exists && statusInfo.value !== null && String(statusInfo.value).length > 0) {
            controlParamsLastStatus = String(statusInfo.value)
        } else if (demoMode) {
            controlParamsLastStatus = "UI 演示模式：后端参数接口尚未接入"
        } else if (controlParamsAvailable) {
            controlParamsLastStatus = "参数已同步"
        } else {
            controlParamsLastStatus = "未读取参数"
        }

        if (resetDraft || keepDraftSyncedToBackend || !hasDirtyFields()) {
            restoreDraftFromCurrent()
        }
    }

    // 根据当前连接与同步状态生成顶部状态提示
    function syncStatusText() {
        if (!isSerialConnected) {
            return "串口未连接"
        }
        if (controlParamsBusy) {
            return "参数同步中"
        }
        if (controlParamsAvailable) {
            return demoMode ? "演示数据已加载" : "参数已同步"
        }
        return demoMode ? "未读取，当前显示占位值" : "等待读取参数"
    }

    // 统一生成串口连接状态文案
    function connectionStatusText() {
        return isSerialConnected ? "已连接" : "未连接"
    }

    // 统一格式化数值显示，避免多处重复 toFixed 逻辑
    function formatValue(value) {
        var numericValue = Number(value)
        return isNaN(numericValue) ? "--" : numericValue.toFixed(6)
    }

    // 读取当前值对象中的指定字段
    function readCurrentParam(loopKey, fieldKey) {
        return Number(currentControlParams[loopKey][fieldKey])
    }

    // 读取编辑草稿中的指定字段
    function readDraftParam(loopKey, fieldKey) {
        return Number(draftControlParams[loopKey][fieldKey])
    }

    // 为输入框提供初始文案与程序性刷新文本
    function readDraftText(loopKey, fieldKey) {
        return formatValue(readDraftParam(loopKey, fieldKey))
    }

    // 用户修改输入框时只更新草稿，不直接覆盖当前值
    function setDraftParam(loopKey, fieldKey, textValue) {
        var nextParams = cloneParams(draftControlParams)
        var trimmedText = String(textValue).trim()
        var numericValue = Number(trimmedText)

        // 用户开始手动编辑后，停止自动用回读值覆盖草稿
        keepDraftSyncedToBackend = false

        if (trimmedText.length === 0 || isNaN(numericValue)) {
            nextParams[loopKey][fieldKey] = currentControlParams[loopKey][fieldKey]
        } else {
            nextParams[loopKey][fieldKey] = numericValue
        }

        draftControlParams = nextParams
    }

    // 判断单个字段是否与当前值不同，用于显示“已修改”状态
    function isFieldDirty(loopKey, fieldKey) {
        return Math.abs(readDraftParam(loopKey, fieldKey) - readCurrentParam(loopKey, fieldKey)) > 0.0000005
    }

    // 判断页面是否存在尚未应用的改动
    function hasDirtyFields() {
        for (var groupIndex = 0; groupIndex < parameterGroups.length; groupIndex++) {
            var groupKey = parameterGroups[groupIndex].groupKey
            var fields = parameterGroups[groupIndex].fields
            for (var fieldIndex = 0; fieldIndex < fields.length; fieldIndex++) {
                if (isFieldDirty(groupKey, fields[fieldIndex].fieldKey)) {
                    return true
                }
            }
        }

        return false
    }

    // 将编辑草稿恢复为当前值，供参数读取成功后的草稿覆盖逻辑复用
    function restoreDraftFromCurrent() {
        draftControlParams = cloneParams(currentControlParams)
        draftRevision += 1
    }

    // 构造未来写入 backend 的参数载荷
    function buildApplyPayload() {
        return cloneParams(draftControlParams)
    }

    // 触发一次参数读取；如果后端未接入则回退到本地演示逻辑
    function triggerQuery() {
        if (!isSerialConnected || controlParamsBusy) {
            return
        }

        keepDraftSyncedToBackend = true

        if (hasBackendMethod("queryControlParams")) {
            controlParamsLastStatus = "正在读取参数..."
            controlParamsBusy = true
            try {
                backend.queryControlParams()
            } catch (error) {
                controlParamsBusy = false
                controlParamsLastStatus = "调用 queryControlParams() 失败"
            }
            return
        }

        controlParamsBusy = true
        currentControlParams = cloneParams(fallbackControlParams)
        controlParamsAvailable = true
        restoreDraftFromCurrent()
        controlParamsBusy = false
        controlParamsLastStatus = "UI 演示模式：已加载本地占位参数"
    }

    // 触发一次参数应用；如果后端未接入则在本地模拟应用运行参数
    function triggerApply() {
        if (!isSerialConnected || controlParamsBusy) {
            return
        }

        var payload = buildApplyPayload()
        keepDraftSyncedToBackend = true

        if (hasBackendMethod("applyControlParams")) {
            controlParamsLastStatus = "正在应用参数..."
            controlParamsBusy = true
            try {
                backend.applyControlParams(payload)
            } catch (error) {
                controlParamsBusy = false
                controlParamsLastStatus = "调用 applyControlParams() 失败"
            }
            return
        }

        controlParamsBusy = true
        currentControlParams = normalizeParams(payload)
        controlParamsAvailable = true
        restoreDraftFromCurrent()
        controlParamsBusy = false
        controlParamsLastStatus = "UI 演示模式：已本地应用参数"
    }

    // 触发一次参数保存；保存来源始终是 MCU 当前运行参数，而不是编辑框草稿
    function triggerSave() {
        if (!isSerialConnected || controlParamsBusy) {
            return
        }
        if (!controlParamsAvailable) {
            controlParamsLastStatus = "请先读取并确认当前 TUNE 参数后再保存"
            return
        }

        if (hasBackendMethod("saveCurrentTuneParamsToFlash")) {
            controlParamsLastStatus = "正在保存当前 TUNE 参数到 FLASH..."
            controlParamsBusy = true
            try {
                backend.saveCurrentTuneParamsToFlash()
            } catch (error) {
                controlParamsBusy = false
                controlParamsLastStatus = "调用 saveCurrentTuneParamsToFlash() 失败"
            }
            return
        }

        controlParamsLastStatus = "UI 演示模式：未执行实际 TUNE 参数 FLASH 保存"
    }

    component InputField: Rectangle {
        id: control
        property alias text: input.text
        property alias validator: input.validator
        property string placeholderText: ""
        property int fontPixelSize: 13
        property int horizontalAlignment: TextInput.AlignLeft
        readonly property bool acceptableInput: input.acceptableInput

        implicitWidth: 120
        implicitHeight: 30
        radius: 4
        color: control.enabled ? "white" : "#dde1e4"
        border.color: input.activeFocus ? "#3498db" : "#bdc3c7"
        border.width: 1

        Text {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            text: control.placeholderText
            font.pixelSize: control.fontPixelSize
            color: "#95a5a6"
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: control.horizontalAlignment
            visible: input.text.length === 0
        }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            font.pixelSize: control.fontPixelSize
            color: control.enabled ? "#2c3e50" : "#7f8c8d"
            enabled: control.enabled
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: control.horizontalAlignment
            selectByMouse: control.enabled
            clip: true
        }
    }

    component ActionButton: Rectangle {
        id: control
        property string text: ""
        property color normalColor: "#27ae60"
        property color pressedColor: normalColor
        signal clicked()

        implicitWidth: 112
        implicitHeight: 32
        radius: 5
        color: control.enabled
               ? (buttonArea.pressed ? control.pressedColor : control.normalColor)
               : "#bdc3c7"

        Text {
            anchors.centerIn: parent
            text: control.text
            font.pixelSize: 12
            font.bold: true
            color: "white"
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            enabled: control.enabled
            cursorShape: control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: control.clicked()
        }
    }

    component ParameterRow: RowLayout {
        id: rowRoot
        required property string loopKey
        required property string fieldKey
        required property string labelText
        required property string unitText

        implicitHeight: 32
        spacing: 10

        Text {
            Layout.preferredWidth: 64
            text: rowRoot.labelText
            font.pixelSize: 13
            color: "#2c3e50"
        }

        Rectangle {
            Layout.preferredWidth: 100
            implicitHeight: 30
            radius: 4
            color: "#e8f4fd"
            border.color: "#aed6f1"
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: root.formatValue(root.readCurrentParam(rowRoot.loopKey, rowRoot.fieldKey))
                font.pixelSize: 13
                font.bold: true
                color: "#2980b9"
            }
        }

        InputField {
            id: editField
            Layout.preferredWidth: 120
            enabled: root.isSerialConnected && !root.controlParamsBusy
            horizontalAlignment: TextInput.AlignRight
            placeholderText: "输入数值"
            validator: DoubleValidator {
                notation: DoubleValidator.StandardNotation
                decimals: 6
            }

            function syncText() {
                text = root.readDraftText(rowRoot.loopKey, rowRoot.fieldKey)
            }

            Component.onCompleted: syncText()
            onTextChanged: root.setDraftParam(rowRoot.loopKey, rowRoot.fieldKey, text)
        }

        // 程序恢复草稿时统一刷新输入框文本，避免旧值残留在界面上
        Connections {
            target: root
            function onDraftRevisionChanged() {
                editField.syncText()
            }
        }

        Text {
            Layout.preferredWidth: 28
            text: rowRoot.unitText
            font.pixelSize: 12
            color: "#7f8c8d"
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            Layout.preferredWidth: 56
            implicitHeight: 24
            radius: 12
            color: root.isFieldDirty(rowRoot.loopKey, rowRoot.fieldKey) ? "#fdebd0" : "#e5e8e8"
            border.color: root.isFieldDirty(rowRoot.loopKey, rowRoot.fieldKey) ? "#f5cba7" : "#d5dbdb"
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: root.isFieldDirty(rowRoot.loopKey, rowRoot.fieldKey) ? "已修改" : "一致"
                font.pixelSize: 11
                font.bold: root.isFieldDirty(rowRoot.loopKey, rowRoot.fieldKey)
                color: root.isFieldDirty(rowRoot.loopKey, rowRoot.fieldKey) ? "#d35400" : "#7f8c8d"
            }
        }
    }

    component ParameterCard: Rectangle {
        id: cardRoot
        required property string groupKey
        required property string titleText
        required property var fieldsModel

        Layout.fillWidth: true
        implicitHeight: cardLayout.implicitHeight + 32
        color: "white"
        border.color: "#bdc3c7"
        border.width: 1
        radius: 8

        ColumnLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Text {
                text: cardRoot.titleText
                font.pixelSize: 16
                font.bold: true
                color: "#2c3e50"
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 28
                radius: 4
                color: "#f4f6f7"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        Layout.preferredWidth: 64
                        text: "名称"
                        font.pixelSize: 11
                        color: "#7f8c8d"
                    }

                    Text {
                        Layout.preferredWidth: 100
                        text: "当前值"
                        font.pixelSize: 11
                        color: "#7f8c8d"
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        Layout.preferredWidth: 120
                        text: "编辑值"
                        font.pixelSize: 11
                        color: "#7f8c8d"
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        Layout.preferredWidth: 28
                        text: "单位"
                        font.pixelSize: 11
                        color: "#7f8c8d"
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        Layout.preferredWidth: 56
                        text: "状态"
                        font.pixelSize: 11
                        color: "#7f8c8d"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Repeater {
                model: cardRoot.fieldsModel

                delegate: Item {
                    required property var modelData
                    implicitWidth: parent ? parent.width : 0
                    implicitHeight: rowItem.implicitHeight

                    ParameterRow {
                        id: rowItem
                        width: parent.width
                        loopKey: cardRoot.groupKey
                        fieldKey: modelData.fieldKey
                        labelText: modelData.label
                        unitText: modelData.unit
                    }
                }
            }
        }
    }

    // 参数保存成功提示弹窗
    Rectangle {
        id: saveSuccessToast
        anchors.centerIn: parent
        width: 280
        height: 120
        radius: 16
        color: "#16a085"
        visible: false
        z: 100

        // 半透明遮罩，让弹窗更突出
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: "#1abc9c"
            border.width: 2
        }

        Column {
            anchors.centerIn: parent
            spacing: 10

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "✓"
                font.pixelSize: 32
                font.bold: true
                color: "white"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "参数保存成功"
                font.pixelSize: 20
                font.bold: true
                color: "white"
            }
        }

        SequentialAnimation {
            id: toastAnimation
            running: false
            ScriptAction { script: { saveSuccessToast.visible = true; saveSuccessToast.opacity = 1.0; saveSuccessToast.scale = 1.0 } }
            PauseAnimation { duration: 1800 }
            NumberAnimation { target: saveSuccessToast; property: "opacity"; to: 0.0; duration: 400 }
            ScriptAction { script: saveSuccessToast.visible = false }
        }
    }

    ScrollView {
        id: pageScrollView
        anchors.fill: parent
        clip: true
        // 内容宽度按 ScrollView 可视区域铺满，不随竖向滚动条预留宽度缩窄
        contentWidth: width - leftPadding - rightPadding
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Item {
            width: pageScrollView.width - pageScrollView.leftPadding - pageScrollView.rightPadding
            implicitHeight: pageLayout.implicitHeight + 24

            // 整个 TUNE 页面统一放入滚动容器，避免中间卡片的独立 ScrollView 影响上下间距
            ColumnLayout {
                id: pageLayout
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 94
            color: "white"
            border.color: "#bdc3c7"
            border.width: 1
            radius: 8

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                Text {
                    text: "参数调试"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#2c3e50"
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 18
                    rowSpacing: 6

                    Text {
                        text: "连接状态: " + root.connectionStatusText()
                        font.pixelSize: 13
                        color: root.isSerialConnected ? "#27ae60" : "#e74c3c"
                    }

                    Text {
                        text: "同步状态: " + root.syncStatusText()
                        font.pixelSize: 13
                        color: root.controlParamsAvailable ? "#2980b9" : "#7f8c8d"
                    }

                    Text {
                        text: "后端接口: " + (root.demoMode ? "未接入" : "已预留")
                        font.pixelSize: 13
                        color: root.demoMode ? "#e67e22" : "#27ae60"
                    }

                    Text {
                        Layout.columnSpan: 3
                        text: "最近操作: " + root.controlParamsLastStatus
                        font.pixelSize: 12
                        color: "#2c3e50"
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

                Repeater {
                    model: root.parameterGroups

                    delegate: ParameterCard {
                        required property var modelData
                        groupKey: modelData.groupKey
                        titleText: modelData.title
                        fieldsModel: modelData.fields
                    }
                }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 72
            color: "white"
            border.color: "#bdc3c7"
            border.width: 1
            radius: 8

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 10

                Text {
                    text: root.hasDirtyFields() ? "有未应用修改" : "当前无未应用修改"
                    font.pixelSize: 13
                    color: root.hasDirtyFields() ? "#d35400" : "#7f8c8d"
                }

                Item {
                    Layout.fillWidth: true
                }

                ActionButton {
                    text: "读取参数"
                    enabled: root.isSerialConnected && !root.controlParamsBusy
                    normalColor: "#3498db"
                    pressedColor: "#2c80b4"
                    onClicked: root.triggerQuery()
                }

                ActionButton {
                    text: "应用"
                    enabled: root.isSerialConnected && !root.controlParamsBusy && root.controlParamsAvailable && root.hasDirtyFields()
                    normalColor: "#27ae60"
                    pressedColor: "#1e8449"
                    onClicked: root.triggerApply()
                }

                ActionButton {
                    text: "TUNE 参数保存"
                    enabled: root.isSerialConnected && !root.controlParamsBusy && root.controlParamsAvailable
                    normalColor: "#16a085"
                    pressedColor: "#117864"
                    onClicked: root.triggerSave()
                }
            }
                }
            }
        }
    }

    // 串口断开时立即结束本地 busy 状态，避免按钮持续锁死
    onIsSerialConnectedChanged: {
        if (!isSerialConnected) {
            controlParamsBusy = false
        }
    }

    onIsPageActiveChanged: {
        if (isPageActive && isSerialConnected && !controlParamsBusy) {
            triggerQuery()
        }
    }

    Component.onCompleted: syncFromBackend(true)

    // 预留未来 backend 的参数变更信号，接口未接入时忽略即可
    Connections {
        target: backend
        enabled: backend !== null && root.isPageActive
        ignoreUnknownSignals: true

        function onControlParamsChanged() {
            root.syncFromBackend(false)
        }

        function onControlParamsAvailableChanged() {
            var availableInfo = root.readBackendMember("controlParamsAvailable")
            root.syncFromBackend(availableInfo.exists ? Boolean(availableInfo.value) : false)
        }

        function onControlParamsBusyChanged() {
            root.syncFromBackend(false)
        }

        function onControlParamsLastStatusChanged() {
            root.syncFromBackend(false)
        }

        function onTuneSaveSucceeded() {
            toastAnimation.stop()
            toastAnimation.start()
        }
    }
}
