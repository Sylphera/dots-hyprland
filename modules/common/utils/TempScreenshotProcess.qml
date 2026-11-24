import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Item {
    id: root
    property bool running: false
    property string screenshotDir: Directories.screenshotTemp
    required property ShellScreen screen
    readonly property string requestTag: Platform.isWindows ? `-${Date.now().toString(36)}${Math.floor(Math.random() * 0xffffff).toString(36)}` : ""
    property string screenshotPath: `${screenshotDir}/image-${FileUtils.sanitizeFilename(screen?.name ?? "")}${requestTag}`
    signal exited(int exitCode, int exitStatus)

    Process {
        id: linuxProc
        running: root.running && !Platform.isWindows
        command: ["bash", "-c", `mkdir -p '${StringUtils.shellSingleQuoteEscape(root.screenshotDir)}' && grim -o '${StringUtils.shellSingleQuoteEscape(root.screen.name)}' '${StringUtils.shellSingleQuoteEscape(root.screenshotPath)}'`]
        onExited: (exitCode, exitStatus) => {
            root.running = false;
            root.exited(exitCode, exitStatus);
        }
    }

    property int windowsRequestId: -1
    property string windowsOwnedPath: ""
    property bool keepWindowsZoom: false
    property var capturedZoom: null
    property bool previewShown: false
    readonly property bool zoomed: (root.capturedZoom?.factor ?? 1) > 1

    function projectRegion(region, width, height) {
        const zoom = root.capturedZoom;
        if (!root.zoomed || width <= 0 || height <= 0)
            return region;

        const x = region.at[0] * zoom.factor + zoom.x * width / zoom.width;
        const y = region.at[1] * zoom.factor + zoom.y * height / zoom.height;
        const left = Math.max(0, x);
        const top = Math.max(0, y);
        const right = Math.min(width, x + region.size[0] * zoom.factor);
        const bottom = Math.min(height, y + region.size[1] * zoom.factor);
        if (right <= left || bottom <= top)
            return null;
        return Object.assign({}, region, { at: [left, top], size: [right - left, bottom - top] });
    }

    function finishZoomPreview() {
        const shot = WindowsNative.ready ? WindowsNative.screenshot : null;
        if (typeof shot?.finishZoomPreview === "function")
            shot.finishZoomPreview(root.windowsOwnedPath);
    }

    Connections {
        target: Platform.isWindows ? root.Window.window : null
        enabled: root.zoomed && root.previewShown
        function onFrameSwapped() {
            zoomPreviewTimer.start();
        }
    }

    Timer {
        id: zoomPreviewTimer
        interval: 50
        onTriggered: root.finishZoomPreview()
    }

    function captureWindows() {
        if (!root.running) return;
        root.releaseWindows();
        const shot = WindowsNative.ready ? WindowsNative.screenshot : null;
        root.windowsOwnedPath = root.screenshotPath;
        if (shot && typeof shot.captureScreenAsync === "function") {
            if (root.keepWindowsZoom && typeof shot.freezeZoom === "function")
                shot.freezeZoom();
            const requestId = root.keepWindowsZoom && typeof shot.finishZoomPreview === "function"
                ? shot.captureScreenAsync(root.screen.name, root.windowsOwnedPath, true)
                : shot.captureScreenAsync(root.screen.name, root.windowsOwnedPath);
            root.windowsRequestId = requestId;
            if (requestId < 0) Qt.callLater(() => root.finishWindows(requestId, false));
            return;
        }
        const ok = shot ? shot.captureScreen(root.screen.name, root.windowsOwnedPath) : false;
        Qt.callLater(() => root.finishWindows(-1, ok));
    }

    function releaseWindows() {
        const shot = WindowsNative.ready ? WindowsNative.screenshot : null;
        if (root.windowsRequestId > 0 && typeof shot?.cancelCapture === "function")
            shot.cancelCapture(root.windowsRequestId);
        root.windowsRequestId = -1;
        if (root.zoomed) root.finishZoomPreview();
        const path = root.windowsOwnedPath;
        root.windowsOwnedPath = "";
        root.capturedZoom = null;
        if (path.length === 0 || !shot) return;
        if (typeof shot.discardCapture === "function") {
            shot.discardCapture(path);
            return;
        }
        shot.releaseCapture(path);
        WindowsNative.fsUtils?.removeFile(path);
    }

    function finishWindows(requestId, ok) {
        if (requestId !== root.windowsRequestId) return;
        root.windowsRequestId = -1;
        if (ok && root.keepWindowsZoom) {
            const shot = WindowsNative.screenshot;
            if (typeof shot?.captureZoom === "function")
                root.capturedZoom = shot.captureZoom(root.windowsOwnedPath);
        }
        if (!ok) console.warn("[TempScreenshotProcess] Native capture failed for", root.screen.name);
        root.running = false;
        root.exited(ok ? 0 : 1, 0);
    }

    Connections {
        target: Platform.isWindows && WindowsNative.ready ? WindowsNative.screenshot : null
        function onCaptureFinished(requestId, ok) {
            root.finishWindows(requestId, ok);
        }
    }

    onRunningChanged: {
        if (!running || !Platform.isWindows) return;
        Qt.callLater(root.captureWindows);
    }

    Component.onDestruction: {
        if (Platform.isWindows) root.releaseWindows();
    }
}
