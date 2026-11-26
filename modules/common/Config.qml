pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common.functions

Singleton {
    id: root
    property string filePath: Directories.shellConfigPath
    property alias options: configOptionsJsonAdapter
    property bool ready: false
    property int readWriteDelay: 50 // milliseconds
    property bool blockWrites: false

    function setNestedValue(nestedKey, value) {
        let keys = nestedKey.split(".");
        let obj = root.options;
        let parents = [obj];

        // Traverse and collect parent objects
        for (let i = 0; i < keys.length - 1; ++i) {
            if (!obj[keys[i]] || typeof obj[keys[i]] !== "object") {
                obj[keys[i]] = {};
            }
            obj = obj[keys[i]];
            parents.push(obj);
        }

        // Convert value to correct type using JSON.parse when safe
        let convertedValue = value;
        if (typeof value === "string") {
            let trimmed = value.trim();
            if (trimmed === "true" || trimmed === "false" || !isNaN(Number(trimmed))) {
                try {
                    convertedValue = JSON.parse(trimmed);
                } catch (e) {
                    convertedValue = value;
                }
            }
        }

        obj[keys[keys.length - 1]] = convertedValue;
    }

    Timer {
        id: fileReloadTimer
        interval: root.readWriteDelay
        repeat: false
        onTriggered: {
            configFileView.reload()
        }
    }

    Timer {
        id: fileWriteTimer
        interval: root.readWriteDelay
        repeat: false
        onTriggered: {
            configFileView.writeAdapter()
        }
    }

    property string activeEnvironment: ""
    property bool switchingEnvironment: false

    function environmentFilePath(environment) {
        return `${Directories.shellConfig}/config.${environment}.json`;
    }

    function readPath(object, path) {
        let value = object;
        for (const part of path.split(".")) {
            if (value === null || typeof value !== "object" || !(part in value))
                return undefined;
            value = value[part];
        }
        return value;
    }

    function writePath(object, path, value) {
        const parts = path.split(".");
        let target = object;
        for (let i = 0; i < parts.length - 1; ++i) {
            if (target[parts[i]] === null || typeof target[parts[i]] !== "object")
                target[parts[i]] = {};
            target = target[parts[i]];
        }
        target[parts[parts.length - 1]] = JSON.parse(JSON.stringify(value));
    }

    function mergeInto(base, overlay) {
        for (const key in overlay) {
            const value = overlay[key];
            if (value !== null && typeof value === "object" && !Array.isArray(value) && base[key] !== null && typeof base[key] === "object" && !Array.isArray(base[key]))
                root.mergeInto(base[key], value);
            else
                base[key] = value;
        }
        return base;
    }

    function defaultOptions() {
        const view = defaultsViewComponent.createObject(root);
        view.writeAdapter();
        view.waitForJob();
        const defaults = JSON.parse(view.text());
        view.destroy();
        return defaults;
    }

    function readEnvironment(environment) {
        environmentReader.path = "";
        environmentReader.path = root.environmentFilePath(environment);
        const text = environmentReader.text() ?? "";
        if (text.trim() === "")
            return null;
        try {
            return JSON.parse(text);
        } catch (e) {
            console.warn("[Config] Ignoring unreadable", environmentReader.path, e);
            return null;
        }
    }

    function writeEnvironment(environment, options) {
        environmentWriter.path = root.environmentFilePath(environment);
        environmentWriter.setText(JSON.stringify(options, null, 2));
        environmentWriter.waitForJob();
    }

    function followEnvironment() {
        const style = configOptionsJsonAdapter.appearance.visualStyle;
        if (root.switchingEnvironment)
            return;
        if (root.activeEnvironment === "") {
            root.activeEnvironment = style;
            return;
        }
        if (style !== root.activeEnvironment)
            root.switchEnvironment(root.activeEnvironment, style);
    }

    function switchEnvironment(from, target) {
        root.switchingEnvironment = true;
        configFileView.writeAdapter();
        configFileView.waitForJob();
        const current = JSON.parse(configFileView.text());

        const leaving = JSON.parse(JSON.stringify(current));
        root.writePath(leaving, "appearance.visualStyle", from);
        root.writeEnvironment(from, leaving);

        const saved = root.readEnvironment(target);
        root.applyOptions(saved ? root.mergeInto(root.defaultOptions(), saved) : root.freshOptions(current, target), current, target);
    }

    function freshOptions(current, target) {
        if (target === "end4pc")
            return JSON.parse(JSON.stringify(current));
        const next = root.defaultOptions();
        for (const key of EnvironmentKeys.end4Keys) {
            const value = root.readPath(current, key);
            if (value !== undefined)
                root.writePath(next, key, value);
        }
        return next;
    }

    function applyOptions(next, current, target) {
        const shared = root.readPath(current, "windowsPort.sharedWallpaper") ? ["background.wallpaperPath", "background.thumbnailPath"] : [];
        for (const path of EnvironmentKeys.globalPaths.concat(shared)) {
            const value = root.readPath(current, path);
            if (value !== undefined)
                root.writePath(next, path, value);
        }
        root.writePath(next, "appearance.visualStyle", target);
        fileWriteTimer.stop();
        fileReloadTimer.stop();
        configFileView.setText(JSON.stringify(next, null, 2));
        configFileView.waitForJob();
        configFileView.reload();
        configFileView.waitForJob();
        fileWriteTimer.stop();
        root.activeEnvironment = target;
        Qt.callLater(() => root.switchingEnvironment = false);
    }

    function migrateToEnvironments() {
        const style = configOptionsJsonAdapter.appearance.visualStyle;
        if (style === "end4pc" || root.readEnvironment(style) || root.readEnvironment("end4pc"))
            return;
        root.switchingEnvironment = true;
        const current = JSON.parse(configFileView.text());
        const pc = JSON.parse(JSON.stringify(current));
        root.writePath(pc, "appearance.visualStyle", "end4pc");
        root.writeEnvironment("end4pc", pc);
        root.applyOptions(root.freshOptions(current, style), current, style);
    }

    Connections {
        target: configOptionsJsonAdapter.appearance
        function onVisualStyleChanged() {
            if (root.ready && !root.switchingEnvironment)
                Qt.callLater(root.followEnvironment);
        }
    }

    Component {
        id: defaultsViewComponent
        FileView {
            path: `${Directories.shellConfig}/config.defaults.json`
            preload: false
            printErrors: false
            blockWrites: true
            ConfigOptions {}
        }
    }

    FileView {
        id: environmentReader
        blockAllReads: true
        printErrors: false
    }

    FileView {
        id: environmentWriter
        preload: false
        blockWrites: true
    }

    FileView {
        id: configFileView
        path: root.filePath
        watchChanges: true
        blockWrites: root.blockWrites
        onFileChanged: fileReloadTimer.restart()
        onAdapterUpdated: fileWriteTimer.restart()
        onLoaded: {
            root.ready = true;
            if (root.activeEnvironment === "") {
                root.activeEnvironment = configOptionsJsonAdapter.appearance.visualStyle;
                Qt.callLater(root.migrateToEnvironments);
            }
        }
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                writeAdapter();
            }
        }

        ConfigOptions {
            id: configOptionsJsonAdapter
        }
    }
}
