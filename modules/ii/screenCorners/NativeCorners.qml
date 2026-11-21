import QtQuick
import Quickshell
import Quickshell.Windows as QSWin
import qs
import qs.modules.common
import qs.services

QSWin.NativeScreenCorners {
    id: root

    property bool fullscreen: false
    property var actionForCorner: ({})

    readonly property bool showFakeRounding: Config.options.bar.cornerStyle !== 5
        && (Config.options.appearance.fakeScreenRounding === 1 || (Config.options.appearance.fakeScreenRounding === 2 && !root.fullscreen))

    function isLeft(corner) {
        return corner === 0 || corner === 2;
    }
    function isTop(corner) {
        return corner === 0 || corner === 1;
    }

    shown: root.showFakeRounding && !GlobalStates.regionSelectorOpen
    color: "#000000"
    radius: Appearance.rounding.screenRounding
    hotEnabled: Config.options.sidebar.cornerOpen.enable && !root.fullscreen && !GlobalStates.regionSelectorOpen
    hotBottom: Config.options.sidebar.cornerOpen.bottom
    hotWidth: Config.options.sidebar.cornerOpen.cornerRegionWidth
    hotHeight: Config.options.sidebar.cornerOpen.cornerRegionHeight
    deadPixel: Config.options.interactions.deadPixelWorkaround.enable

    onEntered: corner => {
        if (Config.options.sidebar.cornerOpen.clickless)
            root.actionForCorner[corner]();
    }
    onMoved: (corner, x, y, width, height) => {
        if (!Config.options.sidebar.cornerOpen.clicklessCornerEnd)
            return;
        const verticalOffset = Config.options.sidebar.cornerOpen.clicklessCornerVerticalOffset;
        const correctX = (!root.isLeft(corner) && x >= width - 2) || (root.isLeft(corner) && x <= 2);
        const correctY = (root.isTop(corner) && y > verticalOffset) || (!root.isTop(corner) && y < height - verticalOffset);
        if (correctX && correctY)
            root.actionForCorner[corner]();
    }
    onPressed: corner => root.actionForCorner[corner]()
    onScrolled: (corner, steps) => {
        if (!Config.options.sidebar.cornerOpen.valueScroll)
            return;
        for (let i = 0; i < Math.abs(steps); i++) {
            if (root.isLeft(corner)) {
                if (steps > 0)
                    Brightness.increaseBrightness();
                else
                    Brightness.decreaseBrightness();
            } else {
                const currentVolume = Audio.value;
                const step = currentVolume < 0.1 ? 0.01 : 0.02;
                if (steps > 0)
                    Audio.sink.audio.volume = Math.min(1, Audio.sink.audio.volume + step);
                else
                    Audio.sink.audio.volume -= step;
            }
        }
    }
    onLeft: corner => {
        if (!Config.options.sidebar.cornerOpen.valueScroll)
            return;
        if (root.isLeft(corner))
            GlobalStates.osdBrightnessOpen = false;
        else
            GlobalStates.osdVolumeOpen = false;
    }
}
