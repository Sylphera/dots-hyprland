pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

/**
 * Provides some system info: distro, username.
 */
Singleton {
    id: root
    property string distroName: "Unknown"
    property string distroId: "unknown"
    property string distroIcon: "linux-symbolic"
    property string username: "user"
    property string hostname: Platform.isWindows ? (Quickshell.env("COMPUTERNAME") ?? "") : ""
    property string homeUrl: ""
    property string documentationUrl: ""
    property string supportUrl: ""
    property string bugReportUrl: ""
    property string privacyPolicyUrl: ""
    property string logo: ""
    property string desktopEnvironment: ""
    property string windowingSystem: ""

    property string cpu: ""
    property string gpu: ""
    property string shell: ""
    property string kernelVersion: ""

    function refresh() {
        if (Platform.isWindows) {
            getWindowsHardware.running = false; getWindowsHardware.running = true
            return;
        }
        getCpu.running = false;       getCpu.running = true
        getGpu.running = false;       getGpu.running = true
        getShell.running = false;     getShell.running = true
        getKernel.running = false;    getKernel.running = true
    }

    property string windowsBuild: ""
    function loadWindowsInfo() {
        const info = WindowsNative.session?.osInfo() ?? ({});
        root.distroName = [info.name ?? "Windows", info.version ?? ""].join(" ").trim();
        root.windowsBuild = info.build ?? "";
        root.distroId = "windows";
        const windows10 = parseInt(root.windowsBuild) < 22000;
        root.distroIcon = windows10 ? "windows10-symbolic" : "microsoft-symbolic";
        root.logo = windows10 ? "windows10-logo" : "windows11-logo";
        root.username = Quickshell.env("USERNAME") || "user";
        root.desktopEnvironment = "Windows";
        root.windowingSystem = "Win32";
        root.homeUrl = "https://www.microsoft.com/windows";
        root.documentationUrl = "https://support.microsoft.com/windows";
        root.supportUrl = "https://support.microsoft.com/contactus";
        root.bugReportUrl = "feedback-hub:";
        root.privacyPolicyUrl = "https://privacy.microsoft.com/privacystatement";
    }
    Connections {
        target: Platform.isWindows ? WindowsNative : null
        function onReadyChanged() {
            if (WindowsNative.ready) root.loadWindowsInfo();
        }
    }

    Timer {
        triggeredOnStart: true
        interval: 1
        running: true
        repeat: false
        onTriggered: {
            if (Platform.isWindows) {
                root.loadWindowsInfo();
                return;
            }
            getUsername.running = true
            fileOsRelease.reload()
            const textOsRelease = fileOsRelease.text()

            // Extract the friendly name (PRETTY_NAME field, fallback to NAME)
            const prettyNameMatch = textOsRelease.match(/^PRETTY_NAME=['"](.+?)['"]/m)
            const nameMatch = textOsRelease.match(/^NAME=['"](.+?)['"]/m)
            distroName = prettyNameMatch ? prettyNameMatch[1] : (nameMatch ? nameMatch[1].replace(/Linux/i, "").trim() : "Unknown")

            // Extract the ID
            const idMatch = textOsRelease.match(/^ID=['"]?(.+?)['"]?$/m)
            distroId = idMatch ? idMatch[1] : "unknown"

            // Extract additional URLs and logo
            const homeUrlMatch = textOsRelease.match(/^HOME_URL=['"](.+?)['"]/m)
            homeUrl = homeUrlMatch ? homeUrlMatch[1] : ""
            const documentationUrlMatch = textOsRelease.match(/^DOCUMENTATION_URL=['"](.+?)['"]/m)
            documentationUrl = documentationUrlMatch ? documentationUrlMatch[1] : ""
            const supportUrlMatch = textOsRelease.match(/^SUPPORT_URL=['"](.+?)['"]/m)
            supportUrl = supportUrlMatch ? supportUrlMatch[1] : ""
            const bugReportUrlMatch = textOsRelease.match(/^BUG_REPORT_URL=['"](.+?)['"]/m)
            bugReportUrl = bugReportUrlMatch ? bugReportUrlMatch[1] : ""
            const privacyPolicyUrlMatch = textOsRelease.match(/^PRIVACY_POLICY_URL=['"](.+?)['"]/m)
            privacyPolicyUrl = privacyPolicyUrlMatch ? privacyPolicyUrlMatch[1] : ""
            const logoFieldMatch = textOsRelease.match(/^LOGO=['"]?(.+?)['"]?$/m)
            logo = logoFieldMatch ? logoFieldMatch[1] : ""

            // Update the distroIcon property based on distroId
            switch (distroId) {
                case "artix":
                case "arch": distroIcon = "arch-symbolic"; break;
                case "manjaro": distroIcon = "manjaro-symbolic"; break;
                case "endeavouros": distroIcon = "endeavouros-symbolic"; break;
                case "cachyos": distroIcon = "cachyos-symbolic"; break;
                case "nixos": distroIcon = "nixos-symbolic"; break;
                case "fedora": distroIcon = "fedora-symbolic"; break;
                case "linuxmint":
                case "ubuntu":
                case "zorin":
                case "popos": distroIcon = "ubuntu-symbolic"; break;
                case "debian":
                case "raspbian":
                case "kali": distroIcon = "debian-symbolic"; break;
                case "funtoo":
                case "gentoo": distroIcon = "gentoo-symbolic"; break;
                default: distroIcon = "linux-symbolic"; break;
            }
            if (textOsRelease.toLowerCase().includes("nyarch")) {
                distroIcon = "nyarch-symbolic"
            }

            if (logo.trim().length === 0) {
                logo = distroIcon
            }

        }
    }

    Process {
        id: getWindowsHardware
        running: false
        command: ["powershell", "-NoProfile", "-WindowStyle", "Hidden", "-Command", `
            $ErrorActionPreference = 'SilentlyContinue'
            $cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
            $cards = @(Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Microsoft|Virtual|Remote' })
            $gpu = ($cards | Where-Object { $_.Name -notmatch 'Intel' } | Select-Object -First 1).Name
            if (-not $gpu) { $gpu = ($cards | Select-Object -First 1).Name }
            $nt = Get-ItemProperty 'HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion'
            $kernel = '10.0.' + $nt.CurrentBuild + '.' + $nt.UBR
            $shell = 'PowerShell'
            $terminal = Join-Path $env:LOCALAPPDATA 'Packages\\Microsoft.WindowsTerminal_8wekyb3d8bbwe\\LocalState\\settings.json'
            if (Test-Path $terminal) {
                $settings = (Get-Content -Raw $terminal) -replace '(?m)^\\s*//.*$', '' | ConvertFrom-Json
                $profile = $settings.profiles.list | Where-Object { $_.guid -eq $settings.defaultProfile } | Select-Object -First 1
                if ($profile.name) { $shell = $profile.name }
            }
            @{ cpu = "$cpu"; gpu = "$gpu"; kernel = $kernel; shell = $shell } | ConvertTo-Json -Compress
        `]
        stdout: StdioCollector {
            id: windowsHardwareCollector
            onStreamFinished: {
                try {
                    const info = JSON.parse(windowsHardwareCollector.text.trim());
                    root.cpu = (info.cpu ?? "").trim().replace("Intel(R)", "Intel®").replace("Core(TM)", "Core™")
                        .replace("CPU ", "").replace(/  +/g, " ").replace(/ @ */, " @");
                    root.gpu = (info.gpu ?? "").trim();
                    root.kernelVersion = info.kernel ?? "";
                    root.shell = info.shell ?? "";
                } catch (e) {}
            }
        }
    }

    Process {
        id: getKernel
        running: false
        command: ["uname", "-r"]
        stdout: SplitParser { onRead: data => root.kernelVersion = data.trim() }
    }

    Process {
        id: getCpu
        running: false
        command: ["bash", "-c", "grep -m1 'model name' /proc/cpuinfo | cut -d':' -f2- | sed 's/^ //' | sed 's/Intel(R)/Intel®/' | sed 's/Core(TM)/Core™/' | sed 's/CPU //' | sed 's/  */ /g' | sed 's/ @ */ @/'"]
        stdout: SplitParser { onRead: data => root.cpu = data.trim() }
    }

    Process {
        id: getGpu
        running: false
        command: ["bash", "-c", "lspci | grep -iE 'vga|3d|display' | grep -vi 'Intel Corporation' | head -1 | sed -E 's/.*: //; s/ *\\(rev [0-9a-f]+\\)//; s/.*\\[([^]]+)\\]$/\\1/'"]
        stdout: SplitParser { onRead: data => root.gpu = data.trim() }
    }

    Process {
        id: getShell
        running: false
        command: ["bash", "-c", "echo $SHELL | awk -F'/' '{print $NF}'"]
        stdout: SplitParser { onRead: data => root.shell = data.trim() }
    }

    Process {
        id: getUsername
        command: ["whoami"]
        stdout: SplitParser {
            onRead: data => {
                root.username = data.trim()
            }
        }
    }

    Process {
        id: getDesktopEnvironment
        running: !Platform.isWindows
        command: ["bash", "-c", "echo $XDG_CURRENT_DESKTOP,$WAYLAND_DISPLAY"]
        stdout: StdioCollector {
            id: deCollector
            onStreamFinished: {
                const [desktop, wayland] = deCollector.text.split(",")
                root.desktopEnvironment = desktop.trim()
                root.windowingSystem = wayland.trim().length > 0 ? "Wayland" : "X11" // Are there others? 🤔
            }
        }
    }

    FileView {
        id: fileOsRelease
        path: Platform.isWindows ? "" : "/etc/os-release"
    }

    FileView {
        path: Platform.isWindows ? "" : "/etc/hostname"
        onLoaded: root.hostname = text().trim()
    }
}