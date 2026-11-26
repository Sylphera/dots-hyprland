pragma Singleton

import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import qs.modules.settings
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    property string query: ""

    function ensurePrefix(prefix) {
        if ([Config.options.search.prefix.action, Config.options.search.prefix.app, Config.options.search.prefix.clipboard, Config.options.search.prefix.emojis, Config.options.search.prefix.math, Config.options.search.prefix.shellCommand, Config.options.search.prefix.webSearch,].some(i => root.query.startsWith(i))) {
            root.query = prefix + root.query.slice(1);
        } else {
            root.query = prefix + root.query;
        }
    }

    // Load user action scripts from ~/.config/illogical-impulse/actions/
    // Uses FolderListModel to auto-reload when scripts are added/removed
    property var userActionsFolder: null
    onQueryChanged: {
        if (root.query !== "" && !root.userActionsFolder)
            root.loadUserActionsFolder();
        if (root.query !== "")
            nonAppResultsTimer.restart();
        root.queryOmni();
    }
    function queryOmni() {
        if (root.omniOn("enableFileSearch") && root.query.startsWith("/")) {
            fileSearchTimer.restart();
        } else if (root.omniOn("enableSpotify") && /^[pqPQ](\s+.*)?$/.test(root.query)) {
            spotifyHistoryTimer.restart();
            const songQ = root.query.replace(/^[pqPQ]\s*/, "").trim();
            if (songQ.length > 0) {
                spotifySearchTimer.restart();
            }
        } else if (root.omniOn("enableBrowserHistory") && root.query.trim().length > 0) {
            suggestionTimer.restart();
        }
    }
    function loadUserActionsFolder() {
        if (Platform.isWindows && WindowsNative.fsUtils?.classify(Directories.userActions) !== "dir")
            return;
        root.userActionsFolder = userActionsFolderComponent.createObject(root);
    }
    property var userActionScripts: {
        const userActionsFolder = root.userActionsFolder;
        if (!userActionsFolder)
            return [];
        const actions = [];
        for (let i = 0; i < userActionsFolder.count; i++) {
            const fileName = userActionsFolder.get(i, "fileName");
            const filePath = userActionsFolder.get(i, "filePath");
            if (fileName && filePath) {
                const actionName = fileName.replace(/\.[^/.]+$/, ""); // strip extension
                actions.push({
                    action: actionName,
                    execute: ((path) => (args) => {
                        Quickshell.execDetached([path, ...(args ? args.split(" ") : [])]);
                    })(FileUtils.trimFileProtocol(filePath.toString()))
                });
            }
        }
        return actions;
    }

    Component {
        id: userActionsFolderComponent
        FolderListModel {
            folder: Qt.resolvedUrl(Directories.userActions)
            showDirs: false
            showHidden: false
            sortField: FolderListModel.Name
        }
    }

    property var searchActions: [
        {
            action: "accentcolor",
            execute: args => {
                Wallpapers.setAccentColor(args != '' ? args : undefined);
            }
        },
        {
            action: "dark",
            execute: () => {
                Wallpapers.setMode(true);
            }
        },
        {
            action: "konachanwallpaper",
            execute: () => {
                RandomWallpaper.fetch("konachan");
            }
        },
        {
            action: "light",
            execute: () => {
                Wallpapers.setMode(false);
            }
        },
        {
            action: "superpaste",
            execute: args => {
                if (!/^(\d+)/.test(args.trim())) {
                    // Invalid if doesn't start with numbers
                    Notifications.sendDesktop(Translation.tr("Superpaste"), Translation.tr("Usage: <tt>%1superpaste NUM_OF_ENTRIES[i]</tt>\nSupply <tt>i</tt> when you want images\nExamples:\n<tt>%1superpaste 4i</tt> for the last 4 images\n<tt>%1superpaste 7</tt> for the last 7 entries").arg(Config.options.search.prefix.action), ["-a", "Shell"]);
                    return;
                }
                const syntaxMatch = /^(?:(\d+)(i)?)/.exec(args.trim());
                const count = syntaxMatch[1] ? parseInt(syntaxMatch[1]) : 1;
                const isImage = !!syntaxMatch[2];
                Cliphist.superpaste(count, isImage);
            }
        },
        {
            action: "todo",
            execute: args => {
                Todo.addTask(args);
            }
        },
        {
            action: "unsplash",
            execute: args => {
                if (!args || args.trim().length === 0) {
                    Notifications.sendDesktop("Unsplash", Translation.tr("Usage: %1unsplash YOUR_API_KEY").arg(Config.options.search.prefix.action), ["-a", "Shell"]);
                    return;
                }
                KeyringStorage.setNestedField(["apiKeys", "unsplash"], args.trim());
                Notifications.sendDesktop("Unsplash", Translation.tr("API key saved!"), ["-a", "Shell"]);
            }
        },
        {
            action: "pexels",
            execute: args => {
                if (!args || args.trim().length === 0) {
                    Notifications.sendDesktop("Pexels", Translation.tr("Usage: %1pexels YOUR_API_KEY").arg(Config.options.search.prefix.action), ["-a", "Shell"]);
                    return;
                }
                KeyringStorage.setNestedField(["apiKeys", "pexels"], args.trim());
                Notifications.sendDesktop("Pexels", Translation.tr("API key saved!"), ["-a", "Shell"]);
            }
        },
        {
            action: "wallpaper",
            execute: () => {
                Hyprland.dispatch(`hl.dsp.global("quickshell:wallpaperSelectorToggle")`)
            }
        },
        {
            action: "wipeclipboard",
            execute: () => {
                Cliphist.wipe();
            }
        },
    ]

    // Combined built-in and user actions
    property var allActions: searchActions.concat(userActionScripts)

    property string mathResult: ""
    property string helperScriptPath: FileUtils.trimFileProtocol(Quickshell.shellPath("scripts/super_menu_helper.py"))
    readonly property var helperCommand: Platform.isWindows
        ? ["python", helperScriptPath, "--omni-history=" + (root.omniOn("enableBrowserHistory") ? "1" : "0")]
        : ["env", "QS_OMNI_HISTORY=" + (root.omniOn("enableBrowserHistory") ? "1" : "0"), "python3", helperScriptPath]

    function aiIcon(appName, systemIcon) {
        if (!Platform.isWindows)
            return { name: systemIcon, type: LauncherSearchResult.IconType.System };
        const wanted = appName.toLowerCase();
        const entry = AppSearch.list.find(app => (app.name ?? "").toLowerCase() === wanted);
        if (entry && entry.icon)
            return { name: entry.icon, type: LauncherSearchResult.IconType.System };
        return { name: "neurology", type: LauncherSearchResult.IconType.Material };
    }

    function omniOn(key) {
        if (!DockStyle.pcFeatures) return false;
        if (key === "enableSpotify" && Platform.isWindows) return false;
        return (Config.options.search.omni ?? {})[key] ?? false;
    }
    property var fileSearchResults: []
    property string lastFileQuery: ""
    property var spotifySearchResults: []
    property string lastSpotifyQuery: ""
    property var spotifyHistoryResults: []
    property string lastSpotifyHistoryQuery: ""
    property var smartSuggestions: []
    property string lastSuggestionQuery: ""


    Timer {
        id: spotifyHistoryTimer
        interval: 20
        onTriggered: {
            if (root.omniOn("enableSpotify") && /^[pqPQ](\s+.*)?$/.test(root.query)) {
                const isPlay = root.query[0].toLowerCase() === "p";
                const songQ = root.query.replace(/^[pqPQ]\s*/, "").trim();
                spotifyHistoryProc.search(isPlay, songQ);
            }
        }
    }

    Process {
        id: spotifyHistoryProc
        property string targetQuery: ""
        function search(isPlay, q) {
            spotifyHistoryProc.running = false;
            spotifyHistoryProc.targetQuery = q.toLowerCase();
            spotifyHistoryProc.command = [...root.helperCommand, "spotify-history", isPlay ? "play" : "queue", q];
            spotifyHistoryProc.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.spotifyHistoryResults = JSON.parse(data);
                    root.lastSpotifyHistoryQuery = spotifyHistoryProc.targetQuery;
                } catch (e) {
                    root.spotifyHistoryResults = [];
                }
            }
        }
    }

    Timer {
        id: suggestionTimer
        interval: 180
        onTriggered: {
            const q = root.query.trim();
            if (root.omniOn("enableBrowserHistory") && q.length > 0 && !q.startsWith("/")) {
                suggestionProc.search(q);
            }
        }
    }

    Process {
        id: suggestionProc
        property string targetQuery: ""
        function search(q) {
            suggestionProc.running = false;
            suggestionProc.targetQuery = q.toLowerCase();
            suggestionProc.command = [
                ...root.helperCommand,
                "suggestions",
                q,
                root.omniOn("enableBrowserHistory") ? "1" : "0",
                root.omniOn("enableSpotify") ? "1" : "0",
            ];
            suggestionProc.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.smartSuggestions = JSON.parse(data);
                    root.lastSuggestionQuery = suggestionProc.targetQuery;
                } catch (e) {
                    root.smartSuggestions = [];
                }
            }
        }
    }

    Timer {
        id: fileSearchTimer
        interval: 120
        onTriggered: {
            if (root.omniOn("enableFileSearch") && root.query.startsWith("/")) {
                fileSearchProc.search(root.query);
            }
        }
    }

    Process {
        id: fileSearchProc
        property string targetQuery: ""
        function search(q) {
            fileSearchProc.running = false;
            fileSearchProc.targetQuery = q;
            fileSearchProc.command = [...root.helperCommand, "file-search", q];
            fileSearchProc.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.fileSearchResults = JSON.parse(data);
                    root.lastFileQuery = fileSearchProc.targetQuery;
                } catch (e) {
                    root.fileSearchResults = [];
                }
            }
        }
    }

    Timer {
        id: spotifySearchTimer
        interval: 180
        onTriggered: {
            if (root.omniOn("enableSpotify") && /^[pqPQ]\s+.+/.test(root.query)) {
                const songQ = root.query.replace(/^[pqPQ]\s+/, "").trim();
                if (songQ.length > 0) {
                    spotifySearchProc.search(songQ);
                }
            }
        }
    }

    Process {
        id: spotifySearchProc
        property string targetSongQuery: ""
        function search(sq) {
            spotifySearchProc.running = false;
            spotifySearchProc.targetSongQuery = sq.toLowerCase();
            spotifySearchProc.command = [...root.helperCommand, "spotify-search", sq];
            spotifySearchProc.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.spotifySearchResults = JSON.parse(data);
                    root.lastSpotifyQuery = spotifySearchProc.targetSongQuery;
                } catch (e) {
                    root.spotifySearchResults = [];
                }
            }
        }
    }

    property bool clipboardWorkSafetyActive: {
        const enabled = Config.options.workSafety.enable.clipboard;
        const sensitiveNetwork = (StringUtils.stringListContainsSubstring(Network.networkName.toLowerCase(), Config.options.workSafety.triggerCondition.networkNameKeywords));
        return enabled && sensitiveNetwork;
    }

    function keybindToString(bind) {
        const modmask = bind.modmask ?? 0;
        const mods = [];
        if (modmask & (1 << 2))
            mods.push("Ctrl");
        if (modmask & (1 << 6))
            mods.push("Super");
        if (modmask & (1 << 0))
            mods.push("Shift");
        if (modmask & (1 << 3))
            mods.push("Alt");
        return [...mods, bind.key].filter(part => part).join(" + ");
    }

    function containsUnsafeLink(entry) {
        if (entry == undefined)
            return false;
        const unsafeKeywords = Config.options.workSafety.triggerCondition.linkKeywords;
        return StringUtils.stringListContainsSubstring(entry.toLowerCase(), unsafeKeywords);
    }

    Timer {
        id: nonAppResultsTimer
        interval: Config.options.search.nonAppResultDelay
        onTriggered: {
            let expr = root.query;
            if (expr.startsWith(Config.options.search.prefix.math)) {
                expr = expr.slice(Config.options.search.prefix.math.length);
            }
            mathProc.calculateExpression(expr);
        }
    }

    property bool windowsHasQalc: false
    property bool windowsQalcChecked: false
    function checkWindowsQalc() {
        const fs = WindowsNative.fsUtils;
        if (root.windowsQalcChecked || !fs) return;
        root.windowsQalcChecked = true;
        root.windowsHasQalc = !!fs.findExecutable("qalc.exe");
    }
    function evalArithmetic(expression) {
        const expr = expression.replace(/\s+/g, "").replace(/,/g, ".").replace(/×/g, "*").replace(/÷/g, "/").replace(/\^/g, "**");
        if (!/^[0-9.+\-*\/%()]+$/.test(expr) || !/[0-9]/.test(expr)) return "";
        try {
            const value = Function(`"use strict"; return (${expr});`)();
            return Number.isFinite(value) ? String(Number(value.toPrecision(12))) : "";
        } catch (e) {
            return "";
        }
    }

    Process {
        id: mathProc
        property list<string> baseCommand: ["qalc", "-t"]
        function calculateExpression(expression) {
            if (Platform.isWindows) root.checkWindowsQalc();
            const hasLetters = /[A-Za-z]/.test(expression);
            if (Platform.isWindows && (!root.windowsHasQalc || !hasLetters)) {
                root.mathResult = root.evalArithmetic(expression);
                return;
            }
            if (mathProc.running)
                mathProc.signal(9);
            mathProc.command = baseCommand.concat(expression);
            mathProc.running = true;
            mathTimeout.restart();
        }
        stdout: SplitParser {
            onRead: data => {
                if (data.trim() !== "")
                    root.mathResult = data;
            }
        }
    }

    Timer {
        id: mathTimeout
        interval: 5000
        onTriggered: {
            if (mathProc.running)
                mathProc.signal(9);
        }
    }

    readonly property var resultCache: ({
            previous: new Map(),
            next: new Map()
        })

    function reuse(key, source, make) {
        const cache = root.resultCache;
        const old = cache.previous.get(key);
        const hit = old && old.source === source ? old : {
            source: source,
            object: make()
        };
        cache.next.set(key, hit);
        return hit.object;
    }

    property list<var> results: {
        // Search results are handled here
        root.resultCache.previous = root.resultCache.next;
        root.resultCache.next = new Map();
        ////////////////// Skip? //////////////////
        if (root.query == "")
            return [];

        ///////////// Special cases ///////////////
        if (root.query.startsWith(Config.options.search.prefix.clipboard)) {
            // Clipboard
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.clipboard);
            const clipboardResults = Cliphist.fuzzyQuery(searchString).map((entry, index, array) => {
                const mightBlurImage = Cliphist.entryIsImage(entry) && root.clipboardWorkSafetyActive;
                let shouldBlurImage = mightBlurImage;
                if (mightBlurImage) {
                    shouldBlurImage = shouldBlurImage && (root.containsUnsafeLink(array[index - 1]) || root.containsUnsafeLink(array[index + 1]));
                }
                const type = `#${entry.match(/^\s*(\S+)/)?.[1] || ""}`;
                const pinned = Cliphist.isPinned(entry);
                return root.reuse(`c\u001f${pinned}\u001f${shouldBlurImage}\u001f${entry}`, entry, () => resultComp.createObject(null, {
                    rawValue: entry,
                    name: StringUtils.cleanCliphistEntry(entry),
                    verb: "",
                    type: type,
                    pinned: pinned,
                    execute: () => {
                        Cliphist.copy(entry);
                    },
                    actions: [resultComp.createObject(null, {
                            name: pinned ? Translation.tr("Unpin") : Translation.tr("Pin"),
                            iconName: pinned ? "keep_off" : "keep",
                            iconType: LauncherSearchResult.IconType.Material,
                            execute: () => {
                                Cliphist.togglePin(entry);
                            }
                        }), resultComp.createObject(null, {
                            name: Translation.tr("Copy"),
                            iconName: "content_copy",
                            iconType: LauncherSearchResult.IconType.Material,
                            execute: () => {
                                Cliphist.copy(entry);
                            }
                        }), resultComp.createObject(null, {
                            name: Translation.tr("Delete"),
                            iconName: "delete",
                            iconType: LauncherSearchResult.IconType.Material,
                            execute: () => {
                                Cliphist.deleteEntry(entry);
                            }
                        })],
                    blurImage: shouldBlurImage
                }));
            }).filter(Boolean);
            return [...clipboardResults.filter(r => r.pinned), ...clipboardResults.filter(r => !r.pinned)];
        } else if (root.query.startsWith(Config.options.search.prefix.emojis)) {
            // Clipboard
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.emojis);
            return Emojis.fuzzyQuery(searchString).map(entry => {
                const emoji = entry.match(/^\s*(\S+)/)?.[1] || "";
                return root.reuse(`e\u001f${entry}`, entry, () => resultComp.createObject(null, {
                    rawValue: entry,
                    name: entry.replace(/^\s*\S+\s+/, ""),
                    iconName: emoji,
                    iconType: LauncherSearchResult.IconType.Text,
                    verb: Translation.tr("Copy"),
                    type: Translation.tr("Emoji"),
                    execute: () => {
                        Quickshell.clipboardText = entry.match(/^\s*(\S+)/)?.[1];
                    }
                }));
            }).filter(Boolean);
        } else if (root.query.startsWith(Config.options.search.prefix.keybinds)) {
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.keybinds).toLowerCase();
            return HyprlandKeybinds.keybinds.filter(bind => {
                if (!bind.description && !bind.key)
                    return false;
                if (searchString === "")
                    return true;
                return (bind.description ?? "").toLowerCase().includes(searchString) || (bind.key ?? "").toLowerCase().includes(searchString);
            }).slice(0, 50).map(bind => {
                const keyStr = root.keybindToString(bind);
                return resultComp.createObject(null, {
                    id: `${bind.key}:${bind.modmask}:${bind.dispatcher}:${bind.arg}`,
                    name: bind.description ? `${bind.description}  ·  ${keyStr}` : keyStr,
                    verb: Translation.tr("Copy"),
                    type: Translation.tr("Keybind"),
                    fontType: LauncherSearchResult.FontType.Monospace,
                    iconName: 'keyboard_command_key',
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => {
                        Quickshell.clipboardText = keyStr;
                    }
                });
            });
        } else if (root.query.startsWith(Config.options.search.prefix.symbols)) {
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.symbols);
            return MaterialSymbolsSearch.fuzzyQuery(searchString).map(entry => {
                const symbolName = entry.split("\t")[0] ?? "";
                return root.reuse(`m\u001f${entry}`, entry, () => resultComp.createObject(null, {
                    rawValue: entry,
                    name: symbolName,
                    iconName: symbolName,
                    iconType: LauncherSearchResult.IconType.Material,
                    verb: Translation.tr("Copy"),
                    type: Translation.tr("Symbol"),
                    execute: () => {
                        Quickshell.clipboardText = symbolName;
                    }
                }));
            }).filter(Boolean);
        } else if (root.omniOn("enableAiShortcuts") && /^(?:gpt|chatgpt|claude|ai)\b/i.test(root.query.trim())) {
            // Optional AI quick-launch prefixes: gpt, chatgpt, claude, ai
            const fullTrimmed = root.query.trim();
            const firstSpace = fullTrimmed.indexOf(" ");
            const prefix = (firstSpace !== -1 ? fullTrimmed.slice(0, firstSpace) : fullTrimmed).toLowerCase();
            const prompt = firstSpace !== -1 ? fullTrimmed.slice(firstSpace + 1).trim() : "";

            if (prefix === "claude") {
                return [resultComp.createObject(null, {
                    name: prompt || "Claude",
                    comment: prompt ? Translation.tr("Ask in Claude") : Translation.tr("Open Claude"),
                    verb: Translation.tr("Open"),
                    type: Translation.tr("AI Assistant"),
                    iconName: root.aiIcon("Claude", "claude-desktop").name,
                    iconType: root.aiIcon("Claude", "claude-desktop").type,
                    execute: () => {
                        GlobalStates.overviewOpen = false;
                        if (prompt) Quickshell.clipboardText = prompt;
                        Quickshell.execDetached([...root.helperCommand, "open-claude", prompt]);
                    }
                })];
            } else if (prefix === "gpt" || prefix === "chatgpt") {
                return [resultComp.createObject(null, {
                    name: prompt || "ChatGPT",
                    comment: prompt ? Translation.tr("Ask in ChatGPT (prompt copied)") : Translation.tr("Open ChatGPT"),
                    verb: Translation.tr("Open"),
                    type: Translation.tr("AI Assistant"),
                    iconName: root.aiIcon("ChatGPT", "chatgpt").name,
                    iconType: root.aiIcon("ChatGPT", "chatgpt").type,
                    execute: () => {
                        GlobalStates.overviewOpen = false;
                        if (prompt) Quickshell.clipboardText = prompt;
                        Quickshell.execDetached([...root.helperCommand, "open-chatgpt", prompt]);
                    }
                })];
            }

            return [resultComp.createObject(null, {
                name: prompt || Translation.tr("ai [your question]"),
                comment: prompt ? Translation.tr("Send to sidebar AI chat") : Translation.tr("Open sidebar AI chat"),
                verb: Translation.tr("Ask"),
                type: Translation.tr("AI Assistant"),
                iconName: "neurology",
                iconType: LauncherSearchResult.IconType.Material,
                execute: () => {
                    GlobalStates.sidebarLeftOpen = true;
                    if (prompt) {
                        Qt.callLater(() => {
                            Ai.sendUserMessage(prompt);
                        });
                    }
                }
            })];
        } else if (root.omniOn("enableSpotify") && /^[pqPQ](\s+.*)?$/.test(root.query)) {
            // Optional Spotify Play (p <song>) or Queue (q <song>)
            const isPlay = root.query[0].toLowerCase() === "p";
            const songQuery = root.query.replace(/^[pqPQ]\s*/, "").trim();

            let historyItems = [];
            if (root.lastSpotifyHistoryQuery === songQuery.toLowerCase() && root.spotifyHistoryResults.length > 0) {
                historyItems = root.spotifyHistoryResults.map(h => {
                    return resultComp.createObject(null, {
                        name: `${isPlay ? "p" : "q"} ${h.text}`,
                        comment: (isPlay ? Translation.tr("Previously played") : Translation.tr("Previously queued")) + ` (${h.count || 1})`,
                        verb: isPlay ? Translation.tr("Play") : Translation.tr("Queue"),
                        type: Translation.tr("Spotify History"),
                        iconName: "history",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => {
                            if (h.uri) {
                                Quickshell.execDetached([...root.helperCommand, isPlay ? "spotify-play" : "spotify-queue", h.uri, h.text]);
                            } else {
                                Quickshell.execDetached([...root.helperCommand, isPlay ? "spotify-play-query" : "spotify-queue-query", h.text]);
                            }
                        }
                    });
                });
            }

            if (songQuery.length === 0) {
                const promptItem = resultComp.createObject(null, {
                    name: isPlay ? Translation.tr("Type a track to play on Spotify...") : Translation.tr("Type a track to queue on Spotify..."),
                    comment: isPlay ? Translation.tr("Example: p bohemian rhapsody") : Translation.tr("Example: q stairway to heaven"),
                    verb: isPlay ? Translation.tr("Play") : Translation.tr("Queue"),
                    type: "Spotify",
                    iconName: isPlay ? "play_circle" : "queue_music",
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => {}
                });
                return historyItems.length > 0 ? historyItems.concat([promptItem]) : [promptItem];
            }

            const directItem = resultComp.createObject(null, {
                name: songQuery,
                comment: isPlay ? Translation.tr("Search and play immediately on Spotify") : Translation.tr("Search and add to Spotify queue"),
                verb: isPlay ? Translation.tr("Play") : Translation.tr("Queue"),
                type: "Spotify",
                iconName: isPlay ? "play_circle" : "queue_music",
                iconType: LauncherSearchResult.IconType.Material,
                execute: () => {
                    Quickshell.execDetached([...root.helperCommand, isPlay ? "spotify-play-query" : "spotify-queue-query", songQuery]);
                }
            });

            if (root.lastSpotifyQuery === songQuery.toLowerCase() && root.spotifySearchResults.length > 0) {
                const trackItems = root.spotifySearchResults.map(track => {
                    return resultComp.createObject(null, {
                        name: track.display,
                        comment: (isPlay ? Translation.tr("Play on Spotify") : Translation.tr("Add to Spotify queue")) + (track.album ? ` • ${track.album}` : ""),
                        verb: isPlay ? Translation.tr("Play") : Translation.tr("Queue"),
                        type: "Spotify",
                        iconName: isPlay ? "play_circle" : "queue_music",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => {
                            Quickshell.execDetached([...root.helperCommand, isPlay ? "spotify-play" : "spotify-queue", track.uri, track.display]);
                        },
                        actions: [
                            resultComp.createObject(null, {
                                name: isPlay ? Translation.tr("Add to Queue") : Translation.tr("Play Now"),
                                iconName: isPlay ? "queue_music" : "play_arrow",
                                iconType: LauncherSearchResult.IconType.Material,
                                execute: () => {
                                    Quickshell.execDetached([...root.helperCommand, isPlay ? "spotify-queue" : "spotify-play", track.uri, track.display]);
                                }
                            })
                        ]
                    });
                });
                return historyItems.concat(trackItems).concat([directItem]);
            }

            return historyItems.concat([directItem]);
        }

        ////////////////// Init ///////////////////
        const mathResultObject = resultComp.createObject(null, {
            name: root.mathResult,
            verb: Translation.tr("Copy"),
            type: Translation.tr("Math result"),
            fontType: LauncherSearchResult.FontType.Monospace,
            iconName: 'calculate',
            iconType: LauncherSearchResult.IconType.Material,
            execute: () => {
                Quickshell.clipboardText = root.mathResult;
            }
        });
        const appResultObjects = AppSearch.fuzzyQuery(StringUtils.cleanPrefix(root.query, Config.options.search.prefix.app)).map(entry => {
            return root.reuse(`a\u001f${entry.id}`, entry, () => resultComp.createObject(null, {
                type: Translation.tr("App"),
                id: entry.id,
                name: entry.name,
                iconName: entry.icon,
                iconType: LauncherSearchResult.IconType.System,
                verb: Translation.tr("Open"),
                execute: () => {
                    if (!entry.runInTerminal || Platform.isWindows)
                        entry.execute();
                    else {
                        // Probably needs more proper escaping, but this will do for now
                        Quickshell.execDetached(["bash", '-c', `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(entry.command.join(' '))}'`]);
                    }
                },
                comment: entry.comment,
                runInTerminal: entry.runInTerminal,
                genericName: entry.genericName,
                keywords: entry.keywords,
                actions: entry.actions.map(action => {
                    return resultComp.createObject(null, {
                        name: action.name,
                        iconName: action.icon,
                        iconType: LauncherSearchResult.IconType.System,
                        execute: () => {
                            if (!action.runInTerminal || Platform.isWindows)
                                action.execute();
                            else {
                                Quickshell.execDetached(["bash", '-c', `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(action.command.join(' '))}'`]);
                            }
                        }
                    });
                })
            }));
        });
        const commandResultObject = resultComp.createObject(null, {
            name: StringUtils.cleanPrefix(root.query, Config.options.search.prefix.shellCommand).replace("file://", ""),
            verb: Translation.tr("Run"),
            type: Translation.tr("Command"),
            fontType: LauncherSearchResult.FontType.Monospace,
            iconName: 'terminal',
            iconType: LauncherSearchResult.IconType.Material,
            execute: () => {
                let cleanedCommand = root.query.replace("file://", "");
                cleanedCommand = StringUtils.cleanPrefix(cleanedCommand, Config.options.search.prefix.shellCommand);
                if (cleanedCommand.startsWith(Config.options.search.prefix.shellCommand)) {
                    cleanedCommand = cleanedCommand.slice(Config.options.search.prefix.shellCommand.length);
                }
                if (Platform.isWindows) {
                    Quickshell.execDetached(["powershell", "-NoProfile", "-Command", cleanedCommand]);
                    return;
                }
                Quickshell.execDetached(["bash", "-c", root.query.startsWith('sudo') ? `${Config.options.apps.terminal} fish -C '${cleanedCommand}'` : cleanedCommand]);
            }
        });
        const webSearchResultObject = resultComp.createObject(null, {
            name: StringUtils.cleanPrefix(root.query, Config.options.search.prefix.webSearch),
            verb: Translation.tr("Search"),
            type: Translation.tr("Web search"),
            iconName: 'travel_explore',
            iconType: LauncherSearchResult.IconType.Material,
            execute: () => {
                let query = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.webSearch);
                let url = Config.options.search.engineBaseUrl + encodeURIComponent(query);
                for (let site of Config.options.search.excludedSites) {
                    url += encodeURIComponent(` -site:${site}`);
                }
                Qt.openUrlExternally(url);
            }
        });
        const settingsEntries = Config.options.appearance.settingsLayout === "end4pc" ? SettingsSearchIndex.search(root.query, 8) : [];
        const settingsResults = settingsEntries.map(entry => {
            const breadcrumb = entry.kind === "page" ? Translation.tr("Settings") : [entry.pageName, entry.kind === "option" ? entry.section : "", entry.kind === "option" ? entry.subsection : ""].filter(part => part).join(" › ");
            return resultComp.createObject(null, {
                name: entry.label,
                comment: breadcrumb,
                verb: Translation.tr("Go"),
                type: [Translation.tr("Settings"), entry.pageName, entry.kind === "option" ? entry.section : "", entry.kind === "option" ? entry.subsection : ""].filter(part => part).join(" • "),
                iconName: entry.icon,
                iconType: LauncherSearchResult.IconType.Material,
                execute: () => {
                    root.query = "";
                    SettingsApp.openAt(entry.pageId, entry.kind === "page" ? "" : entry.label, entry.section, entry.subsection);
                }
            });
        });
        const launcherActionObjects = root.allActions.map(action => {
            const actionString = `${Config.options.search.prefix.action}${action.action}`;
            if (actionString.startsWith(root.query) || root.query.startsWith(actionString)) {
                return resultComp.createObject(null, {
                    name: root.query.startsWith(actionString) ? root.query : actionString,
                    verb: Translation.tr("Run"),
                    type: Translation.tr("Action"),
                    iconName: 'settings_suggest',
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => {
                        action.execute(root.query.split(" ").slice(1).join(" "));
                    }
                });
            }
            return null;
        }).filter(Boolean);

        //////// File & Folder Search with "/" /////////
        if (root.omniOn("enableFileSearch") && root.query.startsWith("/")) {
            let fileItems = [];
            if (root.lastFileQuery === root.query && root.fileSearchResults.length > 0) {
                fileItems = root.fileSearchResults.map(item => {
                    return resultComp.createObject(null, {
                        name: item.path,
                        comment: item.comment,
                        verb: Translation.tr(item.verb),
                        type: item.is_dir ? Translation.tr("Folder") : Translation.tr("File"),
                        iconName: item.is_dir ? "folder" : "description",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => {
                            Quickshell.execDetached([...root.helperCommand, "file-open", item.path]);
                        }
                    });
                });
            } else {
                fileItems = [resultComp.createObject(null, {
                    name: root.query,
                    comment: `${root.query} — ${Translation.tr("Open in file manager")}`,
                    verb: Translation.tr("Open"),
                    type: Translation.tr("File"),
                    iconName: "folder_open",
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => {
                        Quickshell.execDetached([...root.helperCommand, "file-open", root.query]);
                    }
                })];
            }

            const exactActionMatch = root.allActions.some(a => {
                const actStr = `${Config.options.search.prefix.action}${a.action}`;
                return root.query === actStr || root.query.startsWith(actStr + " ");
            });

            return exactActionMatch ? launcherActionObjects.concat(fileItems) : fileItems.concat(launcherActionObjects);
        }

        //////// Direct domain / URL -> open in Default Browser /////////
        const trimmedQuery = root.query.trim();
        let domainResultObject = null;
        if (root.omniOn("enableDirectUrl")) {
            const hasScheme = /^https?:\/\//i.test(trimmedQuery);
            const domainMatch = /^(?:https?:\/\/)?(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+([a-z]{2,24})(?::\d+)?(?:[\/?#]\S*)?$/i.exec(trimmedQuery);
            const fileExtLike = ["txt", "md", "py", "js", "sh", "json", "pdf", "png", "jpg", "jpeg", "qml", "lua", "conf", "ini", "zip", "log", "csv", "yml", "yaml", "html", "css", "cpp", "java", "mp3", "mp4"];
            const isDomain = domainMatch !== null && (hasScheme || !fileExtLike.includes(domainMatch[1].toLowerCase()));
            if (isDomain) {
                const targetUrl = hasScheme ? trimmedQuery : "https://" + trimmedQuery;
                domainResultObject = resultComp.createObject(null, {
                    name: trimmedQuery,
                    comment: Translation.tr("Open directly in browser"),
                    verb: Translation.tr("Open"),
                    type: Translation.tr("Website"),
                    iconName: 'language',
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => {
                        Quickshell.execDetached([...root.helperCommand, "open-url", targetUrl]);
                    }
                });
            }
        }

        //////// Prioritized by prefix /////////
        let result = [];
        if (domainResultObject)
            result.push(domainResultObject);

        const startsWithNumber = /^\d/.test(root.query);
        const startsWithMathPrefix = root.query.startsWith(Config.options.search.prefix.math);
        const startsWithShellCommandPrefix = root.query.startsWith(Config.options.search.prefix.shellCommand);
        const startsWithWebSearchPrefix = root.query.startsWith(Config.options.search.prefix.webSearch);
        if ((startsWithNumber || startsWithMathPrefix) && root.mathResult !== "") {
            result.push(mathResultObject);
        } else if (startsWithShellCommandPrefix) {
            result.push(commandResultObject);
        } else if (startsWithWebSearchPrefix) {
            result.push(webSearchResultObject);
        }

        //////////////// Apps //////////////////
        result = result.concat(appResultObjects);

        ////////////// Settings ////////////////
        result = result.concat(settingsResults);

        ////////// Launcher actions ////////////
        result = result.concat(launcherActionObjects);

        //////// Smart Suggestions (Browser History + Launcher History) /////////
        if (root.omniOn("enableBrowserHistory") && root.lastSuggestionQuery === trimmedQuery.toLowerCase() && root.smartSuggestions.length > 0) {
            for (let i = 0; i < root.smartSuggestions.length; i++) {
                const s = root.smartSuggestions[i];
                if (s.type === "browser_url" || s.type === "url") {
                    result.push(resultComp.createObject(null, {
                        name: s.text,
                        comment: (s.data ? `${s.data} • ` : "") + `${Translation.tr("Browser history")} (${s.count || 1})`,
                        verb: Translation.tr("Open"),
                        type: Translation.tr("Website"),
                        iconName: "history",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => {
                            Quickshell.execDetached([...root.helperCommand, "open-url", s.text]);
                        }
                    }));
                } else if (root.omniOn("enableSpotify") && s.type === "spotify_play") {
                    result.push(resultComp.createObject(null, {
                        name: `p ${s.text}`,
                        comment: `${Translation.tr("Recent track")}: ${s.text} (${s.count || 1})`,
                        verb: Translation.tr("Play"),
                        type: "Spotify",
                        iconName: "play_circle",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => {
                            if (s.data) {
                                Quickshell.execDetached([...root.helperCommand, "spotify-play", s.data, s.text]);
                            } else {
                                Quickshell.execDetached([...root.helperCommand, "spotify-play-query", s.text]);
                            }
                        }
                    }));
                } else if (root.omniOn("enableSpotify") && s.type === "spotify_queue") {
                    result.push(resultComp.createObject(null, {
                        name: `q ${s.text}`,
                        comment: `${Translation.tr("Recent queued track")}: ${s.text} (${s.count || 1})`,
                        verb: Translation.tr("Queue"),
                        type: "Spotify",
                        iconName: "queue_music",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => {
                            if (s.data) {
                                Quickshell.execDetached([...root.helperCommand, "spotify-queue", s.data, s.text]);
                            } else {
                                Quickshell.execDetached([...root.helperCommand, "spotify-queue-query", s.text]);
                            }
                        }
                    }));
                } else if (s.type === "search") {
                    result.push(resultComp.createObject(null, {
                        name: s.text,
                        comment: `${Translation.tr("Recent search")}: "${s.text}" (${s.count || 1})`,
                        verb: Translation.tr("Search"),
                        type: Translation.tr("Web search"),
                        iconName: "search",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => {
                            Quickshell.execDetached([...root.helperCommand, "open-search", s.text, Config.options.search.engineBaseUrl]);
                        }
                    }));
                } else if (s.type === "command") {
                    result.push(resultComp.createObject(null, {
                        name: s.text,
                        comment: `${Translation.tr("Recent command")}: ${s.text} (${s.count || 1})`,
                        verb: Translation.tr("Run"),
                        type: Translation.tr("Command"),
                        fontType: LauncherSearchResult.FontType.Monospace,
                        iconName: "terminal",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => {
                            Quickshell.execDetached([...root.helperCommand, "run-shell", s.text]);
                        }
                    }));
                }
            }
        }

        /// Math result, command, web search ///
        if (Config.options.search.prefix.showDefaultActionsWithoutPrefix) {
            if (!startsWithShellCommandPrefix)
                result.push(commandResultObject);
            if (!startsWithNumber && !startsWithMathPrefix && (!Platform.isWindows || root.mathResult !== ""))
                result.push(mathResultObject);
            if (!startsWithWebSearchPrefix)
                result.push(webSearchResultObject);
        }

        return result;
    }

    Component {
        id: resultComp
        LauncherSearchResult {}
    }
}
