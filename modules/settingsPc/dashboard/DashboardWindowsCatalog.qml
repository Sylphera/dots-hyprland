import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common

QtObject {
    id: root

    readonly property var input: WindowsNative.inputSettings
    readonly property var power: WindowsNative.idlePower
    readonly property var tiling: Config.options.windowsPort.tiling
    readonly property var borderColorRoles: ["primary", "secondary", "tertiary", "primaryContainer", "secondaryContainer", "tertiaryContainer", "layer0Border"]

    function roleColor(name) {
        return Appearance.colors["col" + name.charAt(0).toUpperCase() + name.slice(1)] ?? Appearance.getColorFromName(name);
    }

    function nativeToggle(object, prop, fallback) {
        return {
            type: "switch",
            get: () => root[object]?.[prop] ?? fallback,
            set: v => { if (root[object] && v !== root[object][prop]) root[object][prop] = v; }
        };
    }

    function nativeSpin(object, prop, fallback, from, to, stepSize) {
        return {
            type: "spin",
            get: () => root[object]?.[prop] ?? fallback,
            set: v => { if (root[object] && v !== root[object][prop]) root[object][prop] = v; },
            from: from, to: to, stepSize: stepSize
        };
    }

    readonly property var controls: ({
        "windows:Avatar picture": {
            type: "text",
            get: () => Config.options.profile.avatarPicture,
            set: v => {
                const path = String(v).trim().replace(/^file:\/\/\/?/, "");
                Config.options.profile.avatarPicture = path;
                Config.options.profile.avatarPath = path === "" ? "" : path.substring(0, path.lastIndexOf("/"));
            }
        },
        "windows:Display name": { type: "text", get: () => Config.options.profile.displayName, set: v => { Config.options.profile.displayName = v; } },
        "windows:Hide computer name": { type: "switch", get: () => Config.options.profile.hideHostname, set: v => { Config.options.profile.hideHostname = v; } },
        "windows:Description text": {
            type: "select",
            get: () => Config.options.profile.descriptionText === "::uptime::" ? "uptime" : "distro",
            set: v => { Config.options.profile.descriptionText = v === "uptime" ? "::uptime::" : "::distro::"; },
            options: [
                { displayName: Translation.tr("Distro"), icon: "deployed_code", value: "distro" },
                { displayName: Translation.tr("Uptime"), icon: "timelapse", value: "uptime" }
            ]
        },
        "windows:Online presets": { type: "switch", get: () => Config.options.profile.onlinePresets, set: v => { Config.options.profile.onlinePresets = v; } },
        "windows:Extra background tint": { type: "switch", get: () => Config.options.appearance.extraBackgroundTint, set: v => { Config.options.appearance.extraBackgroundTint = v; } },
        "windows:UI background": {
            type: "select",
            get: () => Config.options.appearance.uiBackground,
            set: v => { Config.options.appearance.uiBackground = v; },
            options: [
                { displayName: Translation.tr("Themed"), icon: "palette", value: "themed" },
                { displayName: Translation.tr("OLED"), icon: "contrast", value: "oled" }
            ]
        },
        "windows:Automatic transparency": { type: "switch", get: () => Config.options.appearance.transparency.automatic, set: v => { Config.options.appearance.transparency.automatic = v; } },
        "windows:Background transparency": { type: "slider", get: () => Config.options.appearance.transparency.backgroundTransparency, set: v => { Config.options.appearance.transparency.backgroundTransparency = v; }, from: 0, to: 1, stopIndicatorValues: [], usePercentTooltip: true },
        "windows:Content transparency": { type: "slider", get: () => Config.options.appearance.transparency.contentTransparency, set: v => { Config.options.appearance.transparency.contentTransparency = v; }, from: 0, to: 1, stopIndicatorValues: [], usePercentTooltip: true },
        "windows:Accent color override": {
            type: "text",
            get: () => Config.options.appearance.palette.accentColor,
            set: v => {
                const value = String(v).trim();
                if (value === Config.options.appearance.palette.accentColor)
                    return;
                if (value === "")
                    Wallpapers.setAccentColor("clear");
                else if (/^#?[0-9a-fA-F]{6}$/.test(value))
                    Wallpapers.setAccentColor(value);
            }
        },
        "windows:Save screenshots to a folder": { type: "switch", get: () => Config.options.screenSnip.saveToFolder, set: v => { Config.options.screenSnip.saveToFolder = v; } },
        "windows:Spotlight search": { type: "switch", get: () => Config.options.search.spotlight, set: v => { Config.options.search.spotlight = v; } },
        "windows:Notify on low peripheral battery": { type: "switch", get: () => Config.options.battery.peripheralNotify, set: v => { Config.options.battery.peripheralNotify = v; } },
        "windows:Peripheral low warning": { type: "spin", get: () => Config.options.battery.peripheralLow, set: v => { Config.options.battery.peripheralLow = v; }, from: 0, to: 100, stepSize: 5 },
        "windows:Peripheral critical warning": { type: "spin", get: () => Config.options.battery.peripheralCritical, set: v => { Config.options.battery.peripheralCritical = v; }, from: 0, to: 100, stepSize: 5 },
        "windows:Show date": { type: "switch", get: () => Config.options.time.showDate, set: v => { Config.options.time.showDate = v; } },
        "windows:Background behind icons": { type: "switch", get: () => Config.options.windowsPort.backgroundBehindIcons, set: v => { Config.options.windowsPort.backgroundBehindIcons = v; } },
        "windows:Draw own wallpaper": { type: "switch", get: () => Config.options.windowsPort.ownWallpaper, set: v => { Config.options.windowsPort.ownWallpaper = v; } },
        "windows:Tiling": { type: "switch", get: () => Config.options.windowsPort.tiling.enable, set: v => { Config.options.windowsPort.tiling.enable = v; } },
        "windows:Tiling Layout": {
            type: "select",
            get: () => ["master", "scrolling"].includes(Config.options.hyprland.general.layout) ? Config.options.hyprland.general.layout : "dwindle",
            set: v => { Config.options.hyprland.general.layout = v; },
            options: [
                { displayName: Translation.tr("Dwindle"), icon: "browse", value: "dwindle" },
                { displayName: Translation.tr("Master"), icon: "auto_awesome_mosaic", value: "master" },
                { displayName: Translation.tr("Scrolling"), icon: "view_carousel", value: "scrolling" }
            ]
        },
        "windows:Smart split": { type: "switch", get: () => root.tiling.smartSplit, set: v => { if (v !== root.tiling.smartSplit) root.tiling.smartSplit = v; } },
        "windows:Force split side": {
            type: "select",
            get: () => root.tiling.forceSplit,
            set: v => { root.tiling.forceSplit = v; },
            options: [
                { displayName: Translation.tr("Auto"), icon: "auto_mode", value: 0 },
                { displayName: Translation.tr("Left / top"), icon: "align_horizontal_left", value: 1 },
                { displayName: Translation.tr("Right / bottom"), icon: "align_horizontal_right", value: 2 }
            ]
        },
        "windows:Default split ratio": {
            type: "spin",
            get: () => Math.round(root.tiling.defaultSplitRatio * 50),
            set: v => { if (v !== Math.round(root.tiling.defaultSplitRatio * 50)) root.tiling.defaultSplitRatio = v / 50; },
            from: 5, to: 95, stepSize: 5
        },
        "windows:New windows become": {
            type: "select",
            get: () => root.tiling.master.newStatus,
            set: v => { root.tiling.master.newStatus = v; },
            options: [
                { displayName: Translation.tr("Master"), icon: "star", value: "master" },
                { displayName: Translation.tr("Slave"), icon: "view_agenda", value: "slave" },
                { displayName: Translation.tr("Inherit"), icon: "content_copy", value: "inherit" }
            ]
        },
        "windows:New on top": { type: "switch", get: () => root.tiling.master.newOnTop, set: v => { if (v !== root.tiling.master.newOnTop) root.tiling.master.newOnTop = v; } },
        "windows:Master position": {
            type: "select",
            get: () => root.tiling.master.orientation,
            set: v => { root.tiling.master.orientation = v; },
            options: [
                { displayName: Translation.tr("Left"), icon: "align_horizontal_left", value: "left" },
                { displayName: Translation.tr("Right"), icon: "align_horizontal_right", value: "right" },
                { displayName: Translation.tr("Top"), icon: "align_vertical_top", value: "top" },
                { displayName: Translation.tr("Bottom"), icon: "align_vertical_bottom", value: "bottom" },
                { displayName: Translation.tr("Center"), icon: "align_horizontal_center", value: "center" }
            ]
        },
        "windows:Master size": {
            type: "spin",
            get: () => Math.round(root.tiling.master.mfact * 100),
            set: v => { if (v !== Math.round(root.tiling.master.mfact * 100)) root.tiling.master.mfact = v / 100; },
            from: 10, to: 90, stepSize: 5
        },
        "windows:New column width": {
            type: "select",
            get: () => root.tiling.scrolling.columnWidth,
            set: v => { root.tiling.scrolling.columnWidth = v; },
            options: [
                { displayName: "1/3", icon: "view_week", value: 1 / 3 },
                { displayName: "1/2", icon: "width_normal", value: 0.5 },
                { displayName: "2/3", icon: "width_wide", value: 2 / 3 },
                { displayName: Translation.tr("Full width"), icon: "width_full", value: 1 }
            ]
        },
        "windows:Width presets": {
            type: "text",
            get: () => root.tiling.scrolling.widthPresets.map(v => Math.round(v * 100)).join(", "),
            set: v => {
                const items = String(v).split(",").map(s => parseFloat(s)).filter(n => n >= 10 && n <= 100);
                const shown = root.tiling.scrolling.widthPresets.map(n => Math.round(n * 100)).join(", ");
                if (items.map(n => Math.round(n)).join(", ") !== shown)
                    root.tiling.scrolling.widthPresets = items.length > 0 ? items.map(n => n / 100) : [1 / 3, 0.5, 2 / 3, 1];
            }
        },
        "windows:Center the focused column": {
            type: "select",
            get: () => root.tiling.scrolling.center,
            set: v => { root.tiling.scrolling.center = v; },
            options: [
                { displayName: Translation.tr("When it doesn't fit"), icon: "fit_screen", value: "overflow" },
                { displayName: Translation.tr("Always"), icon: "align_horizontal_center", value: "always" },
                { displayName: Translation.tr("Never"), icon: "align_horizontal_left", value: "never" }
            ]
        },
        "windows:Window borders": {
            type: "select",
            get: () => Config.options.hyprland.general.borderSize <= 0 ? "none" : Config.options.hyprland.general.borderColor.enable ? "colors" : "system",
            set: v => {
                Config.options.hyprland.general.borderSize = v === "none" ? 0 : Math.max(1, Config.options.hyprland.general.borderSize);
                Config.options.hyprland.general.borderColor.enable = v === "colors";
            },
            options: [
                { displayName: Translation.tr("System"), icon: "desktop_windows", value: "system" },
                { displayName: Translation.tr("Palette"), icon: "palette", value: "colors" },
                { displayName: Translation.tr("None"), icon: "block", value: "none" }
            ]
        },
        "windows:Window corners": {
            type: "select",
            get: () => Config.options.windowsPort.decoration.corners,
            set: v => { Config.options.windowsPort.decoration.corners = v; },
            options: [
                { displayName: Translation.tr("Default"), icon: "settings_backup_restore", value: "default" },
                { displayName: Translation.tr("Rounded"), icon: "rounded_corner", value: "round" },
                { displayName: Translation.tr("Slightly rounded"), icon: "crop_square", value: "roundSmall" },
                { displayName: Translation.tr("Square"), icon: "square", value: "square" }
            ]
        },
        "windows:Active border": {
            type: "select",
            get: () => Config.options.hyprland.general.borderColor.activeRole,
            set: v => { Config.options.hyprland.general.borderColor.activeRole = v; },
            get options() { return root.borderColorRoles.map(name => ({ value: name, color: root.roleColor(name) })); }
        },
        "windows:Active border opacity": {
            type: "spin",
            get: () => Math.round(Config.options.hyprland.general.borderColor.activeOpacity * 100),
            set: v => { if (v !== Math.round(Config.options.hyprland.general.borderColor.activeOpacity * 100)) Config.options.hyprland.general.borderColor.activeOpacity = v / 100; },
            from: 0, to: 100, stepSize: 5
        },
        "windows:Inactive border": {
            type: "select",
            get: () => Config.options.hyprland.general.borderColor.inactiveRole,
            set: v => { Config.options.hyprland.general.borderColor.inactiveRole = v; },
            get options() { return root.borderColorRoles.map(name => ({ value: name, color: root.roleColor(name) })); }
        },
        "windows:Inactive border opacity": {
            type: "spin",
            get: () => Math.round(Config.options.hyprland.general.borderColor.inactiveOpacity * 100),
            set: v => { if (v !== Math.round(Config.options.hyprland.general.borderColor.inactiveOpacity * 100)) Config.options.hyprland.general.borderColor.inactiveOpacity = v / 100; },
            from: 0, to: 100, stepSize: 5
        },
        "windows:Focused window opacity": {
            type: "spin",
            get: () => Math.round(Config.options.windowsPort.decoration.activeOpacity * 100),
            set: v => { if (v !== Math.round(Config.options.windowsPort.decoration.activeOpacity * 100)) Config.options.windowsPort.decoration.activeOpacity = v / 100; },
            from: 10, to: 100, stepSize: 5
        },
        "windows:Other windows opacity": {
            type: "spin",
            get: () => Math.round(Config.options.windowsPort.decoration.inactiveOpacity * 100),
            set: v => { if (v !== Math.round(Config.options.windowsPort.decoration.inactiveOpacity * 100)) Config.options.windowsPort.decoration.inactiveOpacity = v / 100; },
            from: 10, to: 100, stepSize: 5
        },
        "windows:Hide the desktop switch popup": { type: "switch", get: () => Config.options.windowsPort.hideDesktopPopup, set: v => { Config.options.windowsPort.hideDesktopPopup = v; } },
        "windows:Workspace back and forth": { type: "switch", get: () => Config.options.windowsPort.binds.workspaceBackAndForth, set: v => { if (v !== Config.options.windowsPort.binds.workspaceBackAndForth) Config.options.windowsPort.binds.workspaceBackAndForth = v; } },
        "windows:Move cursor to the new workspace": {
            type: "switch",
            get: () => Config.options.windowsPort.cursor.warpOnChangeWorkspace !== 0,
            set: v => { const mode = v ? 1 : 0; if (mode !== Config.options.windowsPort.cursor.warpOnChangeWorkspace) Config.options.windowsPort.cursor.warpOnChangeWorkspace = mode; }
        },
        "windows:Repeat delay": {
            type: "select",
            get: () => root.input?.keyboardRepeatDelay ?? 0,
            set: v => { if (root.input) root.input.keyboardRepeatDelay = v; },
            options: [
                { displayName: Translation.tr("Short"), icon: "bolt", value: 0 },
                { displayName: Translation.tr("Medium-short"), icon: "timer", value: 1 },
                { displayName: Translation.tr("Medium-long"), icon: "av_timer", value: 2 },
                { displayName: Translation.tr("Long"), icon: "hourglass_empty", value: 3 }
            ]
        },
        "windows:Repeat rate": nativeSpin("input", "keyboardRepeatRate", 0, 0, 31, 1),
        "windows:Numlock by default": nativeToggle("input", "numLockOnAtSignIn", false),
        "windows:Keyboard layout": {
            type: "select",
            get: () => WindowsNative.keyboard?.currentLayoutCode ?? "",
            set: v => { if (WindowsNative.keyboard) WindowsNative.keyboard.activateLayout(v); },
            get options() { return (WindowsNative.keyboard?.layoutCodes ?? []).map(code => ({ displayName: code, value: code })); }
        },
        "windows:Pointer speed": nativeSpin("input", "pointerSpeed", 10, 1, 20, 1),
        "windows:Enhance pointer precision": nativeToggle("input", "enhancePointerPrecision", false),
        "windows:Swap mouse buttons": nativeToggle("input", "leftHanded", false),
        "windows:Hide pointer while typing": nativeToggle("input", "hidePointerWhileTyping", false),
        "windows:Wheel scroll lines": nativeSpin("input", "wheelScrollLines", 3, 1, 100, 1),
        "windows:Focus follows mouse": nativeToggle("input", "focusFollowsMouse", false),
        "windows:Raise window on focus": nativeToggle("input", "raiseOnFocus", false),
        "windows:Delay before raising": nativeSpin("input", "focusFollowsMouseDelayMs", 0, 0, 5000, 50),
        "windows:Touchpad": nativeToggle("input", "touchpadEnabled", true),
        "windows:Tap to click": nativeToggle("input", "touchpadTapToClick", true),
        "windows:Natural scrolling": nativeToggle("input", "touchpadNaturalScroll", false),
        "windows:Touchpad sensitivity": {
            type: "select",
            get: () => root.input?.touchpadSensitivity ?? 2,
            set: v => { if (root.input) root.input.touchpadSensitivity = v; },
            options: [
                { displayName: Translation.tr("Most sensitive"), icon: "touch_app", value: 0 },
                { displayName: Translation.tr("High sensitivity"), icon: "ads_click", value: 1 },
                { displayName: Translation.tr("Medium sensitivity"), icon: "mouse", value: 2 },
                { displayName: Translation.tr("Low sensitivity"), icon: "front_hand", value: 3 },
                { displayName: Translation.tr("Least sensitive"), icon: "pan_tool", value: 4 }
            ]
        },
        "windows:Cursor scheme": {
            type: "select",
            get: () => root.input?.cursorSchemeName ?? "",
            set: v => { if (root.input) root.input.setCursorScheme(v); },
            get options() { return (root.input?.cursorSchemeNames ?? []).map((name, i) => ({ displayName: root.input?.cursorSchemeLabels[i] ?? name, value: name })); }
        },
        "windows:Cursor size": nativeSpin("input", "cursorSize", 1, 1, 15, 1),
        "windows:Lock after inactivity": {
            type: "switch",
            get: () => Config.options.windowsPort.idle.lock > 0,
            set: v => {
                if (v && Config.options.windowsPort.idle.lock <= 0)
                    Config.options.windowsPort.idle.lock = 300;
                else if (!v && Config.options.windowsPort.idle.lock > 0)
                    Config.options.windowsPort.idle.lock = 0;
            }
        },
        "windows:Lock after": {
            type: "spin",
            get: () => Math.max(1, Math.round(Config.options.windowsPort.idle.lock / 60)),
            set: v => { if (Config.options.windowsPort.idle.lock > 0 && v * 60 !== Config.options.windowsPort.idle.lock) Config.options.windowsPort.idle.lock = v * 60; },
            from: 1, to: 999, stepSize: 1
        },
        "windows:Screen off plugged in": nativeSpin("power", "screenOffAcMinutes", 0, 0, 999, 1),
        "windows:Sleep plugged in": nativeSpin("power", "sleepAcMinutes", 0, 0, 999, 1),
        "windows:Screen off on battery": nativeSpin("power", "screenOffDcMinutes", 0, 0, 999, 1),
        "windows:Sleep on battery": nativeSpin("power", "sleepDcMinutes", 0, 0, 999, 1),
        "windows:Panel animations": { type: "switch", get: () => Config.options.windowsPort.panelAnimations, set: v => { Config.options.windowsPort.panelAnimations = v; } },
        "windows:Animation style": {
            type: "select",
            get: () => Config.options.windowsPort.panelAnimationStyle,
            set: v => { Config.options.windowsPort.panelAnimationStyle = v; },
            options: [
                { displayName: Translation.tr("Standard"), icon: "animation", value: "standard" },
                { displayName: Translation.tr("Expressive"), icon: "auto_awesome", value: "expressive" }
            ]
        },
        "windows:Menu and tooltip animations": nativeToggle("input", "clientAreaAnimations", true),
        "windows:Minimize and maximize animations": nativeToggle("input", "minimizeRestoreAnimations", true)
    })

    readonly property var sections: [
        {
            page: Translation.tr("Windows"), title: Translation.tr("Displays"), icon: "monitor", when: "windows", cards: [
                { type: "embed", h: 5, key: "windows:Displays panel", embed: "WindowsDisplaysPanel.qml", title: Translation.tr("Displays"), icon: "monitor", kw: "display monitor screen resolution refresh rate orientation scale hdr sdr brightness main primary" }
            ]
        },
        {
            page: Translation.tr("Windows"), title: Translation.tr("Windows desktop"), icon: "desktop_windows", when: "windows", cards: [
                { type: "toggle", w: 2, key: "windows:Background behind icons", title: Translation.tr("Put the background behind the desktop icons"), icon: "layers", kw: "desktop icons background behind wallpaper widgets show desktop" },
                { type: "toggle", w: 2, when: "winbehindicons", key: "windows:Draw own wallpaper", title: Translation.tr("Draw ii's own wallpaper"), icon: "wallpaper", kw: "own wallpaper draw blur centered transitions parallax effects native windows" }
            ]
        },
        {
            page: Translation.tr("Windows"), title: Translation.tr("Tiling"), icon: "responsive_layout", when: "windows", cards: [
                { type: "toggle", w: 2, key: "windows:Tiling", title: Translation.tr("Windows tiling"), icon: "grid_view", kw: "tiling tile windows auto" },
                { type: "select", key: "windows:Tiling Layout", title: Translation.tr("Tiling Layout"), icon: "responsive_layout", kw: "layout dwindle master scrolling niri" }
            ]
        },
        {
            page: Translation.tr("Windows"), title: Translation.tr("Dwindle"), icon: "browse", when: "winlayoutdwindle", cards: [
                { type: "toggle", w: 2, key: "windows:Smart split", title: Translation.tr("Smart split (follow the cursor)"), icon: "smart_toy", kw: "dwindle smart split cursor" },
                { type: "spin", w: 2, key: "windows:Default split ratio", title: Translation.tr("Default split ratio (%)"), icon: "percent", kw: "dwindle split ratio" },
                { type: "select", w: 4, when: "winforcesplit", key: "windows:Force split side", title: Translation.tr("Force split side"), icon: "splitscreen", kw: "dwindle force split side" }
            ]
        },
        {
            page: Translation.tr("Windows"), title: Translation.tr("Master"), icon: "auto_awesome_mosaic", when: "winlayoutmaster", cards: [
                { type: "select", key: "windows:New windows become", title: Translation.tr("New windows become"), icon: "add_box", kw: "master new status slave inherit" },
                { type: "toggle", key: "windows:New on top", title: Translation.tr("New windows go on top of the stack"), icon: "vertical_align_top", kw: "master new top stack" },
                { type: "spin", key: "windows:Master size", title: Translation.tr("Master size"), icon: "aspect_ratio", kw: "master size mfact" },
                { type: "select", w: 4, key: "windows:Master position", title: Translation.tr("Master position"), icon: "screen_rotation", kw: "master orientation position" }
            ]
        },
        {
            page: Translation.tr("Windows"), title: Translation.tr("Scrolling"), icon: "view_carousel", when: "winlayoutscrolling", cards: [
                { type: "select", key: "windows:New column width", title: Translation.tr("New column width"), icon: "view_column", kw: "scrolling column width" },
                { type: "select", key: "windows:Center the focused column", title: Translation.tr("Center the focused column"), icon: "center_focus_strong", kw: "scrolling center column" },
                { type: "text", w: 4, key: "windows:Width presets", title: Translation.tr("Width presets"), icon: "width_normal", placeholder: "33, 50, 67, 100", kw: "scrolling width presets column" }
            ]
        },
        {
            page: Translation.tr("Windows"), title: Translation.tr("Borders and corners"), icon: "rounded_corner", when: "windwm", cards: [
                { type: "select", key: "windows:Window borders", title: Translation.tr("Window borders"), icon: "border_outer", kw: "window borders system palette none" },
                { type: "select", key: "windows:Window corners", title: Translation.tr("Window corners"), icon: "rounded_corner", kw: "window corners rounded square" }
            ]
        },
        {
            page: Translation.tr("Windows"), title: Translation.tr("Border Color Management"), icon: "border_color", when: "winbordercolors", cards: [
                { type: "swatch", w: 2, key: "windows:Active border", title: Translation.tr("Active border"), icon: "border_color", kw: "active border color" },
                { type: "swatch", w: 2, key: "windows:Inactive border", title: Translation.tr("Inactive border"), icon: "border_color", kw: "inactive border color" },
                { type: "spin", w: 2, key: "windows:Active border opacity", title: Translation.tr("Active border opacity"), icon: "opacity", kw: "active border opacity" },
                { type: "spin", w: 2, key: "windows:Inactive border opacity", title: Translation.tr("Inactive border opacity"), icon: "opacity", kw: "inactive border opacity" }
            ]
        },
        {
            page: Translation.tr("Windows"), title: Translation.tr("Window opacity"), icon: "opacity", when: "windows", cards: [
                { type: "spin", w: 2, key: "windows:Focused window opacity", title: Translation.tr("Focused window (%)"), icon: "select_window", kw: "window opacity transparent focused active" },
                { type: "spin", w: 2, key: "windows:Other windows opacity", title: Translation.tr("Other windows (%)"), icon: "opacity", kw: "window opacity transparent inactive" }
            ]
        },
        {
            page: Translation.tr("Windows"), title: Translation.tr("Workspaces"), icon: "view_carousel", when: "windows", cards: [
                { type: "toggle", w: 2, key: "windows:Hide the desktop switch popup", title: Translation.tr("Hide the desktop switch popup"), icon: "visibility_off", kw: "workspace desktop popup label hide" },
                { type: "toggle", w: 2, key: "windows:Workspace back and forth", title: Translation.tr("Switching to the current workspace goes back"), icon: "swap_horiz", kw: "workspace back and forth" },
                { type: "toggle", w: 2, key: "windows:Move cursor to the new workspace", title: Translation.tr("Move cursor to the new workspace"), icon: "ads_click", kw: "workspace cursor warp" }
            ]
        },
        {
            page: Translation.tr("Windows"), title: Translation.tr("Keyboard"), icon: "keyboard", when: "windows", cards: [
                { type: "select", w: 4, key: "windows:Repeat delay", title: Translation.tr("Repeat delay"), icon: "keyboard_return", kw: "keyboard repeat delay" },
                { type: "spin", key: "windows:Repeat rate", title: Translation.tr("Repeat rate"), icon: "speed", kw: "keyboard repeat rate" },
                { type: "toggle", key: "windows:Numlock by default", title: Translation.tr("Numlock by default"), icon: "numbers", kw: "keyboard numlock" },
                { type: "combo", key: "windows:Keyboard layout", title: Translation.tr("Keyboard layout"), icon: "keyboard", kw: "keyboard layout language" }
            ]
        },
        {
            page: Translation.tr("Windows"), title: Translation.tr("Mouse"), icon: "mouse", when: "windows", cards: [
                { type: "spin", key: "windows:Pointer speed", title: Translation.tr("Pointer speed"), icon: "speed", kw: "mouse pointer speed sensitivity" },
                { type: "toggle", key: "windows:Enhance pointer precision", title: Translation.tr("Enhance pointer precision"), icon: "ads_click", kw: "mouse acceleration precision" },
                { type: "toggle", key: "windows:Swap mouse buttons", title: Translation.tr("Swap mouse buttons (left-handed)"), icon: "front_hand", kw: "mouse left handed swap buttons" },
                { type: "toggle", key: "windows:Hide pointer while typing", title: Translation.tr("Hide pointer while typing"), icon: "keyboard_hide", kw: "mouse hide pointer typing" },
                { type: "spin", key: "windows:Wheel scroll lines", title: Translation.tr("Wheel scroll lines"), icon: "mouse", kw: "mouse wheel scroll lines" },
                { type: "toggle", key: "windows:Focus follows mouse", title: Translation.tr("Focus follows mouse"), icon: "mouse", kw: "focus follows mouse hover" },
                { type: "toggle", when: "winffm", key: "windows:Raise window on focus", title: Translation.tr("Raise window on focus"), icon: "center_focus_strong", kw: "focus follows mouse raise" },
                { type: "spin", when: "winffm", key: "windows:Delay before raising", title: Translation.tr("Delay before raising (ms)"), icon: "hourglass_empty", kw: "focus follows mouse raise delay" }
            ]
        },
        {
            page: Translation.tr("Windows"), title: Translation.tr("Touchpad"), icon: "trackpad_input", when: "wintouchpad", cards: [
                { type: "toggle", key: "windows:Touchpad", title: Translation.tr("Touchpad"), icon: "trackpad_input", kw: "touchpad enable" },
                { type: "toggle", key: "windows:Tap to click", title: Translation.tr("Tap to click"), icon: "touch_app", kw: "touchpad tap click" },
                { type: "toggle", w: 2, key: "windows:Natural scrolling", title: Translation.tr("Natural scrolling"), icon: "swap_vert", kw: "touchpad natural scrolling reverse" },
                { type: "select", w: 4, key: "windows:Touchpad sensitivity", title: Translation.tr("Sensitivity"), icon: "touch_app", kw: "touchpad sensitivity" }
            ]
        },
        {
            page: Translation.tr("Windows"), title: Translation.tr("Cursor"), icon: "mouse", when: "windows", cards: [
                { type: "combo", key: "windows:Cursor scheme", title: Translation.tr("Cursor scheme"), icon: "mouse", kw: "cursor scheme theme pointer" },
                { type: "spin", w: 2, key: "windows:Cursor size", title: Translation.tr("Cursor size"), icon: "zoom_in", kw: "cursor size pointer" }
            ]
        },
        {
            page: Translation.tr("Windows"), title: Translation.tr("Idle"), icon: "bedtime", when: "windows", cards: [
                { type: "toggle", w: 2, key: "windows:Lock after inactivity", title: Translation.tr("Lock after inactivity"), icon: "lock_clock", kw: "idle lock inactivity" },
                { type: "spin", w: 2, when: "winlock", key: "windows:Lock after", title: Translation.tr("Lock after (minutes)"), icon: "timer", kw: "idle lock minutes" },
                { type: "spin", w: 2, key: "windows:Screen off plugged in", title: Translation.tr("Turn off screen after (minutes), plugged in"), icon: "monitor", kw: "screen off display timeout power plugged" },
                { type: "spin", w: 2, key: "windows:Sleep plugged in", title: Translation.tr("Sleep after (minutes), plugged in"), icon: "bedtime", kw: "sleep suspend timeout power plugged" },
                { type: "spin", w: 2, when: "winbattery", key: "windows:Screen off on battery", title: Translation.tr("Turn off screen after (minutes), on battery"), icon: "battery_full", kw: "screen off display timeout battery" },
                { type: "spin", w: 2, when: "winbattery", key: "windows:Sleep on battery", title: Translation.tr("Sleep after (minutes), on battery"), icon: "battery_full", kw: "sleep suspend timeout battery" }
            ]
        },
        {
            page: Translation.tr("Windows"), title: Translation.tr("Autostart"), icon: "rocket_launch", when: "windows", cards: [
                { type: "embed", h: 5, key: "windows:Autostart panel", embed: "WindowsAutostartPanel.qml", title: Translation.tr("Autostart"), icon: "rocket_launch", kw: "autostart startup sign in apps launch boot task registry" }
            ]
        },
        {
            page: Translation.tr("Windows"), title: Translation.tr("Profile"), icon: "account_circle", when: "windows", cards: [
                { type: "text", w: 2, key: "windows:Avatar picture", title: Translation.tr("Avatar picture"), icon: "account_circle", placeholder: Translation.tr("Empty: Windows account picture"), kw: "profile avatar picture image photo account" },
                { type: "text", w: 2, key: "windows:Display name", title: Translation.tr("Display name"), icon: "badge", placeholder: Translation.tr("Your name"), kw: "profile name display" },
                { type: "toggle", w: 2, key: "windows:Hide computer name", title: Translation.tr("Hide computer name"), icon: "visibility_off", kw: "profile hostname computer name hide screenshots" },
                { type: "select", w: 2, key: "windows:Description text", title: Translation.tr("Description text"), icon: "short_text", kw: "profile description distro uptime" },
                { type: "toggle", w: 2, key: "windows:Online presets", title: Translation.tr("Show online presets"), icon: "cloud_download", kw: "profile online presets download" }
            ]
        },
        {
            page: Translation.tr("Windows"), title: Translation.tr("Appearance"), icon: "palette", when: "windows", cards: [
                { type: "toggle", w: 2, key: "windows:Extra background tint", title: Translation.tr("Extra background tint"), icon: "format_color_fill", kw: "appearance background tint accent panels" },
                { type: "select", w: 2, key: "windows:UI background", title: Translation.tr("UI background"), icon: "contrast", kw: "appearance ui background oled black themed" },
                { type: "toggle", w: 2, key: "windows:Automatic transparency", title: Translation.tr("Auto transparency"), icon: "auto_awesome", kw: "appearance transparency automatic wallpaper" },
                { type: "text", w: 2, key: "windows:Accent color override", title: Translation.tr("Accent color override"), icon: "colorize", placeholder: "#a7c0ff", kw: "appearance accent color hex override" },
                { type: "slider", w: 2, key: "windows:Background transparency", title: Translation.tr("Background"), icon: "opacity", kw: "appearance transparency background" },
                { type: "slider", w: 2, key: "windows:Content transparency", title: Translation.tr("Panel content"), icon: "opacity", kw: "appearance transparency content panel" },
                { type: "toggle", w: 2, key: "windows:Show date", title: Translation.tr("Show date"), icon: "date_range", kw: "date clock bar show" }
            ]
        },
        {
            page: Translation.tr("Windows"), title: Translation.tr("Bluetooth peripherals"), icon: "bluetooth", when: "windows", cards: [
                { type: "toggle", w: 2, key: "windows:Notify on low peripheral battery", title: Translation.tr("Notify on low peripheral battery"), icon: "notifications", kw: "bluetooth peripheral battery low notify mouse headphones" },
                { type: "spin", key: "windows:Peripheral low warning", title: Translation.tr("Low warning"), icon: "battery_alert", kw: "peripheral battery low warning" },
                { type: "spin", key: "windows:Peripheral critical warning", title: Translation.tr("Critical warning"), icon: "battery_0_bar", kw: "peripheral battery critical warning" }
            ]
        },
        {
            page: Translation.tr("Windows"), title: Translation.tr("Services"), icon: "settings", when: "windows", cards: [
                { type: "toggle", w: 2, key: "windows:Save screenshots to a folder", title: Translation.tr("Save screenshots to a folder"), icon: "folder_special", kw: "screenshot screen snip save folder file clipboard" },
                { type: "toggle", w: 2, key: "windows:Spotlight search", title: Translation.tr("Spotlight search"), icon: "search", kw: "spotlight search super workspaces tab" },
                { type: "toggle", w: 2, key: "services:Enable update checks", title: Translation.tr("App update checks"), icon: "deployed_code_update", kw: "winget app updates check count" },
                { type: "spin", w: 2, key: "services:Check interval (mins)", title: Translation.tr("Check interval (min)"), icon: "av_timer", kw: "winget updates check interval minutes" }
            ]
        },
        {
            page: Translation.tr("Windows"), title: Translation.tr("ii-windows"), icon: "deployed_code", when: "windows", cards: [
                { type: "embed", h: 2, key: "windows:Updates panel", embed: "WindowsUpdatesPanel.qml", title: Translation.tr("ii-windows updates"), icon: "update", kw: "update updates version preview stable patch fix self update ii-windows" },
                { type: "embed", h: 2, key: "windows:Report panel", embed: "WindowsReportPanel.qml", title: Translation.tr("Report a problem"), icon: "bug_report", kw: "report problem bug issue logs crash dump github" }
            ]
        },
        {
            page: Translation.tr("Windows"), title: Translation.tr("Animations"), icon: "animation", when: "windows", cards: [
                { type: "toggle", w: 2, key: "windows:Panel animations", title: Translation.tr("Animate panels when they open and close"), icon: "side_navigation", kw: "panel animations open close slide" },
                { type: "select", w: 2, when: "winpanelanim", key: "windows:Animation style", title: Translation.tr("Animation style"), icon: "auto_awesome", kw: "animation style standard expressive" },
                { type: "toggle", w: 2, key: "windows:Menu and tooltip animations", title: Translation.tr("Menu and tooltip animations"), icon: "check", kw: "menu tooltip animations" },
                { type: "toggle", w: 2, key: "windows:Minimize and maximize animations", title: Translation.tr("Minimize and maximize animations"), icon: "animation", kw: "minimize maximize animations" }
            ]
        }
    ]
}
