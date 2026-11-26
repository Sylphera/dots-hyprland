import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

DashboardCard {
    id: root

    property string title: ""
    property string icon: "tune"
    property string embed: ""
    property var tileShape: MaterialShape.Shape.Cookie9Sided

    tint: Appearance.colors.colLayer1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialShapeWrappedMaterialSymbol {
                shape: root.tileShape
                text: root.icon
                iconSize: 22
                fill: 1
                padding: 9
                color: Appearance.colors.colSecondary
                colSymbol: Appearance.colors.colOnSecondary
            }

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer1
                elide: Text.ElideRight
            }
        }

        StyledFlickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: loader.implicitHeight

            Loader {
                id: loader
                width: flick.width
                source: root.embed === "" ? "" : Qt.resolvedUrl(root.embed)
            }
        }
    }
}
