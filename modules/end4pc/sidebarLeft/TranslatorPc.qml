import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.end4pc.sidebarLeft.translator
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/**
 * Translator widget with the `trans` commandline tool.
 */
Item {
    id: root

    // Sizes
    property real padding: 4

    // Widgets
    property var inputField: inputCanvas.inputTextArea

    // Widget variables
    property bool translationFor: false
    property string translatedText: ""
    property list<string> languages: []

    // Options
    property string targetLanguage: Config.options.language.translator.targetLanguage
    property string sourceLanguage: Config.options.language.translator.sourceLanguage
    property string hostLanguage: targetLanguage
    readonly property string engine: {
        const configured = Config.options.language.translator.engine ?? "auto";
        return configured === "auto" ? "bing" : configured;
    }
    property bool failed: false

    // States
    property bool showLanguageSelector: false
    property bool languageSelectorTarget: false

    function showLanguageSelectorDialog(isTargetLang: bool) {
        root.languageSelectorTarget = isTargetLang;
        root.showLanguageSelector = true
    }

    function swapLanguages() {
        let temp = root.targetLanguage;
        root.targetLanguage = root.sourceLanguage;
        root.sourceLanguage = temp;
        Config.options.language.translator.targetLanguage = root.targetLanguage;
        Config.options.language.translator.sourceLanguage = root.sourceLanguage;
        translateTimer.restart();
    }

    onFocusChanged: (focus) => {
        if (focus) {
            root.inputField.forceActiveFocus()
        }
    }

    Timer {
        id: translateTimer
        interval: Config.options.sidebar.translator.delay
        repeat: false
        onTriggered: () => {
            if (translateProc.running) translateProc.queued = true;
            else root.startTranslation();
        }
    }

    property var windowsRequest: null
    readonly property bool busy: translateProc.running
        || (root.windowsRequest !== null && root.windowsRequest.readyState !== XMLHttpRequest.DONE)

    function startTranslation() {
        const text = root.inputField.text.trim();
        if (text.length === 0) {
            root.windowsRequest?.abort();
            root.translatedText = "";
            root.failed = false;
            return;
        }
        if (Platform.isWindows) {
            root.windowsRequest?.abort();
            root.windowsRequest = GoogleTranslateFree.translate(root.sourceLanguage, root.targetLanguage, text, translated => {
                root.translatedText = translated;
                root.failed = translated.length === 0;
            });
            return;
        }
        translateProc.buffer = "";
        translateProc.command = ["timeout", "12", "trans", "-e", root.engine, "-4", "-brief", "-no-bidi",
            "-source", root.sourceLanguage, "-target", root.targetLanguage, text];
        translateProc.running = true;
    }

    Process {
        id: translateProc
        property bool queued: false
        property string buffer: ""
        stdout: SplitParser {
            onRead: data => {
                translateProc.buffer += data + "\n";
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (translateProc.queued) {
                translateProc.queued = false;
                root.startTranslation();
                return;
            }
            finishTimer.restart();
        }
    }

    Timer {
        id: finishTimer
        interval: 60
        onTriggered: {
            if (translateProc.running) return;
            const lines = translateProc.buffer.split("\n").filter(line => !line.includes("[WARNING]"));
            const output = lines.join("\n").trim();
            if (output.length > 0) {
                root.translatedText = output;
                root.failed = false;
            } else {
                root.translatedText = "";
                root.failed = true;
            }
        }
    }

    readonly property list<string> windowsLanguageCodes: ["auto", "af", "sq", "am", "ar", "hy", "as", "ay", "az",
        "bm", "eu", "be", "bn", "bho", "bs", "bg", "ca", "ceb", "ny", "zh-CN", "zh-TW", "co", "hr", "cs", "da",
        "dv", "doi", "nl", "en", "eo", "et", "ee", "fil", "fi", "fr", "fy", "gl", "ka", "de", "el", "gn", "gu",
        "ht", "ha", "haw", "he", "hi", "hmn", "hu", "is", "ig", "ilo", "id", "ga", "it", "ja", "jv", "kn", "kk",
        "km", "rw", "gom", "ko", "kri", "ku", "ckb", "ky", "lo", "la", "lv", "ln", "lt", "lg", "lb", "mk", "mai",
        "mg", "ms", "ml", "mt", "mi", "mr", "mni-Mtei", "lus", "mn", "my", "ne", "no", "or", "om", "ps", "fa",
        "pl", "pt", "pa", "qu", "ro", "ru", "sm", "sa", "gd", "nso", "sr", "st", "sn", "sd", "si", "sk", "sl",
        "so", "es", "su", "sw", "sv", "tl", "tg", "ta", "tt", "te", "th", "ti", "ts", "tr", "tk", "ak", "uk",
        "ur", "ug", "uz", "vi", "cy", "xh", "yi", "yo", "zu"]

    Component.onCompleted: {
        if (Platform.isWindows) root.languages = root.windowsLanguageCodes;
    }

    Process {
        id: getLanguagesProc
        command: ["trans", "-list-languages", "-no-bidi"]
        property list<string> bufferList: ["auto"]
        running: !Platform.isWindows
        stdout: SplitParser {
            onRead: data => {
                getLanguagesProc.bufferList.push(data.trim());
            }
        }
        onExited: (exitCode, exitStatus) => {
            let langs = getLanguagesProc.bufferList
                .filter(lang => lang.trim().length > 0 && lang !== "auto")
                .sort((a, b) => a.localeCompare(b));
            langs.unshift("auto");
            root.languages = langs;
            getLanguagesProc.bufferList = [];
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: 10

        TextCanvasPc {
            id: inputCanvas
            Layout.fillWidth: true
            isInput: true
            containerColor: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 0.8)
            placeholderText: Translation.tr("Enter text to translate...")
            onInputTextChanged: {
                translateTimer.restart();
            }
            GroupButton {
                id: pasteButton
                baseWidth: height
                buttonRadius: Appearance.rounding.small
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    iconSize: Appearance.font.pixelSize.larger
                    text: "content_paste"
                    color: deleteButton.enabled ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                }
                onClicked: {
                    root.inputField.text = Quickshell.clipboardText
                }
            }
            GroupButton {
                id: deleteButton
                baseWidth: height
                buttonRadius: Appearance.rounding.small
                enabled: inputCanvas.inputTextArea.text.length > 0
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    iconSize: Appearance.font.pixelSize.larger
                    text: "close"
                    color: deleteButton.enabled ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                }
                onClicked: {
                    root.inputField.text = ""
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 20

            Item { Layout.fillWidth: true }

            LanguageSelectorButtonPc {
                id: sourceLanguageButton
                displayText: root.sourceLanguage
                buttonColor: Appearance.colors.colSecondaryContainer
                onClicked: root.showLanguageSelectorDialog(false)
            }

            GroupButton {
                id: swapButton
                glass: true
                Layout.preferredWidth: height
                colBackground: Appearance.colors.colTertiaryContainer
                colBackgroundHover: Appearance.colors.colTertiaryContainerHover
                buttonRadius: Appearance.rounding.full
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    iconSize: Appearance.font.pixelSize.larger
                    text: "autorenew"
                    color: Appearance.colors.colOnLayer1
                }
                onClicked: root.swapLanguages()
            }

            LanguageSelectorButtonPc {
                id: targetLanguageButton
                displayText: root.targetLanguage
                buttonColor: Appearance.colors.colPrimaryContainer
                onClicked: root.showLanguageSelectorDialog(true)
            }

            Item { Layout.fillWidth: true }
        }

        TextCanvasPc {
            id: outputCanvas
            Layout.fillWidth: true
            isInput: false
            containerColor: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 0.8)
            placeholderText: root.failed ? Translation.tr("Translation failed. Check your connection and try again.")
                : root.busy ? Translation.tr("Translating...")
                : Translation.tr("Translation goes here...")
            property bool hasTranslation: (root.translatedText.trim().length > 0)
            text: hasTranslation ? root.translatedText : ""
            GroupButton {
                id: copyButton
                baseWidth: height
                buttonRadius: Appearance.rounding.small
                enabled: outputCanvas.displayedText.trim().length > 0
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    iconSize: Appearance.font.pixelSize.larger
                    text: "content_copy"
                    color: copyButton.enabled ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                }
                onClicked: {
                    Quickshell.clipboardText = outputCanvas.displayedText
                }
            }
            GroupButton {
                id: searchButton
                baseWidth: height
                buttonRadius: Appearance.rounding.small
                enabled: outputCanvas.displayedText.trim().length > 0
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    iconSize: Appearance.font.pixelSize.larger
                    text: "travel_explore"
                    color: searchButton.enabled ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                }
                onClicked: {
                    let url = Config.options.search.engineBaseUrl + outputCanvas.displayedText;
                    for (let site of Config.options.search.excludedSites) {
                        url += ` -site:${site}`;
                    }
                    Qt.openUrlExternally(url);
                }
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: root.showLanguageSelector
        visible: root.showLanguageSelector
        z: 9999
        sourceComponent: SelectionDialog {
            id: languageSelectorDialog
            titleText: Translation.tr("Select Language")
            items: root.languages
            defaultChoice: root.languageSelectorTarget ? root.targetLanguage : root.sourceLanguage
            onCanceled: () => {
                root.showLanguageSelector = false;
            }
            onSelected: (result) => {
                root.showLanguageSelector = false;
                if (!result || result.length === 0) return;
                if (root.languageSelectorTarget) {
                    root.targetLanguage = result;
                    Config.options.language.translator.targetLanguage = result;
                } else {
                    root.sourceLanguage = result;
                    Config.options.language.translator.sourceLanguage = result;
                }
                translateTimer.restart();
            }
        }
    }
}