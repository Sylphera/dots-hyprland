pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root
    required property var screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property var toplevels: ToplevelManager.toplevels
    // Clamp to avoid lock-screen temp workspace (2147483647 - N) leaking into UI
    readonly property int effectiveActiveWorkspaceId: Math.max(1, Math.min(100, monitor?.activeWorkspace?.id ?? 1))
    readonly property int workspacesShown: Config.options.overview.rows * Config.options.overview.columns
    readonly property int workspaceGroup: Math.floor((effectiveActiveWorkspaceId - 1) / workspacesShown)
    property bool monitorIsFocused: (Hyprland.focusedMonitor?.name == monitor.name)
    property bool live: true
    property bool shown: GlobalStates.overviewOpen
    property bool animate: true
    property var windows: HyprlandData.windowList
    property var windowByAddress: HyprlandData.windowByAddress
    property var windowAddresses: HyprlandData.addresses
    property var monitors: HyprlandData.monitors
    property var monitorData: root.monitors.find(m => m.id === root.monitor?.id)
    property real scale: Config.options.overview.scale
    property color activeBorderColor: Appearance.colors.colSecondary

    property real workspaceImplicitWidth: (monitorData?.transform % 2 === 1) ? 
        ((monitor.height - monitorData?.reserved[0] - monitorData?.reserved[2]) * root.scale / monitor.scale) :
        ((monitor.width - monitorData?.reserved[0] - monitorData?.reserved[2]) * root.scale / monitor.scale)
    property real workspaceImplicitHeight: (monitorData?.transform % 2 === 1) ? 
        ((monitor.width - monitorData?.reserved[1] - monitorData?.reserved[3]) * root.scale / monitor.scale) :
        ((monitor.height - monitorData?.reserved[1] - monitorData?.reserved[3]) * root.scale / monitor.scale)
    property real largeWorkspaceRadius: Appearance.rounding.large
    property real smallWorkspaceRadius: Appearance.rounding.verysmall

    property real workspaceNumberMargin: 80
    property real workspaceNumberSize: 250 * monitor.scale
    property int workspaceZ: 0
    property int windowZ: 1
    property int windowDraggingZ: 99999
    property real workspaceSpacing: 5

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1

    implicitWidth: overviewBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: overviewBackground.implicitHeight + Appearance.sizes.elevationMargin * 2

    property Component windowComponent: OverviewWindow {
        shown: root.shown
    }
    property list<OverviewWindow> windowWidgets: []

    function windowsInWorkspaceGroup() {
        return ToplevelManager.toplevels.values.filter(toplevel => {
            const address = `0x${toplevel.HyprlandToplevel?.address}`;
            var win = root.windowByAddress[address];
            const inWorkspaceGroup = (root.workspaceGroup * root.workspacesShown < win?.workspace?.id && win?.workspace?.id <= (root.workspaceGroup + 1) * root.workspacesShown);
            return inWorkspaceGroup;
        });
    }

    onLiveChanged: {
        if (root.live) {
            animateTimer.restart();
        } else {
            animateTimer.stop();
            root.animate = false;
        }
    }

    Timer {
        id: animateTimer
        interval: 0
        onTriggered: root.animate = true
    }

    Binding {
        target: root
        property: "windowByAddress"
        when: root.live
        value: HyprlandData.windowByAddress
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: root
        property: "monitors"
        when: root.live
        value: HyprlandData.monitors
        restoreMode: Binding.RestoreNone
    }
    
    function getWsRow(ws) {
        // 1-indexed workspace, 0-indexed row
        var normalRow = Math.floor((ws - 1) / Config.options.overview.columns) % Config.options.overview.rows;
        return (Config.options.overview.orderBottomUp ? Config.options.overview.rows - normalRow - 1 : normalRow);
    }
    function getWsColumn(ws) {
        // 1-indexed workspace, 0-indexed column
        var normalCol = (ws - 1) % Config.options.overview.columns;
        return (Config.options.overview.orderRightLeft ? Config.options.overview.columns - normalCol - 1 : normalCol);
    }
    function getWsInCell(ri, ci) {
        // 1-indexed workspace, 0-indexed row and column index
        return (Config.options.overview.orderBottomUp ? Config.options.overview.rows - ri - 1 : ri) * Config.options.overview.columns + (Config.options.overview.orderRightLeft ? Config.options.overview.columns - ci - 1 : ci) + 1
    }

    function workspaceAtPoint(x, y) {
        const width = root.workspaceImplicitWidth;
        const height = root.workspaceImplicitHeight;
        if (x < 0 || y < 0 || width <= 0 || height <= 0)
            return -1;
        const column = Math.floor(x / (width + root.workspaceSpacing));
        const row = Math.floor(y / (height + root.workspaceSpacing));
        if (column >= Config.options.overview.columns || row >= Config.options.overview.rows)
            return -1;
        if (x - column * (width + root.workspaceSpacing) >= width
                || y - row * (height + root.workspaceSpacing) >= height)
            return -1;
        return root.workspaceGroup * root.workspacesShown + root.getWsInCell(row, column);
    }

    StyledRectangularShadow {
        target: overviewBackground
    }
    Rectangle { // Background
        id: overviewBackground
        property real padding: 10
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin

        implicitWidth: workspaceColumnLayout.implicitWidth + padding * 2
        implicitHeight: workspaceColumnLayout.implicitHeight + padding * 2
        radius: root.largeWorkspaceRadius + padding
        color: Appearance.colors.colUiSurfaceContainer

        Column { // Workspaces
            id: workspaceColumnLayout

            z: root.workspaceZ
            anchors.centerIn: parent
            spacing: workspaceSpacing
            
            Repeater {
                model: Config.options.overview.rows
                delegate: Row {
                    id: row
                    required property int index
                    spacing: workspaceSpacing

                    Repeater { // Workspace repeater
                        model: Config.options.overview.columns
                        Rectangle { // Workspace
                            id: workspace
                            required property int index
                            property int colIndex: index
                            property int workspaceValue: root.workspaceGroup * root.workspacesShown + getWsInCell(row.index, colIndex)
                            property color defaultWorkspaceColor: Appearance.colors.colSurfaceContainerLow
                            property color hoveredWorkspaceColor: ColorUtils.mix(defaultWorkspaceColor, Appearance.colors.colLayer1Hover, 0.1)
                            property color hoveredBorderColor: Appearance.colors.colLayer2Hover
                            property bool hoveredWhileDragging: Platform.isWindows
                                && root.draggingTargetWorkspace === workspace.workspaceValue
                                && root.draggingFromWorkspace !== workspace.workspaceValue

                            implicitWidth: root.workspaceImplicitWidth
                            implicitHeight: root.workspaceImplicitHeight
                            color: hoveredWhileDragging ? hoveredWorkspaceColor : defaultWorkspaceColor
                            property bool workspaceAtLeft: colIndex === 0
                            property bool workspaceAtRight: colIndex === Config.options.overview.columns - 1
                            property bool workspaceAtTop: row.index === 0
                            property bool workspaceAtBottom: row.index === Config.options.overview.rows - 1
                            topLeftRadius: (workspaceAtLeft && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            topRightRadius: (workspaceAtRight && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            bottomLeftRadius: (workspaceAtLeft && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            bottomRightRadius: (workspaceAtRight && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            border.width: 2
                            border.color: hoveredWhileDragging ? hoveredBorderColor : "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: workspace.workspaceValue
                                font {
                                    pixelSize: root.workspaceNumberSize * root.scale
                                    weight: Font.DemiBold
                                    family: Appearance.font.family.expressive
                                }
                                color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.8)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: workspaceArea
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                onPressed: {
                                    if (root.draggingTargetWorkspace === -1) {
                                        GlobalStates.overviewOpen = false
                                        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${workspace.workspaceValue} })`)
                                    }
                                }
                            }

                            DropArea {
                                anchors.fill: parent
                                enabled: !Platform.isWindows
                                onEntered: {
                                    root.draggingTargetWorkspace = workspace.workspaceValue
                                    if (root.draggingFromWorkspace == root.draggingTargetWorkspace) return;
                                    hoveredWhileDragging = true
                                }
                                onExited: {
                                    hoveredWhileDragging = false
                                    if (root.draggingTargetWorkspace == workspace.workspaceValue) root.draggingTargetWorkspace = -1
                                }
                            }

                        }
                    }
                }
            }
        }

        Item { // Windows & focused workspace indicator
            id: windowSpace
            anchors.centerIn: parent
            implicitWidth: workspaceColumnLayout.implicitWidth
            implicitHeight: workspaceColumnLayout.implicitHeight

            Repeater { // Window repeater
                model: ScriptModel {
                    id: windowModel
                }
                delegate: OverviewWindow {
                    id: window
                    shown: root.shown
                    required property var modelData
                    property int monitorId: windowData?.monitor
                    property var monitor: root.monitors.find(m => m.id == monitorId)
                    property var address: `0x${modelData.HyprlandToplevel.address}`
                    toplevel: modelData
                    monitorData: this.monitor
                    scale: root.scale
                    animate: root.animate && !dragArea.movingWindow
                    x: dragArea.previewHeld ? dragArea.previewPosition.x : initX
                    y: dragArea.previewHeld ? dragArea.previewPosition.y : initY
                    onWindowDataChanged: {
                        if (dragArea?.pendingPlacement)
                            Qt.callLater(dragArea.checkPlacement);
                    }
                    widgetMonitor: root.monitors.find(m => m.id == root.monitor.id)
                    windowData: {
                        const data = root.windowByAddress[address];
                        if (!Platform.isWindows || data?.overviewAt?.length !== 2 || data?.overviewSize?.length !== 2)
                            return data;
                        return Object.assign({}, data, { at: data.overviewAt, size: data.overviewSize });
                    }

                    property bool atInitPosition: (initX == x && initY == y)

                    // Offset on the canvas
                    property int workspaceColIndex: getWsColumn(windowData?.workspace.id)
                    property int workspaceRowIndex: getWsRow(windowData?.workspace.id)
                    xOffset: (root.workspaceImplicitWidth + workspaceSpacing) * workspaceColIndex
                    yOffset: (root.workspaceImplicitHeight + workspaceSpacing) * workspaceRowIndex
                    property real xWithinWorkspaceWidget: Math.max((windowData?.at[0] - (monitor?.x ?? 0) - monitorData?.reserved[0]) * root.scale, 0)
                    property real yWithinWorkspaceWidget: Math.max((windowData?.at[1] - (monitor?.y ?? 0) - monitorData?.reserved[1]) * root.scale, 0)

                    // Radius
                    property real minRadius: Appearance.rounding.small
                    property bool workspaceAtLeft: workspaceColIndex === 0
                    property bool workspaceAtRight: workspaceColIndex === Config.options.overview.columns - 1
                    property bool workspaceAtTop: workspaceRowIndex === 0
                    property bool workspaceAtBottom: workspaceRowIndex === Config.options.overview.rows - 1
                    property bool workspaceAtTopLeft: (workspaceAtLeft && workspaceAtTop) 
                    property bool workspaceAtTopRight: (workspaceAtRight && workspaceAtTop) 
                    property bool workspaceAtBottomLeft: (workspaceAtLeft && workspaceAtBottom) 
                    property bool workspaceAtBottomRight: (workspaceAtRight && workspaceAtBottom) 
                    property real distanceFromLeftEdge: xWithinWorkspaceWidget
                    property real distanceFromRightEdge: root.workspaceImplicitWidth - (xWithinWorkspaceWidget + targetWindowWidth)
                    property real distanceFromTopEdge: yWithinWorkspaceWidget
                    property real distanceFromBottomEdge: root.workspaceImplicitHeight - (yWithinWorkspaceWidget + targetWindowHeight)
                    property real distanceFromTopLeftCorner: Math.max(distanceFromLeftEdge, distanceFromTopEdge)
                    property real distanceFromTopRightCorner: Math.max(distanceFromRightEdge, distanceFromTopEdge)
                    property real distanceFromBottomLeftCorner: Math.max(distanceFromLeftEdge, distanceFromBottomEdge)
                    property real distanceFromBottomRightCorner: Math.max(distanceFromRightEdge, distanceFromBottomEdge)
                    topLeftRadius: Math.max((workspaceAtTopLeft ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromTopLeftCorner, minRadius)
                    topRightRadius: Math.max((workspaceAtTopRight ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromTopRightCorner, minRadius)
                    bottomLeftRadius: Math.max((workspaceAtBottomLeft ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromBottomLeftCorner, minRadius)
                    bottomRightRadius: Math.max((workspaceAtBottomRight ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromBottomRightCorner, minRadius)

                    Timer {
                        id: updateWindowPosition
                        interval: Config.options.hacks.arbitraryRaceConditionDelay
                        repeat: false
                        running: false
                        onTriggered: {
                            window.x = Math.round(xWithinWorkspaceWidget + xOffset)
                            window.y = Math.round(yWithinWorkspaceWidget + yOffset)
                        }
                    }

                    z: Drag.active || dragArea.previewHeld ? root.windowDraggingZ : (root.windowZ + windowData?.floating + windowData?.fullscreen * 2)
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    DragHandler {
                        id: overviewDrag
                        enabled: Platform.isWindows
                        target: null
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        acceptedButtons: Qt.LeftButton
                        grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType

                        onActiveChanged: {
                            if (active) {
                                dragArea.beginMove(centroid.scenePressPosition);
                                dragArea.movePreview(centroid.scenePosition);
                            }
                        }
                        onCentroidChanged: {
                            if (active)
                                dragArea.movePreview(centroid.scenePosition);
                        }
                        onGrabChanged: (transition, point) => {
                            if (!dragArea.movingWindow)
                                return;
                            if (transition === PointerDevice.UngrabExclusive) {
                                dragArea.movePreview(point.scenePosition);
                                dragArea.finishMove();
                            } else if (transition === PointerDevice.CancelGrabExclusive) {
                                dragArea.releasePointer();
                                dragArea.settlePreview();
                            }
                        }
                    }

                    TapHandler {
                        enabled: Platform.isWindows
                        acceptedButtons: Qt.LeftButton
                        gesturePolicy: TapHandler.DragThreshold
                        onTapped: {
                            const data = window.windowData;
                            if (!data)
                                return;
                            GlobalStates.overviewOpen = false;
                            Hyprland.dispatch('hl.dsp.focus({ window = "address:' + data.address + '" })');
                        }
                    }

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: hovered = true // For hover color change
                        onExited: hovered = false // For hover color change
                        acceptedButtons: Platform.isWindows ? Qt.MiddleButton : Qt.LeftButton | Qt.MiddleButton
                        drag.target: Platform.isWindows ? null : window
                        property bool movingWindow: false
                        property bool previewHeld: false
                        property var pendingPlacement: null
                        property point pressPosition
                        property point previewOrigin
                        property point previewPosition
                        property point dropPoint

                        Timer {
                            id: placementTimeout
                            interval: Math.max(150, Appearance.animation.elementMoveFast.duration)
                            onTriggered: dragArea.settlePreview()
                        }

                        function checkPlacement() {
                            const placement = dragArea.pendingPlacement;
                            const data = window.windowData;
                            if (!placement || !data)
                                return;
                            if (placement.workspace !== data.workspace.id)
                                return;
                            if (placement.previousPosition
                                    && placement.previousPosition.x === data.at[0]
                                    && placement.previousPosition.y === data.at[1]
                                    && placement.previousSize.width === data.size[0]
                                    && placement.previousSize.height === data.size[1])
                                return;
                            dragArea.settlePreview();
                        }

                        function settlePreview() {
                            placementTimeout.stop();
                            dragArea.pendingPlacement = null;
                            dragArea.previewHeld = false;
                        }

                        function beginMove(scenePressPosition) {
                            if (!window.windowData?.workspace)
                                return;
                            placementTimeout.stop();
                            dragArea.pendingPlacement = null;
                            dragArea.pressPosition = windowSpace.mapFromItem(null,
                                scenePressPosition.x, scenePressPosition.y);
                            dragArea.previewOrigin = Qt.point(window.x, window.y);
                            dragArea.previewPosition = dragArea.previewOrigin;
                            window.pressed = true;
                            dragArea.movingWindow = true;
                            dragArea.previewHeld = true;
                            root.draggingFromWorkspace = window.windowData.workspace.id;
                        }

                        function movePreview(scenePosition) {
                            if (!dragArea.movingWindow)
                                return;
                            const pointer = windowSpace.mapFromItem(null, scenePosition.x, scenePosition.y);
                            dragArea.previewPosition = Qt.point(dragArea.previewOrigin.x + pointer.x - dragArea.pressPosition.x,
                                dragArea.previewOrigin.y + pointer.y - dragArea.pressPosition.y);
                            const grid = workspaceColumnLayout.mapFromItem(null, scenePosition.x, scenePosition.y);
                            root.draggingTargetWorkspace = root.workspaceAtPoint(grid.x, grid.y);
                            dragArea.dropPoint = Qt.point((grid.x - window.xOffset) / root.workspaceImplicitWidth,
                                (grid.y - window.yOffset) / root.workspaceImplicitHeight);
                        }

                        function finishMove() {
                            const from = root.draggingFromWorkspace;
                            const target = root.draggingTargetWorkspace;
                            const position = dragArea.previewPosition;
                            dragArea.releasePointer();
                            const data = window.windowData;
                            if (target !== -1 && data) {
                                if (target !== from) {
                                    dragArea.pendingPlacement = { workspace: target };
                                    placementTimeout.restart();
                                    Hyprland.dispatch('hl.dsp.window.move({ workspace = ' + target
                                        + ', follow = false, window = "address:' + data.address + '" })');
                                    return;
                                }

                                if (!data.fullscreen && !data.floating && data.monitor === root.monitor.id) {
                                    const point = dragArea.dropPoint;
                                    const x = point.x * root.workspaceImplicitWidth + window.xOffset;
                                    const y = point.y * root.workspaceImplicitHeight + window.yOffset;
                                    if (x < window.initX || x >= window.initX + window.targetWindowWidth
                                            || y < window.initY || y >= window.initY + window.targetWindowHeight) {
                                        dragArea.awaitGeometry(target, data);
                                        Hyprland.dispatch('overviewdrop address:' + data.address + ',' + point.x + ',' + point.y);
                                        return;
                                    }
                                }

                                if (data.floating && !data.fullscreen && data.monitor === root.monitor.id) {
                                    const x = Math.round((position.x - window.xOffset) / (root.scale * window.widthRatio)
                                        + (window.monitorData?.reserved[0] ?? 0));
                                    const y = Math.round((position.y - window.yOffset) / (root.scale * window.heightRatio)
                                        + (window.monitorData?.reserved[1] ?? 0));
                                    if (Number.isFinite(x) && Number.isFinite(y)) {
                                        dragArea.awaitGeometry(target, data);
                                        Hyprland.dispatch('hl.dsp.window.move({ x = "' + x + '", y = "' + y
                                            + '", window = "address:' + data.address + '" })');
                                        return;
                                    }
                                }
                            }
                            dragArea.settlePreview();
                        }

                        function awaitGeometry(workspace, data) {
                            dragArea.pendingPlacement = {
                                workspace: workspace,
                                previousPosition: Qt.point(data.at[0], data.at[1]),
                                previousSize: Qt.size(data.size[0], data.size[1])
                            };
                            placementTimeout.restart();
                        }

                        function releasePointer() {
                            window.pressed = false;
                            dragArea.movingWindow = false;
                            root.draggingFromWorkspace = -1;
                            root.draggingTargetWorkspace = -1;
                        }

                        onPressed: (mouse) => {
                            if (Platform.isWindows)
                                return;
                            root.draggingFromWorkspace = windowData?.workspace.id
                            window.pressed = true
                            window.Drag.active = true
                            window.Drag.source = window
                            window.Drag.hotSpot.x = mouse.x
                            window.Drag.hotSpot.y = mouse.y
                            // console.log(`[OverviewWindow] Dragging window ${windowData?.address} from position (${window.x}, ${window.y})`)
                        }
                        onReleased: {
                            if (Platform.isWindows)
                                return;
                            const targetWorkspace = root.draggingTargetWorkspace
                            window.pressed = false
                            window.Drag.active = false
                            root.draggingFromWorkspace = -1
                            if (targetWorkspace !== -1 && targetWorkspace !== windowData?.workspace.id) {
                                Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${targetWorkspace}, follow = false, window = "address:${window.windowData?.address}" })`)
                                updateWindowPosition.restart()
                            }
                            else {
                                if (!window.windowData.floating) {
                                    updateWindowPosition.restart()
                                    return
                                }
                                const percentageX = (window.x - xOffset) / root.workspaceImplicitWidth
                                const percentageY = (window.y - yOffset) / root.workspaceImplicitHeight
                                Hyprland.dispatch(`hl.dsp.window.move({ x = "${percentageX * root.screen.width}", y = "${percentageY * root.screen.height}", window = "address:${window.windowData?.address}" })`)
                            }
                        }
                        onClicked: (event) => {
                            if (!windowData) return;

                            if (event.button === Qt.LeftButton) {
                                GlobalStates.overviewOpen = false
                                Hyprland.dispatch(`hl.dsp.focus({window = "address:${windowData.address}"})`)
                                event.accepted = true
                            } else if (event.button === Qt.MiddleButton) {
                                Hyprland.dispatch(`hl.dsp.window.close({window = "address:${windowData.address}"})`)
                                event.accepted = true
                            }
                        }

                        StyledToolTip {
                            extraVisibleCondition: false
                            alternativeVisibleCondition: dragArea.containsMouse && !window.Drag.active && !dragArea.previewHeld
                            text: `${windowData?.title}\n[${windowData?.class}] ${windowData?.xwayland ? "[XWayland] " : ""}`
                        }
                    }
                }
            }

            Binding {
                target: windowModel
                property: "values"
                when: root.live
                value: root.windowsInWorkspaceGroup()
                restoreMode: Binding.RestoreNone
            }

            Rectangle { // Focused workspace indicator
                id: focusedWorkspaceIndicator
                property int rowIndex: getWsRow(root.effectiveActiveWorkspaceId)
                property int colIndex: getWsColumn(root.effectiveActiveWorkspaceId)
                x: (root.workspaceImplicitWidth + workspaceSpacing) * colIndex
                y: (root.workspaceImplicitHeight + workspaceSpacing) * rowIndex
                z: root.windowZ
                width: root.workspaceImplicitWidth
                height: root.workspaceImplicitHeight
                color: "transparent"
                property bool workspaceAtLeft: colIndex === 0
                property bool workspaceAtRight: colIndex === Config.options.overview.columns - 1
                property bool workspaceAtTop: rowIndex === 0
                property bool workspaceAtBottom: rowIndex === Config.options.overview.rows - 1
                topLeftRadius: (workspaceAtLeft && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                topRightRadius: (workspaceAtRight && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                bottomLeftRadius: (workspaceAtLeft && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                bottomRightRadius: (workspaceAtRight && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                border.width: 2
                border.color: root.activeBorderColor
                Behavior on x {
                    enabled: root.animate
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on y {
                    enabled: root.animate
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on topLeftRadius {
                    enabled: root.animate
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on topRightRadius {
                    enabled: root.animate
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on bottomLeftRadius {
                    enabled: root.animate
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on bottomRightRadius {
                    enabled: root.animate
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
            }
        }
    }
}
