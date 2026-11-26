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
    id: displaysSection
    spacing: 4

    readonly property var current: displayConfig.monitors[displayCanvas.selectedIndex] ?? null
    readonly property bool active: displaysSection.current !== null && !displaysSection.current.disabled
    readonly property bool busy: displayConfig.busy

    WinModels.MonitorConfigOption {
        id: displayConfig
    }

    W.MonitorCanvas {
        id: displayCanvas
        Layout.fillWidth: true
        visible: displayConfig.monitors.length > 0
        monitorConfig: displayConfig
    }

    W.NoticeBox {
        Layout.fillWidth: true
        Layout.topMargin: 6
        visible: displayConfig.lastError.length > 0
        materialIcon: "error"
        text: Translation.tr("Windows didn't accept that display change.") + "\n" + displayConfig.lastError
    }

    ContentSubsection {
        Layout.topMargin: 10
        visible: displaysSection.current !== null
        title: displayConfig.title(displaysSection.current)

        GroupedList {
            ConfigSwitch {
                buttonIcon: "desktop_windows"
                text: Translation.tr("Enabled")
                enabled: !displaysSection.busy && (displayConfig.activeCount > 1 || !displaysSection.active)
                checked: displaysSection.active
                onCheckedChanged: {
                    if (!displaysSection.current || checked === displaysSection.active)
                        return;
                    displayConfig.setEnabled(displaysSection.current, checked);
                    checked = Qt.binding(() => displaysSection.active);
                }
            }

            ConfigSwitch {
                buttonIcon: "star"
                text: Translation.tr("Make this my main display")
                enabled: !displaysSection.busy && displaysSection.active && displayConfig.activeCount > 1 && !(displaysSection.current?.primary ?? false)
                checked: displaysSection.current?.primary ?? false
                onCheckedChanged: {
                    if (!displaysSection.current || checked === (displaysSection.current.primary ?? false))
                        return;
                    if (checked)
                        displayConfig.setPrimary(displaysSection.current);
                    checked = Qt.binding(() => displaysSection.current?.primary ?? false);
                }
            }
        }

        GroupedList {
            Layout.topMargin: 6
            visible: displaysSection.active

            ConfigComboBox {
                Layout.fillWidth: true
                buttonIcon: "aspect_ratio"
                text: Translation.tr("Display resolution")
                enabled: !displaysSection.busy
                model: displayConfig.resolutionOptions(displaysSection.current)
                currentValue: displayConfig.resolutionValue(displaysSection.current?.resolutionWidth, displaysSection.current?.resolutionHeight)
                onSelected: newValue => displayConfig.setResolution(displaysSection.current, newValue)
            }

            ConfigComboBox {
                Layout.fillWidth: true
                buttonIcon: "speed"
                text: Translation.tr("Refresh rate")
                enabled: !displaysSection.busy && model.length > 1
                model: displayConfig.refreshRateOptions(displaysSection.current)
                currentValue: displaysSection.current?.refreshRate ?? 0
                onSelected: newValue => displayConfig.setRefreshRate(displaysSection.current, newValue)
            }

            ColumnLayout {
                spacing: 6
                enabled: !displaysSection.busy
                RowLayout {
                    spacing: 10
                    Layout.leftMargin: 8
                    W.MaterialSymbol {
                        text: "mobile_rotate"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    W.StyledText {
                        text: Translation.tr("Display orientation")
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }
                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: displaysSection.current?.rotation ?? 0
                    onSelected: newValue => displayConfig.setRotation(displaysSection.current, newValue)
                    options: [
                        { displayName: Translation.tr("Landscape"), icon: "screen_rotation_alt", value: 0 },
                        { displayName: Translation.tr("Portrait"), icon: "rotate_90_degrees_cw", value: 1 },
                        { displayName: Translation.tr("Landscape (flipped)"), icon: "screen_rotation", value: 2 },
                        { displayName: Translation.tr("Portrait (flipped)"), icon: "rotate_90_degrees_ccw", value: 3 }
                    ]
                }
            }
        }

        GroupedList {
            Layout.topMargin: 6
            visible: displaysSection.active && (displaysSection.current?.scaleSupported ?? false)

            ConfigComboBox {
                Layout.fillWidth: true
                buttonIcon: "zoom_in"
                text: Translation.tr("Scale")
                enabled: !displaysSection.busy
                model: displayConfig.scaleOptions(displaysSection.current)
                currentValue: displaysSection.current?.scale ?? 100
                onSelected: newValue => displayConfig.setScale(displaysSection.current, newValue)
            }
        }
    }

    ContentSubsection {
        Layout.topMargin: 10
        visible: displaysSection.active && (displaysSection.current?.hdrSupported ?? false)
        title: Translation.tr("HDR & Color Management")

        W.NoticeBox {
            Layout.fillWidth: true
            Layout.bottomMargin: 6
            visible: displaysSection.current?.hdrLimited ?? false
            text: Translation.tr("Windows is limiting HDR on this display right now, for example to save battery.")
        }

        GroupedList {
            ConfigSwitch {
                buttonIcon: "hdr_on"
                text: Translation.tr("Use HDR")
                enabled: !displaysSection.busy
                checked: displaysSection.current?.hdrEnabled ?? false
                onCheckedChanged: {
                    if (!displaysSection.current || checked === (displaysSection.current.hdrEnabled ?? false))
                        return;
                    displayConfig.setHdr(displaysSection.current, checked);
                    checked = Qt.binding(() => displaysSection.current?.hdrEnabled ?? false);
                }
            }
        }

        GroupedList {
            Layout.topMargin: 6
            visible: (displaysSection.current?.hdrEnabled ?? false) && (displaysSection.current?.sdrBrightnessSupported ?? false)

            ConfigSlider {
                id: sdrBrightnessSlider
                buttonIcon: "brightness_6"
                text: Translation.tr("SDR content brightness")
                textWidth: 180
                from: 80
                to: 480
                stepSize: 4
                usePercentTooltip: false
                value: displaysSection.current?.sdrBrightness ?? 80
                onMoved: sdrBrightnessTimer.restart()

                Timer {
                    id: sdrBrightnessTimer
                    interval: 120
                    onTriggered: displayConfig.setSdrBrightness(displaysSection.current, sdrBrightnessSlider.value)
                }
            }
        }
    }

    W.NoticeBox {
        Layout.fillWidth: true
        Layout.topMargin: 10
        visible: displayConfig.available
        text: Translation.tr("Color profiles, Night light and HDR calibration are in Windows Settings.")

        Item {
            Layout.fillWidth: true
        }
        W.RippleButtonWithIcon {
            Layout.fillWidth: false
            buttonRadius: Appearance.rounding.small
            materialIcon: "open_in_new"
            mainText: Translation.tr("Open Windows display settings")
            onClicked: Qt.openUrlExternally("ms-settings:display")
            colBackground: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer)
            colBackgroundHover: Appearance.colors.colPrimaryContainerHover
            colRipple: Appearance.colors.colPrimaryContainerActive
        }
    }
}
