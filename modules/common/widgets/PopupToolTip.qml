pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    property string text: ""
    property bool extraVisibleCondition: true
    property bool alternativeVisibleCondition: false
    property bool opacityOnly: false
    property bool popupActive: false
    // Hyprland fades a popup's window in and out (fadePopups, its slow default
    // in end-4's config); Windows doesn't. With this set the tooltip's window
    // fades over these ms, and a closing one keeps fading while another shows.
    property int compositorFadeMs: 0
    property int compositorFadeInMs: compositorFadeMs
    readonly property bool keepsAlive: root.opacityOnly || root.compositorFadeMs > 0
    property real horizontalPadding: 10
    property real verticalPadding: 5
    property real horizontalMargin: horizontalPadding
    property real verticalMargin: verticalPadding
    
    function updateAnchor() {
        tooltipLoader.item?.anchor.updateAnchor();
    }

    readonly property bool internalVisibleCondition: (extraVisibleCondition && (parent.hovered === undefined || parent?.hovered)) || alternativeVisibleCondition
    property var anchorEdges: Edges.Top
    property var anchorGravity: anchorEdges

    property Item contentItem: null
    property Component defaultContentComponent: StyledToolTipContent {
        anchors.centerIn: parent
        text: root.text
        shown: false
        opacityOnly: root.opacityOnly
        horizontalPadding: root.horizontalPadding
        verticalPadding: root.verticalPadding
    }

    onInternalVisibleConditionChanged: {
        const animated = root.contentItem && "shown" in root.contentItem;
        if (!root.internalVisibleCondition) {
            if (root.compositorFadeMs > 0 && root.contentItem) {
                compositorFade.stop();
                compositorFade.from = root.contentItem.opacity;
                compositorFade.to = 0;
                compositorFade.duration = root.compositorFadeMs;
                compositorFade.start();
                return;
            }
            if (animated)
                root.contentItem.shown = false;
            if (root.opacityOnly && root.contentItem)
                dismissTimer.restart();
            return;
        }
        dismissTimer.stop();
        if (!root.contentItem)
            root.contentItem = root.defaultContentComponent.createObject(root, {
                "parent": null
            });
        if (root.keepsAlive)
            root.popupActive = true;
        if (root.compositorFadeMs > 0 && root.contentItem) {
            compositorFade.stop();
            if (!compositorFade.running && root.contentItem.opacity >= 1)
                root.contentItem.opacity = 0;
            compositorFade.from = root.contentItem.opacity;
            compositorFade.to = 1;
            compositorFade.duration = root.compositorFadeInMs;
            compositorFade.start();
        }
        if (root.contentItem && "shown" in root.contentItem) {
            Qt.callLater(() => {
                if (root.internalVisibleCondition && root.contentItem)
                    root.contentItem.shown = true;
            });
        }
    }

    NumberAnimation {
        id: compositorFade
        target: root.contentItem
        property: "opacity"
        easing.type: Easing.OutCubic
        onFinished: {
            if (compositorFade.to !== 0)
                return;
            if (root.contentItem && "shown" in root.contentItem)
                root.contentItem.shown = false;
            root.popupActive = false;
        }
    }

    Timer {
        id: dismissTimer
        interval: Appearance.animation.elementMoveFast.duration
        repeat: false
        onTriggered: root.popupActive = false
    }

    Loader {
        id: tooltipLoader
        anchors.fill: parent
        active: (root.keepsAlive ? root.popupActive : root.internalVisibleCondition)
            && root.contentItem !== null
        sourceComponent: PopupWindow {
            visible: true
            anchor {
                window: root.QsWindow.window
                item: root.parent
                edges: root.anchorEdges
                gravity: root.anchorGravity
            }
            mask: Region {
                item: null
            }

            color: "transparent"
            implicitWidth: root.contentItem.implicitWidth + root.horizontalMargin * 2
            implicitHeight: root.contentItem.implicitHeight + root.verticalMargin * 2

            data: [root.contentItem]
        }
    }
}
