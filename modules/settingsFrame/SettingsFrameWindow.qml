import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings as IiSettings
import qs.modules.settingsPc.dashboard as PcDashboard

FloatingWindow {
    id: root

    signal closeRequested

    property string tab: "environment"
    readonly property bool railOpen: Config.options.settings.environmentRailOpen
    readonly property real railWidth: 236
    readonly property bool railOverlay: root.tab === "environment" && root.pcLayout && (contentLoader.item?.fullBleedPage ?? false)

    function setRailOpen(open) {
        Config.options.settings.environmentRailOpen = open;
    }
    readonly property bool pcLayout: Config.options.appearance.settingsLayout === "end4pc"
    readonly property string currentEnvironment: Config.options.appearance.visualStyle
    readonly property bool maximized: frame.Window.window?.visibility === Window.Maximized

    readonly property var environments: [
        { value: "ii", name: "illogical-impulse", note: "end-4", icon: "auto_awesome", shape: MaterialShape.Shape.Sunny },
        { value: "end4pc", name: "end4-pC", note: "pctrade", icon: "dashboard_customize", shape: MaterialShape.Shape.Cookie9Sided }
    ].filter(environment => VisualStyle.styles.includes(environment.value))

    function hideTitleBar() {
        const backingWindow = frame.Window.window;
        if (Platform.isWindows && backingWindow && WindowsNative.windowFrame)
            WindowsNative.windowFrame.hideTitleBar(backingWindow);
    }

    function activate() {
        if (!root.visible)
            return;
        const backingWindow = frame.Window.window;
        if (backingWindow) {
            if (Platform.isWindows)
                WindowsNative.windowFrame?.ensureVisible(backingWindow);
            backingWindow.raise();
            backingWindow.requestActivate();
        }
    }

    property bool centered: false
    function center() {
        const backingWindow = frame.Window.window;
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
        root.tab = "environment";
        Qt.callLater(() => {
            const item = contentLoader.item;
            if (!item)
                return;
            if (typeof item.goToTarget === "function")
                item.goToTarget(target);
            else if (typeof item.runSearch === "function")
                item.runSearch(target?.label || target?.section || "");
        });
    }

    function pickEnvironment(value) {
        root.tab = "environment";
        if (Config.options.appearance.visualStyle !== value)
            Config.requestedEnvironment = value;
    }

    visible: true
    title: "illogical-impulse Settings"
    readonly property real screenWidth: root.screen?.width ?? 1920
    readonly property real screenHeight: root.screen?.height ?? 1080
    readonly property real fitWidth: Math.min(1320, root.screenWidth - 80)
    readonly property real fitHeight: Math.min(760, root.screenHeight - 140)
    implicitWidth: root.fitWidth
    implicitHeight: root.fitHeight
    minimumSize: Qt.size(Math.min(1050, root.implicitWidth), Math.min(600, root.implicitHeight))
    color: Appearance.colors.colUiBackground

    onClosed: root.closeRequested()
    onVisibleChanged: {
        if (!root.visible)
            return;
        root.hideTitleBar();
        Qt.callLater(root.center);
        Qt.callLater(root.activate);
    }

    Item {
        id: frame
        anchors.fill: parent

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                id: sidebar
                z: 2
                Layout.fillHeight: true
                Layout.margins: 10
                Layout.rightMargin: 0
                implicitWidth: root.railOpen ? root.railWidth : 52
                radius: Appearance.rounding.large
                color: root.railOverlay ? Qt.rgba(Appearance.colors.colLayer1.r, Appearance.colors.colLayer1.g, Appearance.colors.colLayer1.b, root.railOpen ? 0.72 : foldedArea.containsMouse ? 0.8 : 0.55)
                    : Appearance.colors.colLayer1
                clip: true

                Behavior on implicitWidth {
                    NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                }
                Behavior on color {
                    ColorAnimation { duration: 140 }
                }

                MouseArea {
                    id: foldedArea
                    property point pressPoint
                    property bool dragged: false
                    anchors.fill: parent
                    visible: !root.railOpen
                    hoverEnabled: true
                    onPressed: mouse => {
                        foldedArea.pressPoint = Qt.point(mouse.x, mouse.y);
                        foldedArea.dragged = false;
                    }
                    onPositionChanged: mouse => {
                        if (!foldedArea.pressed || foldedArea.dragged)
                            return;
                        if (Math.abs(mouse.x - foldedArea.pressPoint.x) + Math.abs(mouse.y - foldedArea.pressPoint.y) > 6) {
                            foldedArea.dragged = true;
                            frame.Window.window?.startSystemMove();
                        }
                    }
                    onClicked: {
                        if (!foldedArea.dragged)
                            root.setRailOpen(true);
                    }
                }

                ColumnLayout {
                    id: foldedColumn
                    anchors.fill: parent
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    spacing: 8
                    opacity: root.railOpen ? 0 : 1
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }

                    RailIconButton {
                        Layout.alignment: Qt.AlignHCenter
                        symbol: "chevron_right"
                        tip: Translation.tr("Show environments")
                        onClicked: root.setRailOpen(true)
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        TextMetrics {
                            id: foldedLabelMetrics
                            font: foldedLabel.font
                            text: foldedLabel.text
                        }

                        FontMetrics {
                            id: foldedLabelFont
                            font: foldedLabel.font
                        }

                        StyledText {
                            id: foldedLabel
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: foldedLabel.height / 2 - (foldedLabelFont.ascent + foldedLabelMetrics.tightBoundingRect.y + foldedLabelMetrics.tightBoundingRect.height / 2)
                            rotation: -90
                            text: Translation.tr("Environments").toUpperCase()
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.DemiBold
                            font.letterSpacing: 2
                            color: Appearance.colors.colSubtext
                            opacity: foldedArea.containsMouse ? 1 : 0.7
                        }
                    }

                    RailIconButton {
                        Layout.alignment: Qt.AlignHCenter
                        visible: Platform.isWindows
                        symbol: "public"
                        selected: root.tab === "windows"
                        tip: Translation.tr("Global")
                        onClicked: root.tab = root.tab === "windows" ? "environment" : "windows"
                    }

                    RailIconButton {
                        Layout.alignment: Qt.AlignHCenter
                        symbol: "close"
                        tip: Translation.tr("Close")
                        onClicked: root.closeRequested()
                    }
                }

                MouseArea {
                    enabled: root.railOpen
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 60
                    onPressed: frame.Window.window?.startSystemMove()
                    onDoubleClicked: {
                        const backingWindow = frame.Window.window;
                        if (!backingWindow)
                            return;
                        if (backingWindow.visibility === Window.Maximized)
                            backingWindow.showNormal();
                        else
                            backingWindow.showMaximized();
                    }
                }

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 12
                    width: root.railWidth - 24
                    spacing: 6
                    opacity: root.railOpen ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        Layout.bottomMargin: 14
                        spacing: 10

                        MaterialShapeWrappedMaterialSymbol {
                            shape: MaterialShape.Shape.Cookie7Sided
                            text: "settings"
                            iconSize: 20
                            fill: 1
                            padding: 8
                            color: Appearance.colors.colPrimary
                            colSymbol: Appearance.colors.colOnPrimary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: -2

                            StyledText {
                                text: Translation.tr("Settings")
                                font.pixelSize: Appearance.font.pixelSize.larger
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnLayer1
                            }

                            StyledText {
                                text: "ii-windows"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }

                        RailIconButton {
                            small: true
                            symbol: "close"
                            tip: Translation.tr("Close")
                            onClicked: root.closeRequested()
                        }

                        RailIconButton {
                            small: true
                            symbol: "chevron_left"
                            tip: Translation.tr("Hide environments")
                            onClicked: root.setRailOpen(false)
                        }
                    }

                    StyledText {
                        Layout.leftMargin: 6
                        text: Translation.tr("Environments").toUpperCase()
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.5
                        color: Appearance.colors.colSubtext
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 6
                        Layout.rightMargin: 6
                        Layout.bottomMargin: 4
                        text: Translation.tr("Each environment keeps its own settings")
                        wrapMode: Text.WordWrap
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        opacity: 0.8
                    }

                    Repeater {
                        model: root.environments

                        delegate: EnvironmentCard {
                            required property var modelData
                            environment: modelData
                            selected: root.tab === "environment" && root.currentEnvironment === modelData.value
                            active: root.currentEnvironment === modelData.value
                            onClicked: root.pickEnvironment(modelData.value)
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    RippleButton {
                        id: globalCard
                        visible: Platform.isWindows
                        Layout.fillWidth: true
                        implicitHeight: 72
                        buttonRadius: Appearance.rounding.large
                        toggled: root.tab === "windows"
                        colBackground: Appearance.colors.colLayer2
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        colBackgroundToggled: Appearance.colors.colPrimaryContainer
                        colBackgroundToggledHover: Appearance.colors.colPrimaryContainerHover
                        onClicked: root.tab = "windows"

                        contentItem: RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            MaterialShapeWrappedMaterialSymbol {
                                shape: MaterialShape.Shape.Cookie9Sided
                                text: "public"
                                iconSize: 22
                                fill: 1
                                padding: 9
                                color: globalCard.toggled ? Appearance.colors.colPrimary : Appearance.colors.colTertiaryContainer
                                colSymbol: globalCard.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnTertiaryContainer
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: -2

                                StyledText {
                                    text: Translation.tr("Global")
                                    font.pixelSize: Appearance.font.pixelSize.large
                                    font.weight: Font.DemiBold
                                    color: globalCard.toggled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: Translation.tr("All environments")
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                }
                            }

                            MaterialSymbol {
                                text: "chevron_right"
                                iconSize: Appearance.font.pixelSize.larger
                                color: globalCard.toggled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                            }
                        }
                    }
                }
            }

            Loader {
                id: contentLoader
                Layout.fillWidth: true
                Layout.leftMargin: root.railOverlay ? -(sidebar.width + 10) : 0
                Layout.fillHeight: true
                focus: true
                sourceComponent: root.tab === "windows" && Platform.isWindows ? windowsPage
                    : root.pcLayout ? pcDashboardContent
                    : iiContent
                onLoaded: Qt.callLater(() => contentLoader.item?.forceActiveFocus())
            }
        }
    }

    component RailIconButton: RippleButton {
        id: railIconButton
        property string symbol: ""
        property string tip: ""
        property bool small: false
        property bool selected: false

        implicitWidth: railIconButton.small ? 30 : 36
        implicitHeight: railIconButton.small ? 30 : 36
        buttonRadius: Appearance.rounding.full
        toggled: railIconButton.selected
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer1Hover
        colBackgroundToggled: Appearance.colors.colPrimaryContainer
        colBackgroundToggledHover: Appearance.colors.colPrimaryContainerHover

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            text: railIconButton.symbol
            iconSize: railIconButton.small ? Appearance.font.pixelSize.large : Appearance.font.pixelSize.larger
            fill: railIconButton.selected ? 1 : 0
            color: railIconButton.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
        }

        StyledToolTip {
            text: railIconButton.tip
        }
    }

    component EnvironmentCard: RippleButton {
        id: environmentCard
        property var environment: ({})
        property bool selected: false
        property bool active: false

        Layout.fillWidth: true
        implicitHeight: 58
        buttonRadius: Appearance.rounding.normal
        toggled: environmentCard.selected
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer1Hover
        colBackgroundToggled: Appearance.colors.colSecondaryContainer
        colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover

        contentItem: RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 10
            spacing: 10

            MaterialShapeWrappedMaterialSymbol {
                shape: environmentCard.environment.shape
                text: environmentCard.environment.icon
                iconSize: 18
                fill: environmentCard.active ? 1 : 0
                padding: 8
                color: environmentCard.active ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
                colSymbol: environmentCard.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2

                StyledText {
                    Layout.fillWidth: true
                    text: environmentCard.environment.name
                    elide: Text.ElideRight
                    font.weight: environmentCard.selected || environmentCard.active ? Font.DemiBold : Font.Normal
                    color: environmentCard.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("by %1").arg(environmentCard.environment.note)
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }
            }

            Rectangle {
                visible: environmentCard.active
                implicitHeight: 20
                implicitWidth: activeLabel.implicitWidth + 14
                radius: height / 2
                color: Appearance.colors.colPrimary

                StyledText {
                    id: activeLabel
                    anchors.centerIn: parent
                    text: Translation.tr("Active")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnPrimary
                }
            }
        }
    }

    Component {
        id: windowsPage
        WindowsSettingsPage {
            onCloseRequested: root.closeRequested()
        }
    }

    Component {
        id: iiContent
        IiSettings.SettingsContent {
            windowControls: false
            onCloseRequested: root.closeRequested()
        }
    }

    Component {
        id: pcDashboardContent
        PcDashboard.SettingsPcDashboardContent {
            leftInset: root.railOverlay ? sidebar.width + 10 : 0
            onCloseRequested: root.closeRequested()
        }
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
            onPressed: frame.Window.window?.startSystemResize(modelData.edges)
        }
    }
}
