import QtQuick
import Quickshell
import org.kde.kirigami as Kirigami
import qs.services
import qs.modules.common

Kirigami.Icon {
    id: root
    required property string iconName
    property bool separateLightDark: false
    property bool tryCustomIcon: true
    
    property real implicitSize: 26
    implicitWidth: implicitSize
    implicitHeight: implicitSize

    animated: true
    roundToIconSize: false
    readonly property bool _windowsAppIcon: Platform.isWindows && root.iconName.startsWith("appicon:")
    fallback: Platform.isWindows ? Quickshell.iconPath(root.iconName, "image-missing") : root.iconName
    source: tryCustomIcon && !root._windowsAppIcon ? `${Looks.iconsPath}/${root.iconName}${!root.separateLightDark ? "" : Looks.dark ? "-dark" : "-light"}.svg` : fallback

    color: Looks.colors.fg
}
