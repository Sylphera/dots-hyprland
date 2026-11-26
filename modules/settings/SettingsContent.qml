import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF

Item {
    id: root
    property real contentPadding: 8
    property bool asynchronousFirstPage: true
    property int currentPage: 0
    readonly property bool lookReady: Config.ready && MaterialThemeLoader.ready && Translation.ready
    property bool ready: false
    readonly property bool pageShown: pageArea.shownPage !== -1
    readonly property list<url> pageSources: root.pageList.map(page => Qt.resolvedUrl(page.file))
    readonly property var pages: root.pageList
    readonly property var pageList: [
        {
            name: Translation.tr("Quick"),
            file: "QuickConfig.qml",
            icon: "instant_mix"
        },
        {
            name: Translation.tr("General"),
            file: "GeneralConfig.qml",
            icon: "browse"
        },
        {
            name: Translation.tr("Bar"),
            file: "BarConfig.qml",
            icon: "toast",
            iconRotation: 180
        },
        {
            name: Translation.tr("Background"),
            file: "BackgroundConfig.qml",
            icon: "texture"
        },
        {
            name: Translation.tr("Interface"),
            file: "InterfaceConfig.qml",
            icon: "bottom_app_bar"
        },
        {
            name: Translation.tr("Services"),
            file: "ServicesConfig.qml",
            icon: "settings"
        },
        {
            name: Translation.tr("Advanced"),
            file: "AdvancedConfig.qml",
            icon: "construction"
        },
        {
            name: Translation.tr("About"),
            file: "About.qml",
            icon: "info"
        }
    ]

    signal closeRequested
    property bool windowControls: false

    property var searchResults: []

    function searchLabel(node) {
        if (typeof node.text === "string" && node.text.length > 0)
            return node.text;
        if (typeof node.title === "string" && node.title.length > 0)
            return node.title;
        return "";
    }

    function sectionOf(node, pageRoot) {
        let p = node.parent;
        while (p && p !== pageRoot) {
            if (typeof p.title === "string" && p.title.length > 0)
                return p.title;
            p = p.parent;
        }
        return "";
    }

    function collectMatches(node, query, pageIndex, pageRoot, seen, out) {
        if (!node || out.length >= 60)
            return;
        const label = root.searchLabel(node);
        if (label.length > 0 && label.length < 200 && label.toLowerCase().includes(query)) {
            const key = pageIndex + "|" + label;
            if (!seen[key]) {
                seen[key] = true;
                out.push({
                    page: pageIndex,
                    pageName: root.pages[pageIndex].name,
                    section: root.sectionOf(node, pageRoot),
                    label: label.replace(/\n/g, " "),
                    item: node
                });
            }
            return;
        }
        const kids = node.children ?? [];
        for (let i = 0; i < kids.length; i++)
            root.collectMatches(kids[i], query, pageIndex, pageRoot, seen, out);
    }

    function runSearch(text) {
        const query = text.trim().toLowerCase();
        if (query.length < 2) {
            root.searchResults = [];
            return;
        }
        const out = [];
        const seen = {};
        for (let i = 0; i < pageRepeater.count; i++) {
            const loader = pageRepeater.itemAt(i);
            if (!loader)
                continue;
            if (!loader.visited)
                loader.visited = true;
            if (loader.item)
                root.collectMatches(loader.item, query, i, loader.item, seen, out);
        }
        root.searchResults = out;
    }

    function openResult(result) {
        if (!result)
            return;
        searchJump.target = result.item;
        settingsSearch.text = "";
        root.searchResults = [];
        root.currentPage = result.page;
        searchJump.restart();
    }

    function scrollToItem(item) {
        if (!item)
            return;
        let flick = null;
        let p = item.parent;
        while (p && p !== pageArea) {
            if (p.contentY !== undefined && p.contentItem !== undefined && p.contentHeight !== undefined)
                flick = p;
            p = p.parent;
        }
        if (flick) {
            const pos = item.mapToItem(flick.contentItem, 0, 0);
            const maxY = Math.max(0, flick.contentHeight - flick.height);
            flick.contentY = Math.max(0, Math.min(pos.y - 60, maxY));
        }
        const box = item.mapToItem(pageHolder, 0, 0);
        searchHighlight.x = box.x - 6;
        searchHighlight.y = box.y - 4;
        searchHighlight.width = item.width + 12;
        searchHighlight.height = item.height + 8;
        searchHighlight.opacity = 1;
        searchHighlightFade.restart();
    }

    Timer {
        id: searchJump
        property var target: null
        interval: 350
        onTriggered: root.scrollToItem(searchJump.target)
    }

    Binding on ready {
        when: root.lookReady
        value: true
        restoreMode: Binding.RestoreNone
    }

    Timer {
        interval: 1500
        running: Config.ready && !root.ready
        onTriggered: root.ready = true
    }

    onCurrentPageChanged: pageArea.switchPage()

    ColumnLayout {
        anchors {
            fill: parent
            margins: root.contentPadding
        }

        Keys.onPressed: event => {
            if (event.modifiers === Qt.ControlModifier) {
                if (event.key === Qt.Key_F) {
                    settingsSearch.forceActiveFocus();
                    settingsSearch.selectAll();
                    event.accepted = true;
                } else if (event.key === Qt.Key_PageDown) {
                    root.currentPage = Math.min(root.currentPage + 1, root.pageSources.length - 1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_PageUp) {
                    root.currentPage = Math.max(root.currentPage - 1, 0);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Tab) {
                    root.currentPage = (root.currentPage + 1) % root.pageSources.length;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Backtab) {
                    root.currentPage = (root.currentPage - 1 + root.pageSources.length) % root.pageSources.length;
                    event.accepted = true;
                }
            }
        }

        Item {
            visible: Config.options?.windows.showTitlebar
            Layout.fillWidth: true
            Layout.fillHeight: false
            implicitHeight: Math.max(titleText.implicitHeight, windowControlsRow.implicitHeight)
            StyledText {
                id: titleText
                anchors {
                    left: Config.options.windows.centerTitle ? undefined : parent.left
                    horizontalCenter: Config.options.windows.centerTitle ? parent.horizontalCenter : undefined
                    verticalCenter: parent.verticalCenter
                    leftMargin: 12
                }
                color: Appearance.colors.colOnLayer0
                text: Translation.tr("Settings")
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.title
                    variableAxes: Appearance.font.variableAxes.title
                }
            }
            MouseArea {
                anchors.fill: parent
                visible: root.windowControls
                acceptedButtons: Qt.LeftButton
                onPressed: root.Window.window?.startSystemMove()
                onDoubleClicked: {
                    const backingWindow = root.Window.window;
                    if (!backingWindow) return;
                    if (backingWindow.visibility === Window.Maximized) backingWindow.showNormal();
                    else backingWindow.showMaximized();
                }
            }
            RowLayout {
                id: windowControlsRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                RippleButton {
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 35
                    implicitHeight: 35
                    onClicked: root.closeRequested()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "close"
                        iconSize: 20
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.contentPadding
            Item {
                id: navRailWrapper
                Layout.fillHeight: true
                Layout.margins: 5
                implicitWidth: navRail.expanded ? 150 : fab.baseSize
                Behavior on implicitWidth {
                    NumberAnimation {
                        alwaysRunToEnd: true
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }
                NavigationRail {
                    id: navRail
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }
                    spacing: 10
                    expanded: root.width > 900

                    NavigationRailExpandButton {
                        focus: root.visible
                    }

                    FloatingActionButton {
                        id: fab
                        property bool justCopied: false
                        iconText: justCopied ? "check" : "edit"
                        buttonText: justCopied ? Translation.tr("Path copied") : Translation.tr("Config file")
                        expanded: navRail.expanded
                        downAction: () => {
                            Qt.openUrlExternally(`${Directories.config}/illogical-impulse/config.json`);
                        }
                        altAction: () => {
                            Quickshell.clipboardText = CF.FileUtils.trimFileProtocol(`${Directories.config}/illogical-impulse/config.json`);
                            fab.justCopied = true;
                            revertTextTimer.restart();
                        }

                        Timer {
                            id: revertTextTimer
                            interval: 1500
                            onTriggered: {
                                fab.justCopied = false;
                            }
                        }

                        StyledToolTip {
                            text: Translation.tr("Open the shell config file\nAlternatively right-click to copy path")
                        }
                    }

                    NavigationRailTabArray {
                        currentIndex: root.currentPage
                        expanded: navRail.expanded
                        Repeater {
                            model: root.ready ? root.pages : []
                            NavigationRailButton {
                                required property var index
                                required property var modelData
                                toggled: root.currentPage === index
                                onPressed: root.currentPage = index
                                expanded: navRail.expanded
                                buttonIcon: modelData.icon
                                buttonIconRotation: modelData.iconRotation || 0
                                buttonText: modelData.name
                                showToggledHighlight: false
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Appearance.m3colors.m3surfaceContainerLow
                radius: Appearance.rounding.windowRounding - root.contentPadding

                MaterialTextField {
                    id: settingsSearch
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 10
                    }
                    placeholderText: Translation.tr("Search settings")
                    onTextChanged: searchDebounce.restart()
                    Timer {
                        id: searchDebounce
                        interval: 120
                        onTriggered: root.runSearch(settingsSearch.text)
                    }
                    Keys.onReturnPressed: {
                        root.runSearch(settingsSearch.text);
                        root.openResult(root.searchResults[0]);
                    }
                    Keys.onEnterPressed: {
                        root.runSearch(settingsSearch.text);
                        root.openResult(root.searchResults[0]);
                    }
                    Keys.onEscapePressed: {
                        settingsSearch.text = "";
                        root.searchResults = [];
                    }
                }

                Item {
                    id: pageHolder
                    anchors {
                        top: settingsSearch.bottom
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }

                Item {
                    id: pageArea
                    property int shownPage: -1
                    property bool pageHidden: true

                    function showPending() {
                        if (fadeOut.running || !pageArea.pageHidden)
                            return;
                        const loader = pageRepeater.itemAt(root.currentPage);
                        if (!loader || loader.status !== Loader.Ready)
                            return;
                        const first = pageArea.shownPage === -1;
                        pageArea.shownPage = root.currentPage;
                        pageArea.pageHidden = false;
                        if (first) {
                            pageArea.opacity = 1;
                            pageArea.anchors.topMargin = 0;
                            preloadTimer.start();
                        } else {
                            fadeIn.restart();
                        }
                    }

                    function switchPage() {
                        if (pageArea.shownPage === root.currentPage && !pageArea.pageHidden)
                            return;
                        fadeIn.stop();
                        pageArea.pageHidden = true;
                        if (pageArea.shownPage === -1) {
                            pageArea.showPending();
                            return;
                        }
                        fadeOut.restart();
                    }

                    anchors.fill: parent
                    opacity: 0

                    Repeater {
                        id: pageRepeater
                        model: root.pageSources.length
                        delegate: Loader {
                            id: pageLoader
                            required property int index
                            property bool visited: false
                            anchors.fill: parent
                            visible: index === pageArea.shownPage
                            asynchronous: index !== 0 || root.asynchronousFirstPage
                            active: root.ready && visited
                            source: root.pageSources[index]
                            onLoaded: pageArea.showPending()

                            Binding on visited {
                                when: pageLoader.index === root.currentPage
                                value: true
                                restoreMode: Binding.RestoreNone
                            }
                        }
                    }

                    Timer {
                        id: preloadTimer
                        interval: 300
                        onTriggered: {
                            for (let i = 0; i < pageRepeater.count; i++) {
                                const loader = pageRepeater.itemAt(i);
                                if (!loader)
                                    continue;
                                if (loader.status === Loader.Loading) {
                                    preloadTimer.restart();
                                    return;
                                }
                                if (!loader.visited) {
                                    loader.visited = true;
                                    preloadTimer.restart();
                                    return;
                                }
                            }
                        }
                    }

                    NumberAnimation {
                        id: fadeOut
                        target: pageArea
                        property: "opacity"
                        to: 0
                        duration: 100
                        easing.type: Appearance.animation.elementMoveExit.type
                        easing.bezierCurve: Appearance.animationCurves.emphasizedFirstHalf
                        onFinished: pageArea.showPending()
                    }

                    ParallelAnimation {
                        id: fadeIn
                        NumberAnimation {
                            target: pageArea
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: 200
                            easing.type: Appearance.animation.elementMoveEnter.type
                            easing.bezierCurve: Appearance.animationCurves.emphasizedLastHalf
                        }
                        NumberAnimation {
                            target: pageArea
                            property: "anchors.topMargin"
                            from: 20
                            to: 0
                            duration: 200
                            easing.type: Appearance.animation.elementMoveEnter.type
                            easing.bezierCurve: Appearance.animationCurves.emphasizedLastHalf
                        }
                    }
                }

                Rectangle {
                    id: searchHighlight
                    z: 5
                    opacity: 0
                    visible: opacity > 0
                    color: "transparent"
                    radius: Appearance.rounding.small
                    border.width: 2
                    border.color: Appearance.m3colors.m3primary
                    NumberAnimation on opacity {
                        id: searchHighlightFade
                        running: false
                        from: 1
                        to: 0
                        duration: 1800
                        easing.type: Easing.InQuad
                    }
                }
                }

                Rectangle {
                    id: searchResultsBox
                    z: 10
                    visible: settingsSearch.text.trim().length >= 2
                    anchors {
                        top: settingsSearch.bottom
                        left: settingsSearch.left
                        right: settingsSearch.right
                        topMargin: 4
                    }
                    height: Math.min(searchResultsList.contentHeight, 360) + 8
                    radius: Appearance.rounding.normal
                    color: Appearance.m3colors.m3surfaceContainerHigh
                    border.width: 1
                    border.color: Appearance.m3colors.m3outlineVariant

                    StyledText {
                        visible: root.searchResults.length === 0
                        anchors.centerIn: parent
                        text: Translation.tr("No results")
                        color: Appearance.m3colors.m3outline
                    }

                    ListView {
                        id: searchResultsList
                        anchors.fill: parent
                        anchors.margins: 4
                        clip: true
                        model: root.searchResults
                        implicitHeight: contentHeight
                        delegate: RippleButton {
                            id: resultButton
                            required property var modelData
                            width: ListView.view.width
                            implicitHeight: resultColumn.implicitHeight + 12
                            buttonRadius: Appearance.rounding.small
                            onClicked: root.openResult(resultButton.modelData)
                            contentItem: Column {
                                id: resultColumn
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 12
                                    rightMargin: 12
                                }
                                StyledText {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: resultButton.modelData.label
                                    color: Appearance.colors.colOnLayer1
                                }
                                StyledText {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.m3colors.m3outline
                                    text: resultButton.modelData.section.length > 0
                                        ? `${resultButton.modelData.pageName} › ${resultButton.modelData.section}`
                                        : resultButton.modelData.pageName
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
