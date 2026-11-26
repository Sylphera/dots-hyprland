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

    StyledText {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: Appearance.colors.colSubtext
        text: ProblemReport.collecting
            ? Translation.tr("Collecting the logs…")
            : ProblemReport.lastError !== ""
                ? Translation.tr("Couldn't create the report: %1").arg(ProblemReport.lastError)
                : ProblemReport.zipPath !== ""
                    ? Translation.tr("Saved %1. Attach it to the issue that just opened.").arg(ProblemReport.zipPath)
                    : Translation.tr("Saves ii's logs and some system info (Windows build, GPU, screens, fonts) to a zip in Documents\\ii-windows\\reports, opens a new issue on GitHub with the version, style and Windows fields filled in, and copies those fields to the clipboard. Your user name is taken out of the paths; have a look at the files before you send them. A crash dump helps with crashes, but it can hold bits of what ii had in memory, like clipboard text or chats, so it only goes in if you turn it on.")
    }

    ConfigSwitch {
        buttonIcon: "memory"
        text: Translation.tr("Include the latest crash dump")
        enabled: !ProblemReport.collecting
        checked: ProblemReport.includeCrashDump
        onCheckedChanged: {
            ProblemReport.includeCrashDump = checked;
        }
    }

    Flow {
        Layout.fillWidth: true
        spacing: 5

        RippleButtonWithIcon {
            materialIcon: "bug_report"
            mainText: Translation.tr("Report a problem")
            enabled: !ProblemReport.collecting
            onClicked: {
                ProblemReport.collect()
            }
        }
    }
}
