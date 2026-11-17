import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property bool pinned: Config.options?.dock.pinnedOnStartup ?? false
    property bool barState: false
    property bool ready: false

    function colorFromName(name) {
        if (name === "black" || name === "transparent")
            return name;
        return Appearance.colors["col" + name.charAt(0).toUpperCase() + name.slice(1)] ?? Appearance.colors.colLayer0;
    }

    function screensForDock() {
        const screens = Quickshell.screens;
        const list = Config.options.dock.screenList;
        if (!list || list.length === 0)
            return screens;
        return screens.filter(screen => list.includes(screen.name));
    }

    Component.onCompleted: {
        barSettleTimer.start()
    }

    Timer {
        id: barSettleTimer
        interval: 300
        onTriggered: {
            root.barState = GlobalStates.barOpen
            root.ready = true
        }
    }

    Connections {
        target: Config.options.dock
        function onPositionChanged() {
            root.ready = false
            barSettleTimer.restart()
        }
        function onStyleChanged() {
            root.ready = false
            barSettleTimer.restart()
        }
    }

    Connections {
        target: GlobalStates
        function onBarOpenChanged() { barSettleTimer.restart() }
    }

    Variants {
        model: !root.ready ? [] : root.screensForDock().map(screen => ({
            screen: screen,
            position: Config.options.dock.position,
            layout: `${Config.options.dock.position}|${Config.options.dock.style}|${Config.options.dock.height}|${root.barState}`
        }))

        PanelWindow {
            id: dockRoot
            required property var modelData
            screen: modelData.screen
            visible: !GlobalStates.screenLocked

            // Dock actions can open QuickShell overlays. The native focus
            // grab must consider the dock an internal surface, otherwise its
            // initial click dismisses an overlay before the QML toggle runs.
            Component.onCompleted: {
                if (Platform.isWindows) GlobalFocusGrab.addPersistent(dockRoot);
            }
            Component.onDestruction: {
                if (Platform.isWindows) GlobalFocusGrab.removePersistent(dockRoot);
            }

            readonly property bool hug: DockStyle.hug
            readonly property string position: DockStyle.position
            readonly property bool vertical: position !== "bottom"
            readonly property real gap: Appearance.sizes.hyprlandGapsOut
            readonly property real shadowMargin: Appearance.sizes.elevationMargin
            // Windows' input mask follows dockMouseArea while it is animated.
            // Cursor hit-testing against that moving mask causes alternating
            // enter/leave events as the dock slides into or out of view.
            // Use the existing native GetCursorPos-backed API instead, with
            // a stationary screen-edge trigger and immediate exit detection.
            readonly property bool stableWindowsHover: Platform.isWindows
                && Config.options.windowsPort.dockStableHover
                && Config.options.dock.hoverToReveal
            property bool nativePointerInside: false
            // The native workspace model tracks windows independently of the
            // foreground HWND. A temporary focus gap during a desktop switch
            // must never reveal the dock if the destination has windows.
            // An actually empty destination, however, can reveal immediately.
            readonly property bool nativeWorkspaceEmpty: {
                const workspace = Hyprland.focusedWorkspace;
                if (!workspace)
                    return false;
                const hasToplevel = (workspace.toplevels?.values ?? []).some(t =>
                    !(t.wayland?.minimized ?? false)
                    && !HyprlandData.isSpecialWindow(HyprlandData.clientForToplevel(t)));
                const hasTrackedWindow = HyprlandData.windowList.some(w =>
                    w.workspace?.id === workspace.id && !w.minimized
                    && !HyprlandData.isSpecialWindow(w));
                return !hasToplevel && !hasTrackedWindow;
            }
            Timer {
                interval: 16
                repeat: true
                triggeredOnStart: true
                running: dockRoot.stableWindowsHover && dockRoot.visible && !root.pinned
                onTriggered: {
                    const screen = dockRoot.screen;
                    const cursor = WindowsNative.input?.cursorPosition();
                    let onEdge = false;
                    let inExpandedDock = false;
                    if (screen && cursor?.screen === screen.name) {
                        const x = cursor.x;
                        const y = cursor.y;
                        // Sample slightly inside the physical trigger as
                        // well: fast motion can cross a 2px strip between
                        // two frames, even when QML never receives onEntered.
                        const edge = Math.max(6, Config.options.dock.hoverRegionHeight ?? 2);
                        if (dockRoot.vertical) {
                            const halfHeight = dockMouseArea.implicitHeight / 2;
                            const yWithin = y >= (screen.height / 2 - halfHeight)
                                && y < (screen.height / 2 + halfHeight);
                            const atLeft = dockRoot.position === "left";
                            const sideDistance = atLeft ? x : screen.width - x;
                            onEdge = yWithin && sideDistance >= 0 && sideDistance <= edge;
                            inExpandedDock = yWithin && sideDistance >= 0
                                && sideDistance <= dockRoot.width;
                        } else {
                            const halfWidth = dockMouseArea.implicitWidth / 2;
                            const xWithin = x >= (screen.width / 2 - halfWidth)
                                && x < (screen.width / 2 + halfWidth);
                            const bottomDistance = screen.height - y;
                            onEdge = xWithin && bottomDistance >= 0 && bottomDistance <= edge;
                            inExpandedDock = xWithin && bottomDistance >= 0
                                && bottomDistance <= dockRoot.height;
                        }
                    }
                    if (onEdge || (dockRoot.nativePointerInside && inExpandedDock)) {
                        dockRoot.nativePointerInside = true;
                    } else {
                        dockRoot.nativePointerInside = false;
                    }
                }
                onRunningChanged: {
                    if (!running) {
                        dockRoot.nativePointerInside = false;
                    }
                }
            }
            readonly property color backgroundColor: (hug && Config.options.dock.followFrameColor && Config.options.bar?.showFrame && Config.options.bar?.frameColor)
                ? root.colorFromName(Config.options.bar.frameColor)
                : root.colorFromName(Config.options.dock.backgroundColor)
            readonly property real borderWidth: (Config.options.dock.showBackground && Config.options.dock.showBorder && !hug) ? Config.options.dock.borderWidth : 0

            property bool reveal: {
                if (dockContextMenu.isOpen)
                    return true;
                if (root.pinned)
                    return true;
                if (Config.options?.dock.hoverToReveal) {
                    // In stable mode the pointer state never depends on the
                    // position of the dock's animated QML input region.
                    if (dockRoot.stableWindowsHover) {
                        if (dockRoot.nativePointerInside)
                            return true;
                    } else {
                        const frameHovered = typeof GlobalStates.isFrameHovered === "function"
                            && GlobalStates.isFrameHovered(dockRoot.screen?.name, dockRoot.position);
                        if (dockMouseArea.containsMouse || frameHovered)
                            return true;
                    }
                }
                if (dockApps.requestDockShow)
                    return true;
                // Both window sources must agree before considering a workspace empty.
                if (Platform.isWindows)
                    return dockRoot.nativeWorkspaceEmpty;
                return !ToplevelManager.activeToplevel?.activated;
            }

            exclusiveZone: root.pinned ? DockStyle.zone : 0

            anchors {
                top: dockRoot.vertical
                bottom: true
                left: dockRoot.position !== "right"
                right: dockRoot.position !== "left"
            }
            margins {
                bottom: dockRoot.hug && dockRoot.position === "bottom" ? -dockRoot.gap : 0
                left: dockRoot.hug && dockRoot.position === "left" ? -dockRoot.gap : 0
                right: dockRoot.hug && dockRoot.position === "right" ? -dockRoot.gap : 0
            }
            implicitWidth: dockRoot.vertical ? DockStyle.thickness : dockBackground.implicitWidth
            implicitHeight: dockRoot.vertical ? dockBackground.implicitHeight : DockStyle.thickness
            WlrLayershell.namespace: "quickshell:dock"
            color: "transparent"

            mask: Region {
                // On Windows, dockMouseArea extends over the bottom screen
                // edge even while the floating dock is hidden. That let
                // invisible app buttons receive hover/clicks through the
                // animated input mask. Keep the *original MouseArea* available
                // as soon as the dock is revealed: a visual-only Rectangle
                // is not a substitute for the interactive button hit area.
                // When hidden, only the fixed edge strip remains interactive.
                item: dockRoot.stableWindowsHover
                    ? (dockRoot.reveal ? dockMouseArea : null)
                    : dockMouseArea
                Region {
                    item: dockEdgeTrigger.visible ? dockEdgeTrigger : null
                }
            }

            // The animated dock moves almost completely outside its own
            // PanelWindow when hidden. A MouseArea inside that moving item
            // cannot reliably receive Windows hover events. Keep a fixed
            // narrow hit target at the physical screen edge and combine its
            // input mask with the dock's existing animated input region.
            MouseArea {
                id: dockEdgeTrigger
                visible: Platform.isWindows && Config.options.windowsPort.dockStableHover
                    && Config.options.dock.hoverToReveal && !root.pinned
                hoverEnabled: true
                // The final two pixels reveal the dock, but must never
                // forward a click or hover to a partly hidden app button.
                acceptedButtons: Qt.AllButtons
                onEntered: {
                    if (dockRoot.stableWindowsHover) {
                        dockRoot.nativePointerInside = true;
                    }
                }
                z: 1
                width: dockRoot.vertical ? Math.max(2, Config.options.dock.hoverRegionHeight)
                    : Math.min(dockRoot.width, dockMouseArea.implicitWidth)
                height: dockRoot.vertical ? Math.min(dockRoot.height, dockMouseArea.implicitHeight)
                    : Math.max(2, Config.options.dock.hoverRegionHeight)
                anchors {
                    bottom: dockRoot.vertical ? undefined : parent.bottom
                    horizontalCenter: dockRoot.vertical ? undefined : parent.horizontalCenter
                    verticalCenter: dockRoot.vertical ? parent.verticalCenter : undefined
                    left: dockRoot.position === "left" ? parent.left : undefined
                    right: dockRoot.position === "right" ? parent.right : undefined
                }
            }

            MouseArea {
                id: dockMouseArea
                hoverEnabled: true
                width: dockRoot.vertical ? parent.width : implicitWidth
                height: dockRoot.vertical ? implicitHeight : parent.height
                implicitWidth: dockHoverRegion.implicitWidth + dockRoot.shadowMargin * 2
                implicitHeight: dockHoverRegion.implicitHeight + dockRoot.shadowMargin * 2

                readonly property real hiddenOffset: Config.options?.dock.hoverToReveal
                    ? (DockStyle.thickness - Config.options.dock.hoverRegionHeight)
                    : (DockStyle.thickness + 1)
                property real offset: dockRoot.reveal ? 0 : hiddenOffset

                Behavior on offset {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                anchors {
                    top: dockRoot.vertical ? undefined : parent.top
                    topMargin: dockMouseArea.offset
                    horizontalCenter: dockRoot.vertical ? undefined : parent.horizontalCenter
                    verticalCenter: dockRoot.vertical ? parent.verticalCenter : undefined
                    left: dockRoot.position === "left" ? parent.left : undefined
                    leftMargin: -dockMouseArea.offset
                    right: dockRoot.position === "right" ? parent.right : undefined
                    rightMargin: -dockMouseArea.offset
                }

                Item {
                    id: dockHoverRegion
                    anchors.fill: parent
                    implicitWidth: dockBackground.implicitWidth
                    implicitHeight: dockBackground.implicitHeight

                    Item {
                        id: dockBackground
                        anchors {
                            top: dockRoot.vertical ? undefined : parent.top
                            bottom: dockRoot.vertical ? undefined : parent.bottom
                            left: dockRoot.vertical ? parent.left : undefined
                            right: dockRoot.vertical ? parent.right : undefined
                            horizontalCenter: dockRoot.vertical ? undefined : parent.horizontalCenter
                            verticalCenter: dockRoot.vertical ? parent.verticalCenter : undefined
                        }
                        implicitWidth: dockRow.implicitWidth + DockStyle.backgroundPadding * 2
                        implicitHeight: dockRow.implicitHeight + DockStyle.backgroundPadding * 2

                        StyledRectangularShadow {
                            target: dockVisualBackground
                            visible: false
                        }

                        Rectangle {
                            id: dockVisualBackground
                            anchors.fill: parent
                            anchors.topMargin: dockRoot.position === "bottom" ? dockRoot.shadowMargin : 0
                            anchors.bottomMargin: dockRoot.position === "bottom" ? dockRoot.gap : 0
                            anchors.leftMargin: dockRoot.position === "left" ? dockRoot.gap : dockRoot.position === "right" ? dockRoot.shadowMargin : 0
                            anchors.rightMargin: dockRoot.position === "right" ? dockRoot.gap : dockRoot.position === "left" ? dockRoot.shadowMargin : 0
                            color: Config.options.dock.showBackground && !SekaiTheme.active ? dockRoot.backgroundColor : "transparent"
                            border.width: SekaiTheme.active ? 0 : dockRoot.borderWidth
                            border.color: root.colorFromName(Config.options.dock.borderColor)
                            radius: Config.options.dock.radius
                            topLeftRadius: dockRoot.hug && dockRoot.position === "left" ? 0 : radius
                            bottomLeftRadius: dockRoot.hug && (dockRoot.position === "left" || dockRoot.position === "bottom") ? 0 : radius
                            topRightRadius: dockRoot.hug && dockRoot.position === "right" ? 0 : radius
                            bottomRightRadius: dockRoot.hug && (dockRoot.position === "right" || dockRoot.position === "bottom") ? 0 : radius
                        }

                        SekaiBlock {
                            visible: SekaiTheme.active
                            x: dockVisualBackground.x
                            y: dockVisualBackground.y
                            width: dockVisualBackground.width
                            height: dockVisualBackground.height
                            cornerRadius: 26
                        }

                        RoundCorner {
                            visible: dockRoot.hug && Config.options.dock.showBackground && !SekaiTheme.active
                            anchors.right: dockRoot.vertical ? (dockRoot.position === "right" ? dockVisualBackground.right : undefined) : dockVisualBackground.left
                            anchors.bottom: dockRoot.vertical ? dockVisualBackground.top : dockVisualBackground.bottom
                            anchors.left: dockRoot.position === "left" ? dockVisualBackground.left : undefined
                            implicitSize: Appearance.rounding.screenRounding
                            color: dockRoot.backgroundColor
                            corner: dockRoot.position === "left" ? RoundCorner.CornerEnum.BottomLeft : RoundCorner.CornerEnum.BottomRight
                        }

                        RoundCorner {
                            visible: dockRoot.hug && Config.options.dock.showBackground && !SekaiTheme.active
                            anchors.left: dockRoot.vertical ? (dockRoot.position === "left" ? dockVisualBackground.left : undefined) : dockVisualBackground.right
                            anchors.bottom: dockRoot.vertical ? undefined : dockVisualBackground.bottom
                            anchors.top: dockRoot.vertical ? dockVisualBackground.bottom : undefined
                            anchors.right: dockRoot.position === "right" ? dockVisualBackground.right : undefined
                            implicitSize: Appearance.rounding.screenRounding
                            color: dockRoot.backgroundColor
                            corner: dockRoot.position === "left" ? RoundCorner.CornerEnum.TopLeft
                                : dockRoot.position === "right" ? RoundCorner.CornerEnum.TopRight
                                : RoundCorner.CornerEnum.BottomLeft
                        }

                        DockContextMenu {
                            id: dockContextMenu
                            screen: dockRoot.screen
                        }

                        GridLayout {
                            id: dockRow
                            anchors.top: dockRoot.vertical ? undefined : parent.top
                            anchors.bottom: dockRoot.vertical ? undefined : parent.bottom
                            anchors.left: dockRoot.vertical ? parent.left : undefined
                            anchors.right: dockRoot.vertical ? parent.right : undefined
                            anchors.horizontalCenter: dockRoot.vertical ? undefined : parent.horizontalCenter
                            anchors.verticalCenter: dockRoot.vertical ? parent.verticalCenter : undefined
                            columns: dockRoot.vertical ? 1 : -1
                            rowSpacing: DockStyle.padding - 2
                            columnSpacing: DockStyle.padding - 2
                            property real padding: DockStyle.padding

                            DockPinButton {
                                pinned: root.pinned
                                onToggled: root.pinned = !root.pinned
                            }

                            DockSeparator {
                                visible: Config.options.dock.showPinButton
                            }

                            DockApps {
                                id: dockApps
                                buttonPadding: dockRow.padding
                                contextMenu: dockContextMenu
                            }

                            DockSeparator {
                                visible: Config.options.dock.showMedia
                            }

                            Loader {
                                active: Config.options.dock.showMedia
                                visible: active
                                Layout.fillHeight: !DockStyle.vertical
                                Layout.fillWidth: DockStyle.vertical
                                sourceComponent: DockMedia {}
                            }

                            DockSeparator {
                                visible: Config.options.dock.showAppsButton
                            }

                            DockAppsButton {
                                onClicked: {
                                    if (Config.options.search.spotlight ?? false) {
                                        GlobalStates.spotlightMode = "apps";
                                        GlobalStates.spotlightOpen = !GlobalStates.spotlightOpen;
                                    } else {
                                        GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
