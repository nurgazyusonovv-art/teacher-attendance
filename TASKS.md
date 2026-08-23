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

- [ ] Admin/Teacher login
- [ ] password hashing
- [ ] JWT access token
- [ ] refresh token
- [ ] `/auth/me`
- [ ] role guard

### Mobile

- [ ] Login UI
- [ ] token secure storage
- [ ] auto session restore
- [ ] logout

### Admin

- [ ] Admin login
- [ ] protected routes

Acceptance:
- teacher admin endpoint ачпайт
- expired token refresh болот
- logout token'ду clientтен тазалайт

---

## PHASE 3 — School settings

- [ ] School profile
- [ ] timezone
- [ ] latitude
- [ ] longitude
- [ ] allowed radius
- [ ] maximum GPS accuracy
- [ ] default start/end time
- [ ] grace period

Acceptance:
- settings admin гана өзгөртөт
- changes audit log'го түшөт

---

## PHASE 4 — Teacher management

### Admin

- [ ] Teachers list
- [ ] Add teacher
- [ ] Edit teacher
- [ ] Activate/deactivate
- [ ] Reset temporary password
- [ ] Teacher detail

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

- [ ] Weekly work schedule
- [ ] Monday–Sunday
- [ ] day off
- [ ] start time
- [ ] end time
- [ ] grace minutes
- [ ] individual override

Acceptance:
- backend конкреттүү күнгө schedule чыгарат
- timezone туура иштейт

---

## PHASE 6 — QR

- [ ] School QR credential генерация
- [ ] QR payload format
- [ ] Admin QR view
- [ ] Printable QR export кийин
- [ ] QR validation endpoint/service

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

- [ ] Location permission flow
- [ ] Precise location guidance
- [ ] Current position
- [ ] Accuracy reading
- [ ] Permission denied UI
- [ ] Location service disabled UI

### Backend

- [ ] Haversine distance service
- [ ] radius validation
- [ ] accuracy validation

Acceptance:
- raw GPS attendance record'до сакталбайт
- distance жана accuracy metadata гана сакталат

---

## PHASE 8 — QR Scanner

- [ ] Camera permission
- [ ] QR Scanner screen
- [ ] valid payload parse
- [ ] loading state
- [ ] prevent double-submit
- [ ] scan result UI

Acceptance:
- бир scan бир request
- scanner duplicate frame'дерди жөнөтпөйт
- permission error түшүнүктүү

---

## PHASE 9 — Check-in

- [ ] `/attendance/check-in`
- [ ] JWT verify
- [ ] teacher active check
- [ ] QR validate
- [ ] geofence validate
- [ ] schedule resolve
- [ ] server time
- [ ] status calculation
- [ ] late minutes
- [ ] duplicate protection
- [ ] event save
- [ ] daily record update
- [ ] response DTO

Acceptance examples:

```text
07:52 + start 08:00 = ON_TIME
08:07 + start 08:00 = LATE / 7
```

---

## PHASE 10 — Check-out

- [ ] `/attendance/check-out`
- [ ] same QR/location validation
- [ ] require existing check-in
- [ ] duplicate check-out protection
- [ ] save server time
- [ ] calculate worked duration

Acceptance:
- check-out жок check-in болбосо reject
- duplicate reject

---

## PHASE 11 — Teacher Home

- [ ] Greeting
- [ ] today date
- [ ] schedule
- [ ] current attendance status
- [ ] Scan QR button
- [ ] check-in time
- [ ] check-out time
- [ ] late minutes
- [ ] monthly summary

---

## PHASE 12 — Teacher History

- [ ] Attendance list
- [ ] Month filter
- [ ] Status filter
- [ ] Detail screen

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

- [ ] KPI cards
- [ ] attendance table
- [ ] search
- [ ] status filters
- [ ] late sort
- [ ] teacher detail navigation

KPI:
- total
- checked in
- on time
- late
- not checked in

---

## PHASE 14 — Reports

- [ ] Date range
- [ ] Teacher filter
- [ ] Status filter
- [ ] Summary
- [ ] Monthly report
- [ ] CSV export
- [ ] PDF export Phase 2 optional

---

## PHASE 15 — Manual correction

- [ ] Admin correction modal/page
- [ ] reason required
- [ ] old value audit
- [ ] new value audit
- [ ] admin id
- [ ] timestamp

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
