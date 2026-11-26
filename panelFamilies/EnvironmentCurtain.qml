import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Scope {
    id: root

    property bool shown: false
    property bool covering: false
    property string environment: ""
    readonly property int armMs: 400
    readonly property int warmFrames: 3
    property int presented: 0
    property bool fullyCovered: false
    signal covered()

    function markCovered() {
        if (root.fullyCovered || !root.covering)
            return;
        root.fullyCovered = true;
        root.covered();
    }
    readonly property int fadeInMs: 160
    readonly property int fadeOutMs: 380
    readonly property int coverMs: root.armMs + root.fadeInMs

    function notePresented() {
        if (!root.shown || root.covering)
            return;
        root.presented++;
        if (root.presented >= root.warmFrames) {
            armTimer.stop();
            root.covering = true;
        }
    }

    onShownChanged: {
        root.fullyCovered = false;
        if (root.shown) {
            root.presented = 0;
            armTimer.restart();
        } else {
            armTimer.stop();
            root.covering = false;
        }
    }

    Timer {
        id: armTimer
        interval: root.armMs
        onTriggered: root.covering = true
    }

    readonly property var environments: ({
        "ii": { name: "illogical-impulse", note: "end-4", icon: "auto_awesome", shape: MaterialShape.Shape.Sunny },
        "end4pc": { name: "end4-pC", note: "pctrade", icon: "dashboard_customize", shape: MaterialShape.Shape.Cookie9Sided }
    })
    readonly property var current: root.environments[root.environment] ?? root.environments["ii"]

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: curtainWindow
            required property var modelData
            screen: modelData
            property real fade: root.covering ? 1 : 0
            onFadeChanged: {
                if (curtainWindow.fade >= 1)
                    root.markCovered();
            }
            visible: root.shown || curtainWindow.fade > 0
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:environmentCurtain"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: Appearance.m3colors.m3background

            Behavior on fade {
                NumberAnimation {
                    duration: root.covering ? root.fadeInMs : root.fadeOutMs
                    easing.type: root.covering ? Easing.OutCubic : Easing.InOutCubic
                }
            }

            Binding {
                when: curtain.Window.window !== null
                target: curtain.Window.window
                property: "opacity"
                value: curtainWindow.fade
            }

            Connections {
                target: curtain.Window.window
                function onFrameSwapped() {
                    root.notePresented();
                }
            }

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.shown
            }

            Rectangle {
                id: curtain
                anchors.fill: parent
                color: Appearance.m3colors.m3background
                opacity: 1

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 14
                    scale: root.covering ? 1 : 0.96

                    Behavior on scale {
                        NumberAnimation {
                            duration: root.covering ? root.fadeInMs : root.fadeOutMs
                            easing.type: root.covering ? Easing.OutCubic : Easing.InOutCubic
                        }
                    }

                    MaterialShapeWrappedMaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        shape: root.current.shape
                        text: root.current.icon
                        iconSize: 40
                        fill: 1
                        padding: 18
                        color: Appearance.colors.colPrimary
                        colSymbol: Appearance.colors.colOnPrimary
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 6
                        text: Translation.tr("Switching to")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colSubtext
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.current.name
                        font.pixelSize: Appearance.font.pixelSize.title * 1.4
                        font.family: Appearance.font.family.title
                        color: Appearance.colors.colOnLayer0
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("by %1").arg(root.current.note)
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }
            }
        }
    }
}
