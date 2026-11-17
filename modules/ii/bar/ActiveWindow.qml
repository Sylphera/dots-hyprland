import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root
    property color contentColor: Appearance.colors.colOnLayer0
    property bool contentColorOverridden: false
    property bool classic: false
    property bool vertical: false
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.QsWindow.window?.screen)
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel

    property string activeWindowAddress: `0x${activeWindow?.HyprlandToplevel?.address}`
    property bool focusingThisMonitor: HyprlandData.activeWorkspace?.monitor == monitor?.name
    property var biggestWindow: (Platform.isWindows && root.focusingThisMonitor && !root.activeWindow) ? null : HyprlandData.biggestWindowForWorkspace(HyprlandData.monitors[root.monitor?.id]?.activeWorkspace.id)
    readonly property int currentWorkspaceId: root.monitor?.activeWorkspace?.id ?? -1
    property bool justSwitched: false
    readonly property Toplevel shownWindow: {
        const active = root.activeWindow;
        if (!Platform.isWindows)
            return active?.activated && root.biggestWindow ? active : null;
        return active?.activated && active.HyprlandToplevel?.workspace?.id === root.currentWorkspaceId ? active : null;
    }
    readonly property var expectedWindow: {
        if (!Platform.isWindows || !root.justSwitched || root.shownWindow)
            return null;
        const candidates = HyprlandData.windowList.filter(w => w.workspace?.id === root.currentWorkspaceId && !w.minimized && (w.focusHistoryID ?? -1) >= 0);
        if (candidates.length === 0)
            return null;
        return candidates.reduce((best, w) => w.focusHistoryID < best.focusHistoryID ? w : best);
    }

    onCurrentWorkspaceIdChanged: {
        if (!Platform.isWindows)
            return;
        root.justSwitched = true;
        switchSettle.restart();
    }
    Timer {
        id: switchSettle
        interval: 400
        onTriggered: root.justSwitched = false
    }

    readonly property string activeAppClass: (root.focusingThisMonitor && root.activeWindow?.activated) ? (root.activeWindow?.appId ?? root.biggestWindow?.class ?? "") : (root.biggestWindow?.class ?? "")

    implicitWidth: root.vertical ? Appearance.sizes.verticalBarWidth : root.classic ? colLayout.implicitWidth : Math.min(colLayout.implicitWidth + 12, 280)
    implicitHeight: root.vertical ? 22 : root.classic ? 0 : Appearance.sizes.barHeight

    Loader {
        active: root.vertical
        visible: active
        anchors.centerIn: parent
        sourceComponent: Image {
            width: 18
            height: 18
            sourceSize: Qt.size(18, 18)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            source: Quickshell.iconPath(AppSearch.guessIcon(root.activeAppClass !== "" ? root.activeAppClass : "user-desktop"), "image-missing")
        }
    }

    ColumnLayout {
        id: colLayout
        visible: !root.vertical

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.classic ? 0 : 6
        spacing: -4

        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: root.contentColorOverridden ? Qt.alpha(root.contentColor, 0.7) : Appearance.colors.colSubtext
            elide: Text.ElideRight
            text: root.focusingThisMonitor && root.shownWindow ?
                (Platform.isWindows
                    ? (DesktopEntries.heuristicLookup(root.shownWindow?.appId)?.name ?? root.shownWindow?.appId)
                    : root.shownWindow?.appId) :
                root.focusingThisMonitor && root.expectedWindow ?
                (DesktopEntries.heuristicLookup(root.expectedWindow.class)?.name ?? root.expectedWindow.class) :
                (Platform.isWindows && root.biggestWindow
                    ? (DesktopEntries.heuristicLookup(root.biggestWindow.class)?.name ?? root.biggestWindow.class)
                    : root.biggestWindow?.class) ?? Translation.tr("Desktop")

        }

        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.contentColor
            elide: Text.ElideRight
            text: root.focusingThisMonitor && root.shownWindow ?
                root.shownWindow?.title :
                root.focusingThisMonitor && root.expectedWindow ? root.expectedWindow.title :
                (root.biggestWindow?.title) ?? `${Translation.tr("Workspace")} ${monitor?.activeWorkspace?.id ?? 1}`
        }

    }

}
