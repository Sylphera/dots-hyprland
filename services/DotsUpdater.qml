pragma Singleton

import qs
import QtQuick
import Quickshell
import qs.modules.common

Singleton {
    id: root

    function runSystemUpdate() {
        if (Platform.isWindows) {
            Quickshell.execDetached(["powershell.exe", "-NoProfile", "-Command",
                "if (Get-Command wt.exe -ErrorAction SilentlyContinue) { Start-Process wt.exe -ArgumentList 'powershell','-NoExit','-Command','winget upgrade --all' } else { Start-Process powershell.exe -ArgumentList '-NoExit','-Command','winget upgrade --all' }"]);
            return;
        }
        Quickshell.execDetached([
            "kitty", "--hold",
            "fish", "-i", "-l", "-c",
            "if type -q yay; yay -Syu --combinedupgrade=false; else if type -q paru; paru -Syu; else; sudo pacman -Syu; end"
        ]);
    }

    function runUpdateDots() {
        if (Platform.isWindows) return;
        const updateScript = `
            set -e
            DIR="$HOME/.config/quickshell"

            rm -rf "$DIR/end4-pC-tmp"
            git clone https://github.com/pctrade/end4-pC.git "$DIR/end4-pC-tmp"

            rm -rf "$DIR/end4-pC-old"
            [ -d "$DIR/end4-pC" ] && mv "$DIR/end4-pC" "$DIR/end4-pC-old"
            mv "$DIR/end4-pC-tmp" "$DIR/end4-pC"

            killall qs 2>/dev/null || true
            sleep 0.5
            setsid qs -c end4-pC >/tmp/qs.log 2>&1 < /dev/null &
            disown

            rm -rf "$DIR/end4-pC-old"
        `;
        Quickshell.execDetached(["kitty", "--hold", "bash", "-c", updateScript]);
    }
}
