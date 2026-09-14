/*
 * SPDX-FileCopyrightText: 2019 Vlad Zahorodnii <vlad.zahorodnii@kde.org>
 * SPDX-FileCopyrightText: 2022 ivan tkachenko <me@ratijas.tk>
 * SPDX-FileCopyrightText: 2023 Natalie Clarius <natalie.clarius@kde.org>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick
import QtQuick.Layouts

import org.kde.kcmutils // KCMLauncher
import org.kde.config as KConfig  // KAuthorized.authorizeControlModule
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons

import org.kde.plasma.private.brightnesscontrolplugin
import org.kde.plasma.workspace.dbus as DBus

PlasmaComponents3.ItemDelegate {
    id: root

    required property NightLightControl nightLightControl

    background.visible: highlighted
    highlighted: activeFocus
    hoverEnabled: false

    Accessible.description: status.text
    Accessible.onPressAction: activateOrDeactivateSwitch.clicked()
    KeyNavigation.tab: kcmButton
    KeyNavigation.right: kcmButton
    Keys.onSpacePressed: activateOrDeactivateSwitch.clicked()

    DarkLightTransitionProgress {
        id: currentTransitionProgress
        startDateTime: new Date(root.nightLightControl.previousOrCurrentTransitionStartTime)
        endDateTime: new Date(root.nightLightControl.previousOrCurrentTransitionEndTime)
    }

    component NightLightControl: DBus.Properties {
        busType: DBus.BusType.Session
        service: "org.kde.KWin.NightLight"
        path: "/org/kde/KWin/NightLight"
        iface: "org.kde.KWin.NightLight"

        // This property holds a value to indicate if Night Light is available.
        readonly property bool available: Boolean(properties.available)
        // This property holds a value to indicate if Night Light is enabled.
        readonly property bool enabled: Boolean(properties.enabled)
        // This property holds a value to indicate if Night Light is running.
        readonly property bool running: Boolean(properties.running)
        // This property holds a value to indicate whether night light is currently inhibited.
        readonly property bool inhibited: Boolean(properties.inhibited)
        // This property holds a value to indicate which mode is set for transitions (0 - automatic location, 1 - manual location, 2 - manual timings, 3 - constant)
        readonly property int mode: Number(properties.mode)
        // This property holds a value to indicate if Night Light is on day mode.
        readonly property bool daylight: Boolean(properties.daylight)
        // This property holds a value to indicate currently applied color temperature.
        readonly property int currentTemperature: Number(properties.currentTemperature)
        // This property holds a value to indicate currently applied color temperature.
        readonly property int targetTemperature: Number(properties.targetTemperature)
        // This property holds a value to indicate the start time of the previous or current color transition in msec since epoch.
        readonly property double previousOrCurrentTransitionStartTime: Number(properties.previousTransitionDateTime)
        // This property holds a value to indicate the end time of the previous or current color transition in msec since epoch.
        readonly property double previousOrCurrentTransitionEndTime: Number(properties.previousTransitionDateTime) * 1000 + Number(properties.previousTransitionDuration)
        // This property holds a value to indicate the start time of the next color transition in msec since epoch.
        readonly property double scheduledTransitionStartTime: Number(properties.scheduledTransitionDateTime) * 1000
        // This property holds a value to indicate the date and time until which Night Light is temporarily activated.
        readonly property double activatedUntil: Number(properties.activatedUntil) * 1000
        // This property holds a value to indicate the date and time until which Night Light is temporarily deactivated.
        readonly property double deactivatedUntil: Number(properties.deactivatedUntil) * 1000

        readonly property bool transitioning: currentTemperature != targetTemperature
        readonly property bool hasSwitchingTimes: mode != 0

        function activateUntil(date) {
            const timestamp = date ? date.getTime() / 1000 : 0;

            DBus.SessionBus.asyncCall({
                service: "org.kde.KWin.NightLight",
                path: "/org/kde/KWin/NightLight",
                iface: "org.kde.KWin.NightLight",
                member: "activateUntil",
                arguments: [timestamp],
                signature: "(t)",
            });
        }

        function deactivateUntil(date) {
            const timestamp = date ? date.getTime() / 1000 : 0;

            DBus.SessionBus.asyncCall({
                service: "org.kde.KWin.NightLight",
                path: "/org/kde/KWin/NightLight",
                iface: "org.kde.KWin.NightLight",
                member: "deactivateUntil",
                arguments: [timestamp],
                signature: "(t)",
            });
        }

        function activateOrDeactivate() {
            if (activatedUntil) {
                activateUntil(null);
                return;
            }

            if (deactivatedUntil) {
                deactivateUntil(null);
                return;
            }

            if (daylight) {
                DarkLightScheduleProvider.poll(schedule => activateUntil(schedule.nextMorning(new Date())));
            } else {
                DarkLightScheduleProvider.poll(schedule => deactivateUntil(schedule.nextEvening(new Date())));
            }
        }
    }

    contentItem: RowLayout {
        spacing: Kirigami.Units.gridUnit

        Kirigami.Icon {
            id: image
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            source: {
                if (!root.nightLightControl.enabled) {
                    return "redshift-status-on"; // not configured: show generic night light icon rather "manually turned off" icon
                } else if (!root.nightLightControl.running) {
                    return "redshift-status-off";
                } else if (root.nightLightControl.daylight && root.nightLightControl.targetTemperature != 6500) { // show daylight icon only when temperature during the day is actually modified
                    return "redshift-status-day";
                } else {
                    return "redshift-status-on";
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    id: title
                    text: root.text
                    textFormat: Text.PlainText

                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                PlasmaComponents3.Label {
                    id: status
                    text: {
                        if (root.nightLightControl.inhibited && root.nightLightControl.enabled) {
                            return i18nc("Night light status", "Suspended");
                        }
                        if (!root.nightLightControl.available) {
                            return i18nc("Night light status", "Unavailable");
                        }
                        if (root.nightLightControl.activatedUntil) {
                            return i18nc("Night light status", "On");
                        }
                        if (root.nightLightControl.deactivatedUntil) {
                            return i18nc("Night light status", "Paused");
                        }
                        if (!root.nightLightControl.enabled) {
                            return i18nc("Night light status", "Not enabled");
                        }
                        if (!root.nightLightControl.running) {
                            return i18nc("Night light status", "Not running");
                        }
                        if (!root.nightLightControl.hasSwitchingTimes) {
                            return i18nc("Night light status", "On");
                        }
                        if (currentTransitionProgress.active) {
                            if (root.nightLightControl.daylight) {
                                return i18nc("Night light phase", "Morning Transition");
                            } else {
                                return i18nc("Night light phase", "Evening Transition");
                            }
                        }
                        if (root.nightLightControl.daylight) {
                            return i18nc("Night light phase", "Day");
                        } else {
                            return i18nc("Night light phase", "Night");
                        }
                    }
                    textFormat: Text.PlainText

                    opacity: 0.75
                }

                PlasmaComponents3.Label {
                    id: currentTemp
                    visible: root.nightLightControl.available && root.nightLightControl.enabled && root.nightLightControl.running
                    text: i18nc("Placeholder is screen color temperature", "%1K", root.nightLightControl.currentTemperature)
                    font.features: { "tnum": 1 }
                    textFormat: Text.PlainText

                    horizontalAlignment: Text.AlignRight
                }
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Switch {
                    id: activateOrDeactivateSwitch
                    enabled: !root.nightLightControl.inhibited
                    checked: root.nightLightControl.activatedUntil || root.nightLightControl.deactivatedUntil
                    text: {
                        if (root.nightLightControl.deactivatedUntil) {
                            return i18nc("@action:button Night Light", "Suspend");
                        } else if (root.nightLightControl.activatedUntil) {
                            return i18nc("@action:button Night Light", "Activate");
                        }

                        if (root.nightLightControl.daylight) {
                            return i18nc("@action:button Night Light", "Activate");
                        } else {
                            return i18nc("@action:button Night Light", "Suspend");
                        }
                    }

                    Layout.fillWidth: true

                    Accessible.onPressAction: clicked()

                    activeFocusOnTab: false
                    focusPolicy: Qt.NoFocus

                    onClicked: {
                        // Visually, we don't want the switch to change its state yet.
                        toggle();

                        // The switch state will change after user clicks an item in the menu.
                        if (root.nightLightControl.activatedUntil) {
                            root.nightLightControl.activateUntil(null);
                        } else if (root.nightLightControl.deactivatedUntil) {
                            root.nightLightControl.deactivateUntil(null);
                        } else {
                            if (root.nightLightControl.daylight) {
                                activateOrDeactivateMenu.askToActivate();
                            } else {
                                activateOrDeactivateMenu.askToDeactivate();
                            }
                        }
                    }

                    PlasmaComponents3.Menu {
                        id: activateOrDeactivateMenu

                        function askToActivate() {
                            DarkLightScheduleProvider.poll(schedule => {
                                const now = new Date();
                                let actions = [];

                                actions.push({
                                    text: i18nc("Part of 'Activate Night Light for 1 hour'", "For 1 hour"),
                                    action: () => root.nightLightControl.activateUntil(new Date(now.getTime() + 1000 * 60 * 60))
                                });

                                const nextMorning = schedule.nextMorning(now);
                                actions.push({
                                    text: nextMorning.getDay() == now.getDay()
                                        ? i18nc("Part of 'Activate Night Light until morning today'", "Until morning today")
                                        : i18nc("Part of 'Activate Night Light until morning tomorrow'", "Until morning tomorrow"),
                                    hint: KCoreAddons.Format.formatRelativeDateTime(nextMorning, Locale.ShortFormat),
                                    action: () => root.nightLightControl.activateUntil(nextMorning)
                                });

                                instantiator.model = actions;
                                activateOrDeactivateMenu.open();
                            });
                        }

                        function askToDeactivate() {
                            DarkLightScheduleProvider.poll(schedule => {
                                const now = new Date();
                                let actions = [];

                                actions.push({
                                    text: i18nc("Part of 'Suspend Night Light for 1 hour'", "For 1 hour"),
                                    action: () => root.nightLightControl.deactivateUntil(new Date(now.getTime() + 1000 * 60 * 60))
                                });

                                const nextEvening = schedule.nextEvening(now);
                                actions.push({
                                    text: nextEvening.getDay() == now.getDay()
                                        ? i18nc("Part of 'Suspend Night Light until evening today'", "Until evening today)")
                                        : i18nc("Part of 'Suspend Night Light until evening tomorrow'", "Until evening tomorrow"),
                                    hint: KCoreAddons.Format.formatRelativeDateTime(nextEvening, Locale.ShortFormat),
                                    action: () => root.nightLightControl.activateUntil(nextEvening)
                                });

                                instantiator.model = actions;
                                activateOrDeactivateMenu.open();
                            });
                        }

                        Instantiator {
                            id: instantiator
                            delegate: PlasmaComponents3.MenuItem {
                                contentItem: Kirigami.TitleSubtitle {
                                    title: modelData?.text ?? ""
                                    subtitle: modelData?.hint ?? ""
                                }
                                onTriggered: modelData.action();
                            }

                            onObjectAdded: (index, object) => activateOrDeactivateMenu.insertItem(index, object)
                            onObjectRemoved: (index, object) => activateOrDeactivateMenu.removeItem(object)
                        }
                    }
                }

                PlasmaComponents3.Button {
                    id: kcmButton
                    visible: KConfig.KAuthorized.authorizeControlModule("kcm_nightlight")

                    icon.name: "configure"
                    text: i18n("Configure…")

                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                    KeyNavigation.up: root.KeyNavigation.up

                    Keys.onPressed: (event) => {
                        if (event.key == Qt.Key_Space || event.key == Qt.Key_Return || event.key == Qt.Key_Enter) {
                            clicked();
                            event.accepted = true
                        }
                    }
                    onClicked: KCMLauncher.openSystemSettings("kcm_nightlight")
                }
            }

            PlasmaComponents3.Label {
                visible: root.nightLightControl.activatedUntil || root.nightLightControl.deactivatedUntil
                text: {
                    if (root.nightLightControl.activatedUntil) {
                        const dateTime = new Date(root.nightLightControl.activatedUntil);
                        return i18nc("Label for a time", "Activated until: %1", KCoreAddons.Format.formatRelativeDateTime(dateTime, Locale.ShortFormat));
                    } else if (root.nightLightControl.deactivatedUntil) {
                        const dateTime = new Date(root.nightLightControl.deactivatedUntil);
                        return i18nc("Label for a time", "Deactivated until: %1", KCoreAddons.Format.formatRelativeDateTime(dateTime, Locale.ShortFormat));
                    }

                    return "";
                }
                textFormat: Text.PlainText

                opacity: 0.75
                font: Kirigami.Theme.smallFont
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }
}
