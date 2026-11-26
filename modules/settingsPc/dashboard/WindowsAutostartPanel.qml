import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets as W
import qs.modules.common.functions
import qs.modules.common.models.windows as WinModels
import qs.modules.settingsPc.widgets

ColumnLayout {
    id: page
    spacing: 4

    readonly property var autostartEntries: WindowsNative.autostart ? WindowsNative.autostart.entries : []
    readonly property var autostartAppOptions: {
        const apps = Array.from(DesktopEntries.applications.values);
        const mapped = apps.map(app => {
            const path = app.comment && app.comment.length > 0
                ? app.comment
                : (app.command && app.command.length > 0 ? "shell:AppsFolder\\" + app.command[0] : "");
            return {label: app.name, value: path};
        }).filter(o => o.value.length > 0 && o.label.length > 0);
        mapped.sort((a, b) => a.label.localeCompare(b.label));
        return mapped;
    }

    function addAutostartApp(path, name) {
        if (!path || path.length === 0) return;
        WindowsNative.autostart?.addFromPath(path, name ?? "", []);
    }

    FileDialog {
        id: autostartFileDialog
        title: Translation.tr("Choose an app")
        nameFilters: [Translation.tr("Programs (*.exe)"), Translation.tr("All files (*)")]
        onAccepted: page.addAutostartApp(FileUtils.trimFileProtocol(selectedFile.toString()), "")
    }

    W.StyledText {
        Layout.fillWidth: true
        text: Translation.tr("Apps that launch automatically when you sign in.")
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colSubtext
        wrapMode: Text.Wrap
    }

    GroupedList {
        Layout.topMargin: 6

        ColumnLayout {
            spacing: 6
            ConfigSwitch {
                Layout.bottomMargin: 0
                buttonIcon: "power_settings_new"
                text: Translation.tr("Start ii when you sign in")
                checked: WindowsNative.autostart?.selfStartupEnabled ?? false
                onCheckedChanged: {
                    const autostart = WindowsNative.autostart;
                    if (!autostart || checked === autostart.selfStartupEnabled)
                        return;
                    autostart.setSelfStartup(checked, "task");
                    checked = Qt.binding(() => WindowsNative.autostart?.selfStartupEnabled ?? false);
                }
            }
            ConfigSelectionArray {
                Layout.fillWidth: true
                visible: WindowsNative.autostart?.selfStartupEnabled ?? false
                text: Translation.tr("How ii starts")
                icon: "rocket_launch"
                currentValue: WindowsNative.autostart?.selfStartupMethod || "task"
                onSelected: newValue => {
                    const autostart = WindowsNative.autostart;
                    if (autostart && newValue !== autostart.selfStartupMethod)
                        autostart.setSelfStartup(true, newValue);
                }
                options: [
                    { displayName: Translation.tr("Scheduled task (starts sooner)"), icon: "bolt", value: "task" },
                    { displayName: Translation.tr("Startup registry entry"), icon: "list_alt", value: "run" }
                ]
            }
        }
    }

    W.StyledText {
        Layout.fillWidth: true
        Layout.topMargin: 4
        visible: WindowsNative.autostart?.selfStartupEnabled ?? false
        text: Translation.tr("The scheduled task starts ii a second or two after you sign in; the startup registry entry waits for Windows' startup delay, about 15 seconds. Task Manager's Startup tab doesn't list scheduled tasks, so turn the task off here.")
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colSubtext
        wrapMode: Text.Wrap
    }

    W.NoticeBox {
        Layout.fillWidth: true
        Layout.topMargin: 6
        visible: (WindowsNative.autostart?.selfStartupError ?? "") !== ""
        text: (WindowsNative.autostart?.selfStartupFellBack ?? false)
            ? Translation.tr("Windows didn't let ii create the scheduled task (%1), so it starts from the startup registry entry instead.").arg(WindowsNative.autostart?.selfStartupError ?? "")
            : Translation.tr("Windows didn't accept the last change to how ii starts (%1).").arg(WindowsNative.autostart?.selfStartupError ?? "")
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 10
        spacing: 8

        StyledComboBoxSearch {
            id: autostartAppPicker
            Layout.fillWidth: true
            textRole: "label"
            model: page.autostartAppOptions
            displayText: currentIndex >= 0 ? currentText : Translation.tr("Pick an app…")
        }

        W.RippleButton {
            implicitWidth: 44
            implicitHeight: 40
            buttonRadius: Appearance.rounding.normal
            enabled: autostartAppPicker.currentIndex >= 0
            colBackground: Appearance.colors.colSecondaryContainer
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            colRipple: Appearance.colors.colSecondaryContainerActive
            onClicked: {
                const opt = page.autostartAppOptions[autostartAppPicker.currentIndex];
                if (opt) page.addAutostartApp(opt.value, opt.label);
                autostartAppPicker.currentIndex = -1;
            }
            contentItem: W.MaterialSymbol {
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "add"
                iconSize: 20
                color: Appearance.colors.colOnSecondaryContainer
            }
            W.StyledToolTip {
                text: Translation.tr("Add to startup")
            }
        }

        W.RippleButton {
            implicitWidth: 44
            implicitHeight: 40
            buttonRadius: Appearance.rounding.normal
            colBackground: Appearance.colors.colLayer1
            colBackgroundHover: Appearance.colors.colLayer1Hover
            colRipple: Appearance.colors.colLayer1Active
            onClicked: autostartFileDialog.open()
            contentItem: W.MaterialSymbol {
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "folder_open"
                iconSize: 20
                color: Appearance.colors.colOnLayer1
            }
            W.StyledToolTip {
                text: Translation.tr("Browse for a file")
            }
        }
    }

    W.StyledText {
        Layout.fillWidth: true
        Layout.topMargin: 4
        visible: page.autostartEntries.length === 0
        text: Translation.tr("No startup apps found")
        color: Appearance.colors.colSubtext
        font.pixelSize: Appearance.font.pixelSize.small
    }

    Repeater {
        model: page.autostartEntries

        delegate: RowLayout {
            id: autostartRow
            required property var modelData
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 10

            W.StyledSwitch {
                checked: autostartRow.modelData.enabled
                enabled: autostartRow.modelData.scope === "user"
                onToggled: WindowsNative.autostart?.setEnabled(autostartRow.modelData.id, checked)
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                RowLayout {
                    spacing: 6
                    W.StyledText {
                        text: autostartRow.modelData.name
                        color: Appearance.colors.colOnLayer1
                        elide: Text.ElideRight
                    }
                    W.StyledText {
                        visible: autostartRow.modelData.scope === "machine"
                        text: Translation.tr("(all users)")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                }
                W.StyledText {
                    Layout.fillWidth: true
                    text: autostartRow.modelData.command
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }

            W.RippleButton {
                id: autostartRemoveButton
                visible: autostartRow.modelData.removable
                implicitWidth: 36
                implicitHeight: 36
                buttonRadius: 18
                colBackground: "transparent"
                colBackgroundHover: Qt.rgba(1, 1, 1, 0.12)
                colRipple: Qt.rgba(1, 1, 1, 0.2)
                onClicked: autostartRemovePopup.open()
                contentItem: W.MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "delete"
                    iconSize: 20
                    color: Appearance.colors.colOnLayer1
                }
                W.StyledToolTip {
                    text: Translation.tr("Remove")
                }

                Popup {
                    id: autostartRemovePopup
                    x: autostartRemoveButton.width - implicitWidth
                    y: autostartRemoveButton.height + 4
                    padding: 14
                    modal: true
                    focus: true
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                    contentItem: ColumnLayout {
                        spacing: 10
                        W.StyledText {
                            Layout.maximumWidth: 240
                            wrapMode: Text.Wrap
                            text: Translation.tr("Remove \"%1\" from startup?").arg(autostartRow.modelData.name)
                        }
                        RowLayout {
                            Layout.alignment: Qt.AlignRight
                            W.DialogButton {
                                buttonText: Translation.tr("Cancel")
                                onClicked: autostartRemovePopup.close()
                            }
                            W.DialogButton {
                                buttonText: Translation.tr("Remove")
                                onClicked: {
                                    WindowsNative.autostart?.removeEntry(autostartRow.modelData.id);
                                    autostartRemovePopup.close();
                                }
                            }
                        }
                    }
                    background: Rectangle {
                        radius: Appearance.rounding.normal
                        color: Appearance.m3colors.m3surfaceContainerHigh
                    }
                }
            }
        }
    }

    ContentSubsection {
        Layout.topMargin: 10
        title: Translation.tr("Start with ii")

        W.StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Apps ii itself opens when the shell starts, each on its own workspace.")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            wrapMode: Text.Wrap
        }

        W.AutostartApps {
            Layout.fillWidth: true
            Layout.topMargin: 6
        }
    }
}
