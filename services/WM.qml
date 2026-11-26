pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common

Singleton {
    id: root

    readonly property string compositor: Platform.isWindows ? "windows" : detectCompositor()

    function detectCompositor() {
        const desktop = (Quickshell.env("XDG_CURRENT_DESKTOP") ?? "").toLowerCase();
        const session = (Quickshell.env("XDG_SESSION_DESKTOP") ?? "").toLowerCase();
        const combined = desktop + " " + session;

        if (combined.includes("hyprland")) return "hyprland";
        if (combined.includes("niri")) return "niri";
        if (combined.includes("sway")) return "sway";
        if (combined.includes("mango")) return "mango";
        return "unknown";
    }
}
