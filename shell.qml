//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env IIW_PROCESS=shell

// Remove two slashes below and adjust the value to change the UI scale
////@ pragma Env QT_SCALE_FACTOR=1

import "modules/common"
import "services"
import "panelFamilies"
import "modules/settings"
import "modules/common/utils"

import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    id: root
    settings.watchFiles: !Platform.isWindows || Quickshell.env("IIW_WATCH_FILES") === "1"

    // Stuff for every panel family
    ReloadPopup {}

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme()
        Hyprsunset.load()
        FirstRunExperience.load()
        if (!Platform.isWindows) {
            ConflictKiller.load()
            Cliphist.refresh()
            Updates.load()
        }
        Wallpapers.load()
        AutoTheme.load()
        VisualStyle.load()
        PeripheralBattery.load()
        if (Platform.isWindows) {
            WindowsTerminalTheme.load()
            WindowsPins.load()
            SettingsApp.load()
            WindowsIdleLock.load()
            FullscreenNotice.load()
        }
    }

    Timer {
        running: Platform.isWindows && PanelLoaderQueue.drained
        interval: 20000
        onTriggered: SelfUpdate.load()
    }

    Timer {
        running: FirstRunExperience.welcomePending
        interval: PanelLoaderQueue.drained ? 0 : 10000
        onTriggered: FirstRunExperience.launchWelcome()
    }

    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.taskbar
        property: "hoverOnly"
        value: Config.options.windowsPort.taskbarHoverOnly && !Config.options.windowsPort.nativeTaskbar
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.taskbar
        property: "alwaysHidden"
        value: ((Config.options.panelFamily === "ii" && Config.options.dock.enable)
                || Config.options.panelFamily === "waffle")
            && Config.options.windowsPort.taskbarHoverOnly
            && !Config.options.windowsPort.nativeTaskbar
    }
    Binding {
        when: Platform.isWindows && WindowsNative.ready && WindowsNative.taskbar?.suppressSnapBar !== undefined
        target: WindowsNative.taskbar
        property: "suppressSnapBar"
        value: true
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.gestures
        property: "swipeEnabled"
        value: Config.options.windowsPort.touchpadSwipe
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.gestures
        property: "moveEnabled"
        value: Config.options.windowsPort.touchpadMove
    }
    Connections {
        target: WindowsNative.gestures
        ignoreUnknownSignals: true
        function onVerticalSwiped() {
            Hyprland.dispatch("global quickshell:overviewWorkspacesToggle")
        }
        function onPinched() {
            Hyprland.dispatch("fullscreen 0")
        }
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.windowManager
        property: "removeEmptyDesktops"
        value: Config.options.windowsPort.removeEmptyDesktops
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.windowManager
        property: "windowRules"
        value: Config.options.windowsPort.windowRules
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.windowManager
        property: "dimInactive"
        value: Config.options.windowsPort.dimInactive
    }
    readonly property bool nativeTaskbarTakesOver: Platform.isWindows && Config.ready && WindowsNative.ready && Config.options.panelFamily === "ii" && Config.options.windowsPort.nativeTaskbar && Config.options.windowsPort.taskbarHoverOnly
    onNativeTaskbarTakesOverChanged: {
        if (root.nativeTaskbarTakesOver)
            Qt.callLater(() => WindowsNative.taskbar.turnOffAutoHide());
    }
    readonly property bool startupSettled: Platform.isWindows && Config.ready && WindowsNative.ready && (WindowsNative.startupGate?.settled ?? false)
    onStartupSettledChanged: {
        if (root.startupSettled)
            WindowsAutostartApps.runAtStartup();
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.desktopLayer
        property: "enabled"
        value: Config.options.windowsPort.backgroundBehindIcons
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.desktopDrop
        property: "enabled"
        value: Config.options.windowsPort.backgroundBehindIcons
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.tiling
        property: "suppressWindowShadows"
        value: true
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.tiling
        property: "enabled"
        value: Config.options.windowsPort.tiling.enable
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.tiling
        property: "gapsIn"
        value: Config.options.windowsPort.tiling.gapsIn
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.tiling
        property: "gapsOut"
        value: Config.options.windowsPort.tiling.gapsOut
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.tiling
        property: "preserveSplit"
        value: Config.options.windowsPort.tiling.preserveSplit
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.tiling
        property: "excluded"
        value: Config.options.windowsPort.tiling.excluded
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.tiling
        property: "layout"
        value: Config.options.hyprland.general.layout
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.tiling
        property: "smartSplit"
        value: Config.options.windowsPort.tiling.smartSplit
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.tiling
        property: "forceSplit"
        value: Config.options.windowsPort.tiling.forceSplit
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.tiling
        property: "defaultSplitRatio"
        value: Config.options.windowsPort.tiling.defaultSplitRatio
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.tiling
        property: "masterNewStatus"
        value: Config.options.windowsPort.tiling.master.newStatus
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.tiling
        property: "masterNewOnTop"
        value: Config.options.windowsPort.tiling.master.newOnTop
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.tiling
        property: "masterOrientation"
        value: Config.options.windowsPort.tiling.master.orientation
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.tiling
        property: "masterFactor"
        value: Config.options.windowsPort.tiling.master.mfact
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.tiling
        property: "scrollingColumnWidth"
        value: Config.options.windowsPort.tiling.scrolling.columnWidth
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.tiling
        property: "scrollingPresets"
        value: Config.options.windowsPort.tiling.scrolling.widthPresets
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.tiling
        property: "scrollingCenter"
        value: Config.options.windowsPort.tiling.scrolling.center
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.windowManager
        property: "borders"
        value: Config.options.hyprland.general.borderSize <= 0 ? "none" : Config.options.hyprland.general.borderColor.enable ? "colors" : "system"
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.windowManager
        property: "activeBorderColor"
        value: root.windowBorderColor(Config.options.hyprland.general.borderColor.activeRole, Config.options.hyprland.general.borderColor.activeOpacity)
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.windowManager
        property: "inactiveBorderColor"
        value: root.windowBorderColor(Config.options.hyprland.general.borderColor.inactiveRole, Config.options.hyprland.general.borderColor.inactiveOpacity)
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.windowManager
        property: "corners"
        value: Config.options.windowsPort.decoration.corners
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.windowManager
        property: "hideDesktopPopup"
        value: Config.options.windowsPort.hideDesktopPopup
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.windowManager
        property: "activeOpacity"
        value: Config.options.windowsPort.decoration.activeOpacity
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.windowManager
        property: "inactiveOpacity"
        value: Config.options.windowsPort.decoration.inactiveOpacity
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.windowManager
        property: "workspaceBackAndForth"
        value: Config.options.windowsPort.binds.workspaceBackAndForth
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.windowManager
        property: "warpOnChangeWorkspace"
        value: Config.options.windowsPort.cursor.warpOnChangeWorkspace
    }
    function windowBorderColor(role, opacity) {
        const c = Qt.color(Appearance.getColorFromName(role));
        const b = Appearance.m3colors.m3background;
        const a = Math.max(0, Math.min(1, opacity * c.a));
        return Qt.rgba(c.r * a + b.r * (1 - a), c.g * a + b.g * (1 - a), c.b * a + b.b * (1 - a), 1);
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.superDrag
        property: "enabled"
        value: Config.options.windowsPort.superDrag
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.superDrag
        property: "focusFollowsMouse"
        value: Config.options.windowsPort.focusFollowsMouse
    }
    Binding {
        when: Platform.isWindows && WindowsNative.ready
        target: WindowsNative.desktopLayer
        property: "aboveIcons"
        value: ["quickshell:backgroundWidgets"]
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.blur
        property: "enabled"
        value: !Config.options.windowsPort.gameMode.enable
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.blur
        property: "panelAnimations"
        value: Config.options.windowsPort.panelAnimations && Appearance.animationsEnabled
    }
    Binding {
        when: Platform.isWindows && Config.ready && WindowsNative.ready
        target: WindowsNative.blur
        property: "panelAnimationStyle"
        value: Config.options.windowsPort.panelAnimations ? Config.options.windowsPort.panelAnimationStyle : "standard"
    }

    // Panel families
    property list<string> families: ["ii", "waffle"]
    function cyclePanelFamily() {
        const currentIndex = families.indexOf(Config.options.panelFamily)
        const nextIndex = (currentIndex + 1) % families.length
        Config.options.panelFamily = families[nextIndex]
    }

    property bool lookReady: MaterialThemeLoader.ready && Translation.ready
    Timer {
        id: lookTimeout
        interval: 1500
        running: Config.ready && !root.lookReady
        onTriggered: root.lookReady = true
    }

    readonly property string wantedEnvironmentFamily: Config.options.appearance.visualStyle === "end4pc" ? "end4pc" : "ii"
    property string environmentFamily: root.wantedEnvironmentFamily
    property bool environmentSwapping: false
    property string pendingEnvironment: ""
    onWantedEnvironmentFamilyChanged: {
        if (!Config.ready || root.environmentFamily === "") {
            root.environmentFamily = root.wantedEnvironmentFamily;
            return;
        }
        if (environmentCurtain.covering && root.pendingEnvironment === "") {
            root.swapEnvironmentFamily();
            return;
        }
        environmentCurtain.environment = root.wantedEnvironmentFamily;
        root.coverApplied = false;
        environmentCurtain.shown = true;
        curtainCoverTimer.restart();
    }

    Connections {
        target: Config
        function onRequestedEnvironmentChanged() {
            const target = Config.requestedEnvironment;
            if (target === "")
                return;
            Config.requestedEnvironment = "";
            if (!Config.ready || target === Config.options.appearance.visualStyle || environmentCurtain.shown)
                return;
            root.pendingEnvironment = target;
            environmentCurtain.environment = target;
            root.coverApplied = false;
            environmentCurtain.shown = true;
            curtainCoverTimer.restart();
        }
    }

    IpcHandler {
        target: "environment"

        function switchTo(name: string): void {
            Config.requestedEnvironment = name;
        }
    }

    Binding {
        target: Config
        property: "environmentSwitchDelay"
        value: environmentCurtain.covering ? 0 : environmentCurtain.coverMs + 20
    }

    EnvironmentCurtain {
        id: environmentCurtain
    }

    Connections {
        target: environmentCurtain
        function onCovered() {
            curtainCoverTimer.stop();
            root.applyCoveredEnvironment();
        }
    }

    Timer {
        id: curtainCoverTimer
        interval: environmentCurtain.coverMs + 300
        onTriggered: root.applyCoveredEnvironment()
    }

    property bool coverApplied: false

    function applyCoveredEnvironment() {
        if (root.coverApplied || !environmentCurtain.shown)
            return;
        root.coverApplied = true;
        const pending = root.pendingEnvironment;
        if (pending !== "") {
            root.pendingEnvironment = "";
            Config.options.appearance.visualStyle = pending;
            return;
        }
        root.swapEnvironmentFamily();
    }

    function swapEnvironmentFamily() {
        root.environmentSwapping = true;
        PanelLoaderQueue.bulk = true;
        root.environmentFamily = "";
        Qt.callLater(() => {
            Config.followEnvironment();
            root.environmentFamily = root.wantedEnvironmentFamily;
            curtainQuiet.since = Date.now();
            curtainQuiet.last = Date.now();
            curtainQuiet.start();
            curtainLimitTimer.restart();
        });
    }

    Timer {
        id: curtainQuiet
        property real last: 0
        property real since: 0
        interval: 16
        repeat: true
        onTriggered: {
            const now = Date.now();
            if (now - curtainQuiet.last > 40 || !PanelLoaderQueue.drained)
                curtainQuiet.since = now;
            curtainQuiet.last = now;
            if (now - curtainQuiet.since >= 300)
                root.finishEnvironmentSwap();
        }
    }

    Timer {
        id: curtainLimitTimer
        interval: 4000
        onTriggered: root.finishEnvironmentSwap()
    }

    function finishEnvironmentSwap() {
        curtainQuiet.stop();
        curtainLimitTimer.stop();
        root.environmentSwapping = false;
        PanelLoaderQueue.bulk = false;
        environmentCurtain.shown = false;
    }

    component PanelFamilyLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        active: Config.ready && root.lookReady && Config.options.panelFamily === identifier && extraCondition
    }
    
    PanelFamilyLoader {
        identifier: "ii"
        extraCondition: root.environmentFamily === "ii"
        component: IllogicalImpulseFamily {}
    }

    PanelFamilyLoader {
        identifier: "ii"
        extraCondition: root.environmentFamily === "end4pc"
        component: End4pcFamily {}
    }

    PanelFamilyLoader {
        identifier: "waffle"
        component: WaffleFamily {}
    }

    IpcHandler {
        target: "gesture"

        function swipe(distance: real, durationMs: int): void {
            WindowsNative.gestures?.simulateSwipe(distance, durationMs)
        }

        function touchpad(enabled: bool): void {
            Config.options.windowsPort.touchpadSwipe = enabled
        }
    }

    // Shortcuts
    IpcHandler {
        target: "panelFamily"

        function cycle(): void {
            root.cyclePanelFamily()
        }
    }

    GlobalShortcut {
        name: "panelFamilyCycle"
        description: "Cycles panel family"

        onPressed: root.cyclePanelFamily()
    }

    GlobalShortcut {
        name: "screenshotFullscreen"
        description: "Copies a screenshot of the focused screen"
        onPressed: if (Platform.isWindows) ScreenshotAction.captureWindowsFullscreen(Hyprland.focusedMonitor?.name, false)
    }
    GlobalShortcut {
        name: "screenshotFullscreenSave"
        description: "Saves and copies a screenshot of the focused screen"
        onPressed: if (Platform.isWindows) ScreenshotAction.captureWindowsFullscreen(Hyprland.focusedMonitor?.name, true)
    }

    GlobalShortcut {
        name: "screenRecordFullscreen"
        description: "Records the focused screen (toggle)"
        onPressed: if (Platform.isWindows) ScreenshotAction.toggleWindowsScreenRecording(Hyprland.focusedMonitor, false)
    }
    GlobalShortcut {
        name: "screenRecordFullscreenWithSound"
        description: "Records the focused screen with sound (toggle)"
        onPressed: if (Platform.isWindows) ScreenshotAction.toggleWindowsScreenRecording(Hyprland.focusedMonitor, true, Config.options.screenRecord.microphone)
    }
}
