import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings as IiSettings
import qs.modules.settingsPc as PcSettings
import qs.modules.settingsPc.dashboard as PcDashboard

FloatingWindow {
    id: root

    signal closeRequested

    property string tab: "environment"
    readonly property bool pcLayout: Config.options.appearance.settingsLayout === "end4pc"
    readonly property bool pcDashboard: Config.options.settings.style === "dashboard"
    readonly property string currentEnvironment: Config.options.appearance.visualStyle
    readonly property bool maximized: frame.Window.window?.visibility === Window.Maximized

    readonly property var environments: [
        { value: "ii", name: "illogical-impulse", note: "end-4", icon: "auto_awesome" },
        { value: "end4pc", name: "end4-pC", note: "pctrade", icon: "dashboard_customize" },
        { value: "sekaipop", name: "SekaiPop", note: "Blapples", icon: "interests" },
        { value: "nabyscape", name: "NabyScape", note: "BillyNabil", icon: "toolbar" }
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
            Config.options.appearance.visualStyle = value;
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
                Layout.fillHeight: true
                Layout.margins: 10
                Layout.rightMargin: 0
                implicitWidth: 210
                radius: Appearance.rounding.large
                color: Appearance.colors.colLayer1

                MouseArea {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 64
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
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        Layout.bottomMargin: 10
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
                    }

                    StyledText {
                        Layout.leftMargin: 6
                        text: Translation.tr("Environment")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Medium
                        color: Appearance.colors.colSubtext
                    }

                    Repeater {
                        model: root.environments

                        delegate: SidebarButton {
                            required property var modelData
                            symbol: modelData.icon
                            label: modelData.name
                            note: modelData.note
                            selected: root.tab === "environment" && root.currentEnvironment === modelData.value
                            active: root.currentEnvironment === modelData.value
                            onClicked: root.pickEnvironment(modelData.value)
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: 6
                        Layout.rightMargin: 6
                        Layout.topMargin: 4
                        Layout.bottomMargin: 4
                        implicitHeight: 1
                        color: Appearance.colors.colOutlineVariant
                    }

                    SidebarButton {
                        visible: Platform.isWindows
                        symbol: "desktop_windows"
                        label: Translation.tr("Windows")
                        note: Translation.tr("All environments")
                        selected: root.tab === "windows"
                        onClicked: root.tab = "windows"
                    }

                    SidebarButton {
                        symbol: "close"
                        label: Translation.tr("Close")
                        onClicked: root.closeRequested()
                    }
                }
            }

            Loader {
                id: contentLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                focus: true
                sourceComponent: root.tab === "windows" && Platform.isWindows ? windowsPage
                    : !root.pcLayout ? iiContent
                    : root.pcDashboard ? pcDashboardContent
                    : pcPanelContent
                onLoaded: Qt.callLater(() => contentLoader.item?.forceActiveFocus())
            }
        }
    }

    component SidebarButton: RippleButton {
        id: sidebarButton
        property string symbol: ""
        property string label: ""
        property string note: ""
        property bool selected: false
        property bool active: false

        Layout.fillWidth: true
        implicitHeight: sidebarButton.note !== "" ? 52 : 42
        buttonRadius: Appearance.rounding.normal
        toggled: sidebarButton.selected
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer1Hover
        colBackgroundToggled: Appearance.colors.colSecondaryContainer
        colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover

        contentItem: RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            MaterialSymbol {
                text: sidebarButton.symbol
                iconSize: Appearance.font.pixelSize.huge
                fill: sidebarButton.selected ? 1 : 0
                color: sidebarButton.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2

                StyledText {
                    Layout.fillWidth: true
                    text: sidebarButton.label
                    elide: Text.ElideRight
                    font.weight: sidebarButton.selected ? Font.DemiBold : Font.Normal
                    color: sidebarButton.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: sidebarButton.note !== ""
                    text: sidebarButton.note
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }
            }

            Rectangle {
                visible: sidebarButton.active
                implicitWidth: 8
                implicitHeight: 8
                radius: 4
                color: Appearance.colors.colPrimary
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
            onCloseRequested: root.closeRequested()
        }
    }

    Component {
        id: pcPanelContent
        PcSettings.SettingsPcContent {
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
