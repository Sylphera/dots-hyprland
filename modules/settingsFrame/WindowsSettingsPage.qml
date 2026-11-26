import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settingsPc.dashboard as SettingsPcDashboard

Item {
    id: root

    signal pageExitRequested()
    signal closeRequested()

    readonly property string searchQuery: searchInput.text
    property var thumbsRequested: ({})

    function scrollSettingsBy(delta) {
        page.scrollBy(delta);
    }

    function search(text) {
        searchInput.text = text;
        searchInput.forceActiveFocus();
    }

    focus: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
            searchInput.forceActiveFocus();
            event.accepted = true;
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            page.scrollBy(event.key === Qt.Key_Down ? 120 : -120);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
            page.scrollBy(event.key === Qt.Key_PageDown ? 420 : -420);
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialShapeWrappedMaterialSymbol {
                shape: MaterialShape.Shape.Cookie9Sided
                text: "public"
                iconSize: 24
                fill: 1
                padding: 10
                color: Appearance.colors.colPrimaryContainer
                colSymbol: Appearance.colors.colOnPrimaryContainer
            }

            ColumnLayout {
                spacing: 0

                StyledText {
                    text: Translation.tr("Global")
                    font.pixelSize: Appearance.font.pixelSize.title
                    font.family: Appearance.font.family.title
                    color: Appearance.colors.colOnLayer0
                }

                StyledText {
                    text: Translation.tr("Settings that apply to every environment")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Rectangle {
                implicitHeight: 44
                implicitWidth: 260
                radius: height / 2
                color: Appearance.colors.colLayer1
                border.width: searchInput.activeFocus ? 2 : 0
                border.color: Appearance.colors.colPrimary

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 8

                    MaterialSymbol {
                        text: "search"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer1
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        clip: true
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.family: Appearance.font.family.main
                        color: Appearance.colors.colOnLayer1
                        selectionColor: Appearance.colors.colPrimary
                        Keys.onEscapePressed: {
                            if (text !== "")
                                text = "";
                            else
                                root.forceActiveFocus();
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchInput.text === ""
                            text: Translation.tr("Search global settings")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }

        SettingsPcDashboard.DashboardSettingsPage {
            id: page
            Layout.fillWidth: true
            Layout.fillHeight: true
            pager: root
            globalMode: true
        }
    }
}
