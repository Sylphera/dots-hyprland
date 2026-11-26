import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

DockButton {
    id: root
    property var appToplevel
    property var appListRoot
    property var contextMenu
    property int lastFocused: -1
    property real iconSize: DockStyle.iconSize
    property bool appIsActive: appToplevel.toplevels.find(t => (t.activated == true)) !== undefined

    readonly property bool isSeparator: appToplevel.appId === "SEPARATOR"
    property var desktopEntry: DesktopEntries.heuristicLookup(appToplevel.appId)
    readonly property int pinIndex: appToplevel.pinned ? TaskbarApps.apps.indexOf(appToplevel) : -1
    readonly property bool reordering: (appListRoot?.reorderFrom ?? -1) !== -1 && root.pinIndex === appListRoot.reorderFrom
    readonly property real reorderShift: appListRoot?.reorderShift(root.pinIndex) ?? 0
    property bool justReordered: false
    enabled: !isSeparator
    implicitWidth: isSeparator ? 1 : naturalWidth
    property int magnifyId: -1
    readonly property var magnifyValue: root.magnifyId >= 0 ? (DockMagnify.values[root.magnifyId] ?? null) : null
    readonly property bool magnifyActive: DockStyle.magnifying && !root.isSeparator && root.magnifyValue !== null
    z: root.reordering ? 10 : root.magnifyActive ? root.magnifyValue.scale : 0
    scale: root.reordering ? 1.08 : root.magnifyActive ? root.magnifyValue.scale : 1
    transformOrigin: DockStyle.magnifying ? Item.Bottom : Item.Center
    Component.onCompleted: if (!root.isSeparator) root.magnifyId = DockMagnify.register(root)
    Component.onDestruction: DockMagnify.unregister(root.magnifyId)

    Behavior on scale {
        enabled: !root.magnifyActive
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    transform: [Translate {
        x: root.magnifyActive ? root.magnifyValue.shift : 0
    }, Translate {
        x: DockStyle.vertical ? 0 : root.reorderShift
        y: DockStyle.vertical ? root.reorderShift : 0

        Behavior on x {
            enabled: !root.reordering && !(appListRoot?.reorderSettling ?? false)
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        Behavior on y {
            enabled: !root.reordering && !(appListRoot?.reorderSettling ?? false)
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }]

    DragHandler {
        target: null
        enabled: root.pinIndex !== -1 && !(appListRoot?.reorderLocked ?? true) && (appListRoot?.pinnedCount ?? 0) > 1
        xAxis.enabled: !DockStyle.vertical
        yAxis.enabled: DockStyle.vertical
        grabPermissions: PointerHandler.CanTakeOverFromAnything

        onActiveChanged: {
            if (active) {
                appListRoot.beginReorder(root.pinIndex, (DockStyle.vertical ? root.height : root.width) + DockStyle.listSpacing);
            } else if (appListRoot.reorderFrom !== -1) {
                root.justReordered = true;
                appListRoot.endReorder();
                Qt.callLater(() => root.justReordered = false);
            }
        }
        onCentroidChanged: {
            if (!active)
                return;
            const delta = DockStyle.vertical ? centroid.scenePosition.y - centroid.scenePressPosition.y : centroid.scenePosition.x - centroid.scenePressPosition.x;
            appListRoot.updateReorder(delta);
        }
    }

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            root.desktopEntry = DesktopEntries.heuristicLookup(appToplevel.appId);
        }
    }

    Loader {
        active: isSeparator
        anchors {
            fill: parent
            topMargin: DockStyle.separatorInset
            bottomMargin: DockStyle.separatorInset
        }
        sourceComponent: DockSeparator {}
    }

    onHoveredChanged: {
        if (hovered && appToplevel.toplevels.length > 0) {
            appListRoot.lastHoveredButton = root
            appListRoot.buttonHovered = true
            lastFocused = appToplevel.toplevels.length - 1
        } else if (!hovered && appListRoot.lastHoveredButton === root) {
            appListRoot.buttonHovered = false
        }
    }

    onClicked: {
        if (root.justReordered || appListRoot.reorderFrom !== -1)
            return;
        if (appToplevel.toplevels.length === 0) {
            root.desktopEntry?.execute();
            return;
        }
        lastFocused = (lastFocused + 1) % appToplevel.toplevels.length
        appToplevel.toplevels[lastFocused].activate()
    }

    property real wheelAccum: 0
    property var wheelTarget: null
    Timer {
        id: wheelTargetReset
        interval: 600
        onTriggered: root.wheelTarget = null
    }

    WheelHandler {
        enabled: DockStyle.pcFeatures && (Config.options.dock.scrollToCycleWindows ?? false)
            && !root.isSeparator && root.appToplevel.toplevels.length > 0
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            root.wheelAccum += event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
            if (Math.abs(root.wheelAccum) < 120)
                return;
            const step = root.wheelAccum > 0 ? -1 : 1;
            root.wheelAccum = 0;
            const list = root.appToplevel.toplevels;
            let current = root.wheelTarget ? list.indexOf(root.wheelTarget) : -1;
            if (current < 0)
                current = list.findIndex(t => t.activated);
            const next = current < 0 ? (step > 0 ? 0 : list.length - 1) : (current + step + list.length) % list.length;
            root.wheelTarget = list[next];
            wheelTargetReset.restart();
            root.lastFocused = next;
            list[next].activate();
        }
    }

    DockTooltip {
        text: root.desktopEntry?.name || root.appToplevel.appId
        show: root.hovered && !root.isSeparator && (appListRoot?.reorderFrom ?? -1) === -1
        app: root.appToplevel
        contextMenu: root.contextMenu
    }

    middleClickAction: () => {
        root.desktopEntry?.execute();
    }

    altAction: () => {
        root.contextMenu?.open(root, appToplevel.appId);
    }

    contentItem: Loader {
        active: !isSeparator
        sourceComponent: DockAppIcon {
            anchors.centerIn: parent
            iconSource: Quickshell.iconPath(AppSearch.guessIcon(appToplevel.appId), "image-missing")
            iconSize: root.iconSize
            windowCount: appToplevel.toplevels.length
            active: root.appIsActive
        }
    }
}
