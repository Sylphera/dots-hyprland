import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property Component regionComponent: Component {
        Region {}
    }
    
    Loader {
        id: overlayLoader
        active: GlobalStates.overlayOpen || OverlayContext.hasPinnedWidgets
        sourceComponent: PanelWindow {
            id: overlayWindow
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:overlay"
            WlrLayershell.layer: WlrLayer.Overlay
            // Use OnDemand for pinned widgets to allow focus switching with mouse clicks
            WlrLayershell.keyboardFocus: GlobalStates.overlayOpen ? WlrKeyboardFocus.Exclusive : (OverlayContext.clickableWidgets.length > 0 ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)
            visible: true
            color: "transparent"

            mask: Region {
                item: GlobalStates.overlayOpen ? overlayContent : null
                regions: OverlayContext.clickableWidgets.map((widget) => regionComponent.createObject(this, {
                    item: widget
                }));
            }

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            HyprlandFocusGrab {
                id: grab
                windows: [overlayWindow]
                active: false
                onCleared: () => {
                    if (!active) GlobalStates.overlayOpen = false;
                }
            }

            Connections {
                target: GlobalStates
                function onOverlayOpenChanged() {
                    delayedGrabTimer.restart();
                }
            }

            Timer {
                id: delayedGrabTimer
                interval: Appearance.animation.elementMoveFast.duration
                onTriggered: {
                    grab.active = GlobalStates.overlayOpen;
                }
            }

            OverlayContent {
                id: overlayContent
                anchors.fill: parent
            }
        }
    }

    IpcHandler {
        target: "overlay"

        function toggle(): void {
            GlobalStates.overlayOpen = !GlobalStates.overlayOpen;
        }
    }

    property bool overlayShortcutDown: false
    property bool closeOnShortcutRelease: false

    function scheduleShortcutClose(): void {
        if (!closeOnShortcutRelease || overlayShortcutDown || GlobalStates.superDown)
            return;

        shortcutCloseTimer.interval = 16;
        shortcutCloseTimer.restart();
    }

    Timer {
        id: shortcutCloseTimer
        interval: 16
        onTriggered: {
            if (!root.closeOnShortcutRelease)
                return;

            root.closeOnShortcutRelease = false;
            GlobalStates.overlayOpen = false;
        }
    }

    Connections {
        enabled: Platform.isWindows
        target: GlobalStates

        function onSuperDownChanged() {
            root.scheduleShortcutClose();
        }

        function onOverlayOpenChanged() {
            if (!GlobalStates.overlayOpen)
                root.closeOnShortcutRelease = false;
        }
    }

    GlobalShortcut {
        name: "overlayToggle"
        description: "Toggles overlay"

        onPressed: {
            if (Platform.isWindows && GlobalStates.overlayOpen) {
                root.overlayShortcutDown = true;
                root.closeOnShortcutRelease = true;
                shortcutCloseTimer.interval = 350;
                shortcutCloseTimer.restart();
            } else {
                GlobalStates.overlayOpen = !GlobalStates.overlayOpen;
            }
        }

        onReleased: {
            root.overlayShortcutDown = false;
            root.scheduleShortcutClose();
        }
    }
}
