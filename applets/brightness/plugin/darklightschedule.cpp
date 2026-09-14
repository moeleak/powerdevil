/*
 * SPDX-FileCopyrightText: 2026 Vlad Zahorodnii <vlad.zahorodnii@kde.org>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "darklightschedule.h"

#include <QQmlEngine>

DarkLightSchedule::DarkLightSchedule()
{
}

DarkLightSchedule::DarkLightSchedule(const KDarkLightSchedule &schedule)
    : m_schedule(schedule)
{
}

QDateTime DarkLightSchedule::nextMorning(const QDateTime &referenceDateTime) const
{
    auto nextMorning = m_schedule.nextTransition(referenceDateTime);
    if (nextMorning->type() == KDarkLightTransition::Morning) {
        return nextMorning->endDateTime();
    }

    nextMorning = m_schedule.nextTransition(nextMorning->endDateTime());
    return nextMorning->endDateTime();
}

QDateTime DarkLightSchedule::nextEvening(const QDateTime &referenceDateTime) const
{
    auto nextEvening = m_schedule.nextTransition(referenceDateTime);
    if (nextEvening->type() == KDarkLightTransition::Evening) {
        return nextEvening->endDateTime();
    }

    nextEvening = m_schedule.nextTransition(nextEvening->endDateTime());
    return nextEvening->endDateTime();
}

DarkLightScheduleProvider::DarkLightScheduleProvider(QObject *parent)
    : QObject(parent)
{
}

void DarkLightScheduleProvider::poll(QJSValue callback)
{
    KDarkLightScheduleProvider::poll().then(this, [this, callback](const KDarkLightSchedule &schedule) {
        auto engine = qmlEngine(this);
        callback.call({engine->toScriptValue(DarkLightSchedule(schedule))});
    });
}

#include "moc_darklightschedule.cpp"
