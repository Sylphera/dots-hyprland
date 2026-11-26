pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property string position: Config.options.dock.position ?? "bottom"
    readonly property bool vertical: position !== "bottom"
    readonly property bool hug: Config.options.dock.style === "hug"
    readonly property bool pcFeatures: Config.options.appearance.visualStyle === "end4pc"
    readonly property bool magnifying: pcFeatures && position === "bottom" && (Config.options.dock.magnify ?? false)
    readonly property real magnification: Math.max(1, Math.min(2.2, Config.options.dock.magnification ?? 1.2))
    readonly property real headroom: magnifying ? Math.ceil((magnification - 1) * (iconSize + 14)) + 6 : 0

    function mTop(inner, outer, alongStart) {
        return vertical ? (alongStart ?? 0) : inner;
    }
    function mBottom(inner, outer, alongEnd) {
        return vertical ? (alongEnd ?? 0) : outer;
    }
    function mLeft(inner, outer, alongStart) {
        return vertical ? (position === "left" ? outer : inner) : (alongStart ?? 0);
    }
    function mRight(inner, outer, alongEnd) {
        return vertical ? (position === "left" ? inner : outer) : (alongEnd ?? 0);
    }

    readonly property real defaultIconSize: 35
    readonly property real iconSize: Config.options.dock.iconSize
    readonly property real iconSpacing: Config.options.dock.iconSpacing
    readonly property real buttonBase: iconSize + 15
    readonly property real listSpacing: 2 + iconSpacing
    readonly property real backgroundPadding: 5
    readonly property real padding: 5
    readonly property real buttonInnerMargin: Appearance.sizes.elevationMargin - Appearance.sizes.hyprlandGapsOut
    readonly property real pinInnerMargin: 3
    readonly property real separatorInnerMargin: Appearance.sizes.elevationMargin + padding + Appearance.rounding.normal - 4
    readonly property real separatorOuterMargin: Appearance.sizes.hyprlandGapsOut + padding + Appearance.rounding.normal
    readonly property real separatorInset: Appearance.sizes.elevationMargin + padding + Appearance.rounding.normal
    readonly property real mediaLength: 240
    readonly property real windowGap: Appearance.sizes.hyprlandGapsOut
    readonly property real appsButtonInset: windowGap + padding
    readonly property real thickness: Config.options.dock.height + (iconSize - defaultIconSize) + Appearance.sizes.elevationMargin + windowGap
    readonly property real zone: thickness - Appearance.sizes.elevationMargin
}
