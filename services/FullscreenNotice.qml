pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell

Singleton {
    id: root

    property var current: null
    property var shownThisSession: ({})

    function load() {}

    function keyFor(appId, title) {
        return (appId || title || "").toLowerCase();
    }

    function displayName(appId, title) {
        if (title)
            return title;
        const parts = (appId || "").split(/[\\/!]/);
        const last = parts[parts.length - 1] || "";
        return last.replace(/\.exe$/i, "") || Translation.tr("This app");
    }

    function show(appId, title, exclusive) {
        const key = root.keyFor(appId, title);
        if (!key || root.shownThisSession[key])
            return;
        if (Persistent.states.fullscreenNotice.dismissed.indexOf(key) >= 0)
            return;
        root.shownThisSession[key] = true;
        root.current = {
            "key": key,
            "name": root.displayName(appId, title),
            "exclusive": exclusive
        };
    }

    function close() {
        root.current = null;
    }

    function neverAgain() {
        if (!root.current)
            return;
        const dismissed = Persistent.states.fullscreenNotice.dismissed.slice();
        if (dismissed.indexOf(root.current.key) < 0)
            dismissed.push(root.current.key);
        Persistent.states.fullscreenNotice.dismissed = dismissed;
        root.close();
    }

    Connections {
        target: Platform.isWindows ? WindowsNative.tiling : null
        ignoreUnknownSignals: true
        function onFullscreenConflict(appId, title, exclusive) {
            root.show(appId, title, exclusive);
        }
    }
}
