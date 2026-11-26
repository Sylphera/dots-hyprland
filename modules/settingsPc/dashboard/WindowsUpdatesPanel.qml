import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root
    spacing: 6

    NoticeBox {
        Layout.fillWidth: true
        visible: SelfUpdate.canGoBackToStable
        materialIcon: "science"
        text: Translation.tr("You're on a preview (%1). If something doesn't work, you can go back to the stable version. Your settings stay.").arg(SelfUpdate.installedVersion)

        RippleButtonWithIcon {
            materialIcon: "history"
            mainText: SelfUpdate.stableVersion !== ""
                ? Translation.tr("Go back to %1 (stable)").arg(SelfUpdate.stableVersion)
                : Translation.tr("Go back to stable")
            onClicked: {
                SelfUpdate.goBackToStable()
            }
        }
    }

    NoticeBox {
        Layout.fillWidth: true
        visible: SelfUpdate.updateAvailable
        materialIcon: "new_releases"
        text: Translation.tr("Update available: %1 \"%2\"").arg(SelfUpdate.latestVersion).arg(SelfUpdate.releaseName)
            + (SelfUpdate.downloading ? "\n" + Translation.tr("Downloading the update…") : "")
            + (!SelfUpdate.downloading && SelfUpdate.lastError !== "" ? "\n" + SelfUpdate.lastError : "")

        RippleButtonWithIcon {
            materialIcon: "open_in_new"
            mainText: Translation.tr("What's new")
            onClicked: {
                Qt.openUrlExternally(SelfUpdate.htmlUrl)
            }
        }
        RippleButtonWithIcon {
            materialIcon: "system_update"
            mainText: Translation.tr("Update")
            enabled: !SelfUpdate.downloading
            onClicked: {
                SelfUpdate.startUpdate()
            }
        }
    }

    NoticeBox {
        Layout.fillWidth: true
        visible: SelfUpdate.patchAvailable
        materialIcon: "build"
        text: Translation.tr("A fix for %1 is available. Applying it restarts the shell for a moment; nothing else is reinstalled.").arg(SelfUpdate.installedVersion)
            + (SelfUpdate.patching ? "\n" + Translation.tr("Applying the fix…") : "")

        RippleButtonWithIcon {
            materialIcon: "build"
            mainText: Translation.tr("Apply fix")
            enabled: !SelfUpdate.patching
            onClicked: {
                SelfUpdate.applyPatch()
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: !SelfUpdate.updateAvailable
        wrapMode: Text.WordWrap
        color: Appearance.colors.colSubtext
        text: SelfUpdate.checking
            ? Translation.tr("Checking for updates…")
            : SelfUpdate.lastError !== ""
                ? SelfUpdate.lastError
                : SelfUpdate.installedVersion !== ""
                    ? Translation.tr("ii-windows %1 is up to date.").arg(SelfUpdate.displayVersion)
                    : Translation.tr("Couldn't determine the installed version.")
    }

    Flow {
        Layout.fillWidth: true
        visible: !SelfUpdate.updateAvailable
        spacing: 5

        RippleButtonWithIcon {
            materialIcon: "refresh"
            mainText: Translation.tr("Check for updates")
            enabled: !SelfUpdate.checking
            onClicked: {
                SelfUpdate.refresh()
            }
        }
    }

    ConfigSwitch {
        buttonIcon: "cloud_sync"
        text: Translation.tr("Check for updates automatically")
        checked: Config.options.windowsPort.selfUpdate.enableCheck
        onCheckedChanged: {
            if (checked !== Config.options.windowsPort.selfUpdate.enableCheck)
                Config.options.windowsPort.selfUpdate.enableCheck = checked;
        }
    }

    ConfigSwitch {
        buttonIcon: "notifications"
        text: Translation.tr("Notify me when a new version is available")
        checked: Config.options.windowsPort.selfUpdate.notify
        onCheckedChanged: {
            if (checked !== Config.options.windowsPort.selfUpdate.notify)
                Config.options.windowsPort.selfUpdate.notify = checked;
        }
    }
}
