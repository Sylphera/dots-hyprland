import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import qs.modules.common
import qs.modules.waffle.looks

Kirigami.Icon {
    id: root
    required property string icon
    property bool filled: false
    property bool monochrome: true
    // Should be 16, but it appears the icons have some padding, 
    // Unlike the Windows-only Segoe UI icons, the open source FluentUI ones are hella small
    property int implicitSize: 20
    implicitWidth: implicitSize
    implicitHeight: implicitSize

    source: icon === "" ? "" : `${Looks.iconsPath}/${root.icon}${filled ? "-filled" : ""}.svg`
    fallback: root.icon
    roundToIconSize: false
    color: Looks.colors.fg
    isMask: false
    animated: true
    layer.enabled: root.monochrome
    layer.effect: MultiEffect {
        brightness: 1.0
        colorization: 1.0
        colorizationColor: root.color
    }
}
