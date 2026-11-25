import QtQuick
import Quickshell
import qs.modules.common

FloatingWindow {
    id: root

    signal closeRequested

    readonly property bool maximized: content.Window.window?.visibility === Window.Maximized

    function hideTitleBar() {
        const backingWindow = content.Window.window;
        if (Platform.isWindows && backingWindow && WindowsNative.windowFrame)
            WindowsNative.windowFrame.hideTitleBar(backingWindow);
    }

    function activate() {
        if (!root.visible)
            return;
        const backingWindow = content.Window.window;
        if (backingWindow) {
            if (Platform.isWindows)
                WindowsNative.windowFrame?.ensureVisible(backingWindow);
            backingWindow.raise();
            backingWindow.requestActivate();
        }
    }

    property bool centered: false
    function center() {
        const backingWindow = content.Window.window;
        if (root.centered || !backingWindow || !root.screen)
            return;
        if (backingWindow.width > root.fitWidth)
            backingWindow.width = root.fitWidth;
        if (backingWindow.height > root.fitHeight)
            backingWindow.height = root.fitHeight;
        backingWindow.x = root.screen.x + Math.round((root.screen.width - backingWindow.width) / 2);
        const barOnTop = !Config.options.bar.bottom && !Config.options.bar.vertical;
        const top = root.screen.y + (barOnTop ? Appearance.sizes.barHeight + 8 : 0) + 32;
        backingWindow.y = Math.max(top, root.screen.y + Math.round((root.screen.height - backingWindow.height) / 2));
        root.centered = true;
    }

    function goToTarget(target) {
        content.goToTarget(target);
    }

    visible: true
    title: "illogical-impulse Settings"
    readonly property real screenWidth: root.screen?.width ?? 1920
    readonly property real screenHeight: root.screen?.height ?? 1080
    readonly property real fitWidth: Math.min(1100, root.screenWidth - 80)
    readonly property real fitHeight: Math.min(700, root.screenHeight - 140)
    implicitWidth: root.fitWidth
    implicitHeight: root.fitHeight
    minimumSize: Qt.size(Math.min(900, root.implicitWidth), Math.min(600, root.implicitHeight))
    color: Appearance.colors.colUiBackground

    onClosed: root.closeRequested()
    onVisibleChanged: {
        if (!root.visible)
            return;
        root.hideTitleBar();
        Qt.callLater(root.center);
        Qt.callLater(root.activate);
    }

    SettingsPcDashboardContent {
        id: content
        anchors.fill: parent
        onCloseRequested: root.closeRequested()
    }

    Repeater {
        model: Platform.isWindows && WindowsNative.windowFrame && !root.maximized ? [
            { edges: Qt.TopEdge, cursor: Qt.SizeVerCursor, left: 8, right: 8, width: 0 },
            { edges: Qt.TopEdge | Qt.LeftEdge, cursor: Qt.SizeFDiagCursor, left: 0, right: -1, width: 8 },
            { edges: Qt.TopEdge | Qt.RightEdge, cursor: Qt.SizeBDiagCursor, left: -1, right: 0, width: 8 }
        ] : []
        delegate: MouseArea {
            required property var modelData
            z: 100
            y: 0
            height: 5
            x: modelData.left >= 0 ? modelData.left : root.width - modelData.width
            width: modelData.width > 0 ? modelData.width : root.width - modelData.left - modelData.right
            cursorShape: modelData.cursor
            onPressed: content.Window.window?.startSystemResize(modelData.edges)
        }
    }
}
