pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell

Item {
    id: root
    property string text: ""
    property bool show: false
    property var app: null
    property var contextMenu: null

    readonly property bool previews: (Config.options.dock.showPreviews ?? true) && (root.app?.toplevels?.length ?? 0) > 0
    readonly property bool wanted: DockStyle.pcFeatures && (Config.options.dock.showTooltips ?? true)
        && root.show && root.text.length > 0
        && !(root.contextMenu?.isOpen ?? false)
        && !root.previews

    property real fade: root.wanted ? 1 : 0
    Behavior on fade {
        id: fadeBehavior
        NumberAnimation {
            duration: fadeBehavior.targetValue > 0 ? 100 : 150
            easing.type: Easing.OutCubic
        }
    }

    readonly property real gap: 6
    readonly property int awayEdge: DockStyle.position === "left" ? Edges.Right
        : DockStyle.position === "right" ? Edges.Left
        : Edges.Top

    Loader {
        active: root.fade > 0 && root.QsWindow.window !== null
        sourceComponent: PopupWindow {
            id: popup
            visible: true
            color: "transparent"
            mask: Region {}

            property point center: Qt.point(0, 0)
            Component.onCompleted: {
                const t = root.parent;
                center = t.mapToItem(null, t.width / 2, t.height / 2);
            }

            anchor {
                window: root.QsWindow.window
                adjustment: PopupAdjustment.Slide
                rect.x: DockStyle.position === "left"
                    ? (root.QsWindow.window?.width ?? 0) - Appearance.sizes.elevationMargin + root.gap
                    : DockStyle.position === "right"
                        ? Appearance.sizes.elevationMargin - root.gap
                        : popup.center.x
                rect.y: DockStyle.vertical ? popup.center.y : DockStyle.magnifying ? 0 : Appearance.sizes.elevationMargin - root.gap
                rect.width: 1
                rect.height: 1
                edges: root.awayEdge
                gravity: root.awayEdge
            }

            implicitWidth: content.implicitWidth
            implicitHeight: content.implicitHeight

            Rectangle {
                id: content
                anchors.centerIn: parent
                implicitWidth: label.implicitWidth + 24
                implicitHeight: label.implicitHeight + 12
                radius: Appearance.rounding.small
                color: Appearance.m3colors.m3surfaceContainer
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                opacity: root.fade

                StyledText {
                    id: label
                    anchors.centerIn: parent
                    text: root.text
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer0
                }
            }
        }
    }
}
