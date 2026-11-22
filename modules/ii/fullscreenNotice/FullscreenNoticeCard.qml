import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property var notice: FullscreenNotice.current
    property var shown: null
    readonly property bool open: root.notice !== null

    implicitHeight: root.shown ? card.implicitHeight + Appearance.sizes.elevationMargin + 4 : 0
    clip: true

    Behavior on implicitHeight {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    onNoticeChanged: {
        if (root.notice) {
            root.shown = root.notice;
            exitAnimation.stop();
            card.x = 0;
            enterAnimation.restart();
            countdown.begin();
        } else if (root.shown) {
            enterAnimation.stop();
            exitAnimation.restart();
        }
    }

    ParallelAnimation {
        id: enterAnimation
        NumberAnimation {
            target: card
            properties: "opacity,scale"
            from: 0
            to: 1
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
    }

    SequentialAnimation {
        id: exitAnimation
        ParallelAnimation {
            NumberAnimation {
                target: card
                property: "x"
                to: root.width + 20
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
            NumberAnimation {
                target: card
                property: "opacity"
                to: 0
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }
        ScriptAction {
            script: root.shown = null
        }
    }

    StyledRectangularShadow {
        target: card
        opacity: card.opacity
        scale: card.scale
    }

    Rectangle {
        id: card
        anchors {
            top: parent.top
            topMargin: 4
        }
        width: root.width
        implicitHeight: content.implicitHeight + 34
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer0
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
        clip: true

        opacity: 0
        scale: 0

        HoverHandler {
            id: hover
        }

        ColumnLayout {
            id: content
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 14
            }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colPrimaryContainer

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.shown?.exclusive ? "sports_esports" : "fullscreen_exit"
                        iconSize: 18
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("%1 is in fullscreen").arg(root.shown?.name ?? "")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                        wrapMode: Text.Wrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.shown?.exclusive
                            ? Translation.tr("Exclusive fullscreen: new windows stay behind it and the shell can't manage it.")
                            : Translation.tr("New windows open behind it, and the bar, dock and animations can't reach it.")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: tip.implicitHeight + 12
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer1

                RowLayout {
                    id: tip
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 10
                        rightMargin: 10
                    }
                    spacing: 6

                    StyledText {
                        Layout.fillWidth: true
                        text: root.shown?.exclusive
                            ? Translation.tr("Set windowed mode in-game and press")
                            : Translation.tr("Use windowed mode and press")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer1
                        wrapMode: Text.Wrap
                    }
                    KeyboardKey {
                        key: "Super"
                    }
                    StyledText {
                        text: "+"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer1
                    }
                    KeyboardKey {
                        key: "F"
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Item {
                    Layout.fillWidth: true
                }
                DialogButton {
                    implicitHeight: 30
                    buttonText: Translation.tr("Don't show again")
                    onClicked: FullscreenNotice.neverAgain()
                }
                DialogButton {
                    implicitHeight: 30
                    buttonText: Translation.tr("Got it")
                    colBackground: Appearance.colors.colPrimary
                    colBackgroundHover: Appearance.colors.colPrimaryHover
                    colRipple: Appearance.colors.colPrimaryActive
                    colEnabled: Appearance.colors.colOnPrimary
                    onClicked: FullscreenNotice.close()
                }
            }
        }

        Rectangle {
            anchors {
                left: parent.left
                bottom: parent.bottom
                leftMargin: card.radius
                bottomMargin: 6
            }
            height: 3
            radius: 1.5
            width: (parent.width - card.radius * 2) * countdown.remaining
            color: Appearance.colors.colPrimary
            opacity: 0.6
        }
    }

    Timer {
        id: countdown
        property real remaining: 1
        property real last: 0
        readonly property int total: 15000
        interval: 50
        repeat: true
        onTriggered: {
            const now = Date.now();
            const elapsed = now - countdown.last;
            countdown.last = now;
            if (hover.hovered)
                return;
            countdown.remaining = Math.max(0, countdown.remaining - elapsed / total);
            if (countdown.remaining <= 0) {
                countdown.stop();
                FullscreenNotice.close();
            }
        }
        function begin() {
            countdown.remaining = 1;
            countdown.last = Date.now();
            countdown.start();
        }
    }
}
