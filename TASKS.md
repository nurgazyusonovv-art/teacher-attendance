# TASKS.md

## PHASE 0 — Project foundation

- [x] Flutter mobile проект түзүү
  - Acceptance:
    - iOS/Android build
    - base folder structure
    - environments dev/prod

- [x] Flutter Web Admin проект түзүү
  - Acceptance:
    - web build
    - responsive shell
    - dev/prod config

- [x] FastAPI backend түзүү
  - Acceptance:
    - `/health`
    - PostgreSQL connection
    - Alembic
    - Docker

- [x] `.env.example` даярдоо
- [x] Git ignore
- [x] API v1 structure
- [x] Base error response format

---

## PHASE 1 — Database

- [x] `schools`
- [x] `users`
- [x] `teachers`
- [x] `work_schedules`
- [x] `qr_credentials`
- [x] `attendance_events`
- [x] `daily_attendance`
- [x] `audit_logs`
- [x] `devices`

Acceptance:
- foreign keys туура
- indexes бар
- timestamps timezone aware
- migrations иштейт

---

## PHASE 2 — Authentication

### Backend

- [x] Admin/Teacher login
- [x] password hashing
- [x] JWT access token
- [x] refresh token
- [x] `/auth/me`
- [x] role guard

### Mobile

- [x] Login UI
- [x] token secure storage
- [x] auto session restore
- [x] logout

### Admin

- [x] Admin login
- [x] protected routes

Acceptance:
- teacher admin endpoint ачпайт
- expired token refresh болот
- logout token'ду clientтен тазалайт

---

## PHASE 3 — School settings

- [x] School profile
- [x] timezone
- [x] latitude
- [x] longitude
- [x] allowed radius
- [x] maximum GPS accuracy
- [x] default start/end time
- [x] grace period

Acceptance:
- settings admin гана өзгөртөт
- changes audit log'го түшөт

---

## PHASE 4 — Teacher management

### Admin

- [x] Teachers list
- [x] Add teacher
- [x] Edit teacher
- [x] Activate/deactivate
- [x] Reset temporary password
- [x] Teacher detail

Fields:
- full name
- employee code
- phone optional
- email/login
- status
- schedule

Acceptance:
- duplicate login жок
- inactive teacher login кыла албайт

---

## PHASE 5 — Schedule

- [x] Weekly work schedule
- [x] Monday–Sunday
- [x] day off
- [x] start time
- [x] end time
- [x] grace minutes
- [x] individual override

Acceptance:
- backend конкреттүү күнгө schedule чыгарат
- timezone туура иштейт

---

## PHASE 6 — QR

- [x] School QR credential генерация
- [x] QR payload format
- [x] Admin QR view
- [x] Printable QR export кийин
- [x] QR validation endpoint/service

Payload example:

```json
{
  "type": "school_attendance",
  "school_id": "uuid",
  "token": "random-secret"
}
```

Acceptance:
- invalid token rejected
- wrong school rejected
- disabled credential rejected

---

## PHASE 7 — Location verification

### Mobile

- [x] Location permission flow
- [x] Precise location guidance
- [x] Current position
- [x] Accuracy reading
- [x] Permission denied UI
- [x] Location service disabled UI

### Backend

- [x] Haversine distance service
- [x] radius validation
- [x] accuracy validation

Acceptance:
- raw GPS attendance record'до сакталбайт
- distance жана accuracy metadata гана сакталат

---

## PHASE 8 — QR Scanner

- [x] Camera permission
- [x] QR Scanner screen
- [x] valid payload parse
- [x] loading state
- [x] prevent double-submit
- [x] scan result UI

Acceptance:
- бир scan бир request
- scanner duplicate frame'дерди жөнөтпөйт
- permission error түшүнүктүү

---

## PHASE 9 — Check-in

- [x] `/attendance/check-in`
- [x] JWT verify
- [x] teacher active check
- [x] QR validate
- [x] geofence validate
- [x] schedule resolve
- [x] server time
- [x] status calculation
- [x] late minutes
- [x] duplicate protection
- [x] event save
- [x] daily record update
- [x] response DTO

Acceptance examples:

```text
07:52 + start 08:00 = ON_TIME
08:07 + start 08:00 = LATE / 7
```

---

## PHASE 10 — Check-out

- [x] `/attendance/check-out`
- [x] same QR/location validation
- [x] require existing check-in
- [x] duplicate check-out protection
- [x] save server time
- [x] calculate worked duration

Acceptance:
- check-out жок check-in болбосо reject
- duplicate reject

---

## PHASE 11 — Teacher Home

- [x] Greeting
- [x] today date
- [x] schedule
- [x] current attendance status
- [x] Scan QR button
- [x] check-in time
- [x] check-out time
- [x] late minutes
- [x] monthly summary

---

## PHASE 12 — Teacher History

- [x] Attendance list
- [x] Month filter
- [x] Status filter
- [x] Detail screen

Show:
- date
- check-in
- check-out
- status
- late minutes
- worked duration

Do not show:
- raw coordinates

---

## PHASE 13 — Admin Today Dashboard

- [x] KPI cards
- [x] attendance table
- [x] search
- [x] status filters
- [x] late sort
- [x] teacher detail navigation

KPI:
- total
- checked in
- on time
- late
- not checked in

---

## PHASE 14 — Reports

- [x] Date range
- [x] Teacher filter
- [x] Status filter
- [x] Summary
- [x] Monthly report
- [x] CSV export
- [x] PDF export Phase 2 optional

---

## PHASE 15 — Manual correction

- [x] Admin correction modal/page
- [x] reason required
- [x] old value audit
- [x] new value audit
- [x] admin id
- [x] timestamp

Acceptance:
- silent edit жок
- audit log immutable

---

## PHASE 16 — Absence logic

- [ ] Scheduled job / report calculation
- [ ] no check-in → ABSENT
- [ ] day off excluded
- [ ] excused status admin тарабынан

---

## PHASE 17 — Notifications

- [ ] FCM setup
- [ ] APNs setup
- [ ] device token
- [ ] before-start reminder
- [ ] missing check-in reminder
- [ ] late notification
- [ ] admin daily summary

---

## PHASE 18 — App Store / Privacy

- [ ] Camera usage description
- [ ] Location When In Use description
- [ ] Precise Location purpose
- [ ] Privacy Policy
- [ ] Terms/employee notice
- [ ] App Privacy form data mapping
- [ ] no background location
- [ ] demo account
- [ ] demo teacher data
- [ ] demo QR
- [ ] review notes
- [ ] account/deactivation policy documented

---

## PHASE 19 — App Review Demo Mode

- [ ] Dedicated demo tenant/data
- [ ] Demo teacher account
- [ ] Demo admin account
- [ ] Demo QR
- [ ] Demo attendance workflow
- [ ] No production data
- [ ] No global geofence bypass

Acceptance:
- Apple reviewer app functionality'ды мектепте физикалык турбай текшере алат
- production teacher demo workflow колдонбойт

---

## PHASE 20 — Security hardening

- [ ] Rate limit login
- [ ] Rate limit attendance
- [ ] refresh token rotation
- [ ] secrets management
- [ ] HTTPS only
- [ ] secure headers
- [ ] device metadata
- [ ] audit login events
- [ ] suspicious scan logging

Optional:
- device binding
- school Wi-Fi evidence

---

## PHASE 21 — QA

- [ ] Unit tests backend
- [ ] Widget tests
- [ ] Integration tests
- [ ] iOS real device
- [ ] Android real device
- [ ] weak GPS test
- [ ] outside geofence test
- [ ] denied permission test
- [ ] no internet test
- [ ] duplicate scan test
- [ ] timezone test
- [ ] DST-safe code review despite KG timezone

---

## PHASE 22 — Production

- [ ] Production PostgreSQL
- [ ] Backend deploy
- [ ] SSL/domain
- [ ] migrations
- [ ] logging
- [ ] backups
- [ ] monitoring
- [ ] Flutter production API URL
- [ ] iOS release build
- [ ] Android release build
- [ ] Web admin deploy

---

## PHASE 23 — App Store distribution

- [ ] App Store Connect metadata
- [ ] screenshots
- [ ] privacy URL
- [ ] support URL
- [ ] reviewer credentials
- [ ] review notes
- [ ] submit
- [ ] fix review issues
- [ ] request Unlisted App Distribution if appropriate

---

# POST-MVP

- [ ] Registered device binding
- [ ] School Wi-Fi verification
- [ ] Dynamic QR optional mode
- [ ] Multiple campuses
- [ ] Leave/permission requests
- [ ] Sick leave
- [ ] Telegram admin reports
- [ ] Payroll integration
- [ ] Student attendance module
- [ ] Multi-school SaaS
