import QtQuick
import Quickshell

import qs.modules.common

Scope {
    PanelLoader { deferred: false; extraCondition: !Config.options.bar.vertical && !(Platform.isWindows && Config.options.windowsPort.nativeTaskbar); panelSource: "../modules/end4pc/bar/Bar.qml" }
    PanelLoader { deferPriority: 2; panelSource: "../modules/end4pc/background/Background.qml" }
    PanelLoader { panelSource: "../modules/end4pc/cheatsheet/Cheatsheet.qml" }
    PanelLoader { extraCondition: Platform.isWindows; panelSource: "../modules/end4pc/keybindsEditor/KeybindsEditor.qml" }
    PanelLoader { deferPriority: 1; panelSource: "../modules/end4pc/desktopMenu/DesktopMenu.qml" }
    PanelLoader { deferPriority: 1; panelSource: "../modules/end4pc/dropover/DropShelfPanel.qml" }
    PanelLoader { extraCondition: Platform.isWindows; panelSource: "../modules/end4pc/colorPicker/ColorPicker.qml" }
    PanelLoader { deferPriority: 1; extraCondition: Config.options.dock.enable; panelSource: "../modules/end4pc/dock/Dock.qml" }
    PanelLoader { deferPriority: 2; extraCondition: Config.options.bar.showFrame; panelSource: "../modules/end4pc/frame/ScreenFrame.qml" }
    PanelLoader { deferred: Platform.isWindows && !Config.options.lock.launchOnStartup; panelSource: "../modules/end4pc/lock/Lock.qml" }
    PanelLoader { panelSource: "../modules/end4pc/equalizer/EqualizerPopup.qml" }
    PanelLoader { panelSource: "../modules/end4pc/mediaControls/MediaControls.qml" }
    PanelLoader { panelSource: "../modules/end4pc/notificationPopup/NotificationPopup.qml" }
    PanelLoader { panelSource: "../modules/end4pc/nowPlaying/NowPlaying.qml" }
    PanelLoader { panelSource: "../modules/end4pc/onScreenDisplay/OnScreenDisplay.qml" }
    PanelLoader { panelSource: "../modules/end4pc/onScreenKeyboard/OnScreenKeyboard.qml" }
    PanelLoader { panelSource: "../modules/end4pc/overlay/Overlay.qml" }
    PanelLoader { deferPriority: 1; panelSource: "../modules/end4pc/overview/Overview.qml" }
    PanelLoader { deferPriority: 1; extraCondition: Config.options.search.spotlight; panelSource: "../modules/end4pc/spotlight/Spotlight.qml" }
    PanelLoader { panelSource: "../modules/end4pc/polkit/Polkit.qml" }
    PanelLoader { panelSource: "../modules/end4pc/regionSelector/RegionSelector.qml" }
    PanelLoader { deferPriority: 1; panelSource: "../modules/end4pc/screenCorners/ScreenCorners.qml" }
    PanelLoader { panelSource: "../modules/end4pc/screenTranslator/ScreenTranslator.qml" }
    PanelLoader { panelSource: "../modules/end4pc/sessionScreen/SessionScreen.qml" }
    PanelLoader { deferPriority: 1; panelSource: "../modules/end4pc/sidebarLeft/SidebarLeft.qml" }
    PanelLoader { deferPriority: 1; panelSource: "../modules/end4pc/sidebarRight/SidebarRight.qml" }
    PanelLoader { deferred: false; extraCondition: Config.options.bar.vertical && !(Platform.isWindows && Config.options.windowsPort.nativeTaskbar); panelSource: "../modules/end4pc/verticalBar/VerticalBar.qml" }
    PanelLoader { panelSource: "../modules/end4pc/wallpaperSelector/WallpaperSelector.qml" }
}
