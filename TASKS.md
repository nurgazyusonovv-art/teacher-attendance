# TASKS.md

- [x] Web dashboard: failed loading distinguished from empty attendance, last successful response retained, 60-second non-overlapping refresh added. Actual production school/date/API response still needs inspection; not deployed.

- [x] 2026-09-15: Web teacher creation no longer silently closes on API rejection; minimum lengths, pending-submit guard, visible error and success feedback added. Production rejection cause requires actual response; deployment not yet performed.

- [x] 2026-09-14: 1.1.3/build 5 Android ARM64/ARM32 APK жана Transporter IPA даяр. Кэштин окуу/жазуу форматы, аккаунт/API isolation жана cached UI белгиси оңдолду; analyzer таза, 36 тест өттү. Production backend deploy/Apple upload бул этапта жасалган жок.

## Teacher UX — 2026-09-10

- [x] Updated UI release 1.1.2/build 4: signed ARM64/ARM32 APKs and Transporter IPA exported to releases; previous release signing reused. No Apple upload performed.

- [x] Source-based review: QR action priority, status guidance, calendar-based leave dates, pending approval feedback, empty states, credential input and scanner text wrapping improved.
- [x] Attendance guidance regression tests added; security/backend attendance rules and user-owned iOS configuration preserved.
- [ ] Physical iOS/Android camera/GPS, screen-reader and teacher usability acceptance; rebuild APK/IPA before distribution (existing build 3 artifacts do not include these UI changes).

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
- logout token'ду clientтен тазалайт жана server session'ду revoke кылат

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
  "qr_token": "random-secret"
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

- [x] Scheduled job / report calculation
- [x] no check-in → ABSENT
- [x] day off excluded
- [x] excused status admin тарабынан

---

## PHASE 17 — Notifications

- [x] FCM setup
- [x] APNs setup
- [x] device token
- [x] before-start reminder
- [x] missing check-in reminder
- [x] late notification
- [x] admin daily summary

---

## PHASE 18 — App Store / Privacy

- [x] Camera usage description
- [x] Location When In Use description
- [x] Precise Location purpose
- [x] Privacy Policy
- [x] Terms/employee notice
- [x] App Privacy form data mapping
- [x] no background location
- [x] demo account
- [x] demo teacher data
- [x] demo QR
- [x] review notes
- [x] account/deactivation policy documented

---

## PHASE 19 — App Review Demo Mode

- [x] Dedicated demo tenant/data
- [x] Demo teacher account
- [x] Demo admin account
- [x] Demo QR
- [x] Demo attendance workflow
- [x] No production data
- [x] No global geofence bypass

Acceptance:
- Apple reviewer app functionality'ды мектепте физикалык турбай текшере алат
- production teacher demo workflow колдонбойт

---

## PHASE 20 — Security hardening

- [x] Rate limit login
- [x] Rate limit attendance
- [x] refresh token rotation
- [ ] secrets management — repository/config оңдолду; мурда чыккан production secret/DB credential сырттан rotate кылынышы керек
- [x] HTTPS only
- [x] secure headers
- [x] device metadata
- [x] audit login events
- [x] suspicious scan logging

Optional:
- device binding
- school Wi-Fi evidence

---

## PHASE 21 — QA

- [x] Unit tests backend
- [x] Widget tests
- [x] Integration tests
- [x] iOS real device / Simulator build
- [x] weak GPS test
- [x] outside geofence test
- [x] denied permission test
- [x] duplicate scan test
- [x] timezone test
- [x] DST-safe code review despite KG timezone

---

## PHASE 22 — Production

- [x] Production PostgreSQL
- [x] Backend deploy (Docker multi-stage)
- [x] SSL/domain (Nginx reverse proxy)
- [x] migrations (Alembic automated script)
- [x] logging
- [x] backups (Gzip backup script)
- [x] monitoring (Healthcheck endpoints)
- [x] Flutter production API URL
- [x] iOS release build configuration
- [x] Android release signing key provisioning — 2026-09-10 owner approval менен туруктуу release key түзүлдү; password Keychain'де, keystore Git'тен тышкары.
- [x] Web admin deploy (Nginx SPA container)

---

## PHASE 23 — App Store distribution

- [x] App Store Connect metadata
- [x] screenshots
- [x] privacy URL (docs/PRIVACY_POLICY.md)
- [x] support URL (docs/APP_STORE_GUIDE.md)
- [x] reviewer credentials (demo_teacher / demo123)
- [x] review notes
- [x] submit preparation
- [x] request Unlisted App Distribution if appropriate

---

## PHASE 24 — Security & integrity remediation (2026-09-05)

- [x] Production secret жана database URL'дарды repository'ден алып салуу
- [x] Production config'ти коопсуз эмес default'тарда fail-closed кылуу
- [x] Runtime auto-migration жана startup demo seed'ди алып салуу
- [x] Bootstrap seed'ди explicit opt-in жана environment password'дор менен коргоо
- [x] Demo user/QR/schedule'ди өзүнчө demo school'го бөлүү
- [x] Alembic schema drift'ти жабуу жана fresh schema текшерүү
- [x] Backend тест базасын толук изоляциялоо
- [x] Plaintext password fallback'ты алып салуу
- [x] Login lockout жана attendance rate limit кошуу
- [x] Auth/attendance request size limits жана concurrent failed-login race коргоосу
- [x] Refresh rotation, replay detection жана server-side logout кошуу
- [x] Mobile/Web refresh request'терин serialize кылып, rotation race'ти жабуу
- [x] Web logout'ту backend session revoke endpoint менен байланыштыруу
- [x] Tenant боюнча school/teacher access boundary кошуу
- [x] Attendance day-off/no-schedule жана duplicate race коргоосун оңдоо
- [x] Manual correction убакыт validation жана audit толуктоо
- [x] Manual correction record ID binding жана concurrent row lock кошуу
- [x] Rejected QR/location/rate-limit scan audit кошуу (raw GPS сакталбайт)
- [x] QR payload type validation жана GPS'ке чейин invalid QR rejection кошуу
- [x] Web admin'де placeholder ордуна реалдуу QR render кылуу
- [x] FCM token'ди API response'тан жашыруу жана duplicate device race'ин жабуу
- [x] Android release cleartext traffic'ти өчүрүү жана security headers кошуу
- [x] Android release build'ден debug signing fallback'ты алып салуу
- [x] Mobile кодду Android debug APK, iOS Simulator жана iOS device release (`--no-codesign`) build менен cross-platform текшерүү
- [x] CI'ге өзүнчө macOS/iOS Simulator build gate кошуу
- [x] Mobile/web analyzer жана backend lint каталарын тазалоо
- [x] Regression: backend 60 test, mobile 17 test, web 1 test
- [x] GitHub CI: backend lint/test, PostgreSQL migration/concurrency, mobile/web analyze/test
- [x] Compose migration startup, private-DB SSL mode жана Nginx security headers оңдоо
- [ ] Мурда ачыкка чыккан production JWT/DB credentials'ди provider'лерде rotate кылуу
- [ ] Production database'ке `alembic upgrade head` жүргүзүп, deploy smoke test аткаруу
- [x] Реалдуу PostgreSQL'де concurrent attendance integration test жүргүзүү
- [x] Production көлөмүнө жакын attendance load test жүргүзүү — локалдык PostgreSQL: 500 мугалим, 50 concurrent, 279.1 req/s, p95 48.9 ms

---

## Толук аудит боюнча оңдоо — 2026-09-18

### Phase 0 — дароо (аткарылды)
- [x] `hard_delete` коргоосу: катышуу жазуусу бар мугалимди өчүрүү 409 менен четке кагылат; `DELETE ATTENDANCE HISTORY` ырастоосу талап кылынат, жоюлган жазуулардын саны audit log'го жазылат.
- [x] Колдонулбаган `NSPhotoLibraryUsageDescription`/`NSPhotoLibraryAddUsageDescription` iOS Info.plist'тен алынды (`image_picker` сыяктуу плагин жок эле).
- [ ] Мурда ачыкка чыккан production JWT/DB credentials'ди provider'лерде rotate кылуу (бул код өзгөртүүсү менен чечилбейт).

### Phase 1 — attendance data integrity (аткарылды)
- [x] `School.attendance_start_date` колонкасы + `e35f1cb7d005` migration; `absence_service.py` ичиндеги hardcode `date(2026, 9, 7)` алынды. Бар мектептер ошол эле датага backfill кылынды, жаңылары `created_at`'ка түшөт. SQLite'та upgrade/downgrade roundtrip жана `alembic check` өттү.
- [x] `AbsenceService.catch_up` админдин GET `/teacher/{id}/history` жолунан алынды (GET эми жазбайт). Ордуна `scripts/finalize_absences.py` + Render cron (`0 18 * * *` UTC = 00:00 Asia/Bishkek) жана кол менен чакыруу үчүн `POST /attendance/admin/catch-up-absences`.
- [x] `GeofenceService.verify_or_raise` — check-in жана check-out эми бир эле geofence дарбазасынан өтөт; эки inline көчүрмө (ар башка ката билдирүүлөрү менен) жоюлду. Мурда `verify_location` тестелген, бирок продакшн жолунда колдонулган эмес.
- [x] Жаңы `tests/test_attendance_integrity.py`: hard delete коргоосу (эки тарабы), per-school absence start date + created_at fallback, geofence дарбазасы, check-out'тун radius/accuracy текшерүүсү. Backend 78 → 84 тест.

### Phase 2 — security (аткарылды)
- [x] `POST /auth/change-password` — колдонуучу өз сырсөзүн алмаштыра алат (учурдагы сырсөз текшерилет, жаңысы эскисинен айырмалуу болушу керек, башка бардык session'дар revoke кылынат, audit'ке `PASSWORD_CHANGED` жазылат).
- [x] Login lockout эми эки катмарлуу: мурдагы `(identifier, ip)` эсептегичинин үстүнө `LOGIN_MAX_FAILED_ATTEMPTS_PER_IDENTIFIER` (default 15) — бир аккаунт боюнча бардык IP'лердеги жаңылыштыктар `LOGIN_LOCKOUT_MINUTES` терезесинде кошулат. Ийгиликтүү кирүү бардык IP'лердеги жазууларды тазалайт. Migration талап кылынбайт.
- [x] `schools.telegram_bot_token` эми at-rest шифрленет (`app/core/crypto.py`, Fernet, `enc:v1:` префикси). Эски ачык текст маанилер иштей берет жана кийинки сактоодо шифрленет. Ачкыч `SECRETS_ENCRYPTION_KEY` — SECRET_KEY'ден өзүнчө, ошондуктан JWT ачкычын rotate кылуу токенди бузбайт; чечмелөө ишке ашпаса `None` кайтат (админ кайра киргизет), exception ыргытылбайт. `cryptography` requirements'ке ачык кошулду.
- [x] Mobile router guard: `createAppRouter(authCubit)` — `refreshListenable` + `redirect`. Session жок болсо `/login`, session текшерилип жатса `/splash`, admin эмес колдонуучу `/admin*` жолдоруна кире албайт, кирген колдонуучу `/login`'де калбайт.
- [x] Жанаша табылган ката: splash жана login `role == 'ADMIN'` деп текшерчү, ошондуктан SUPER_ADMIN мугалимдин экранына түшүп калчу. Экөө тең `user.isAdmin`'ге которулду.
- [x] Device binding бүтүрүлдү (PROJECT.md §10): бир мугалим = бир ырасталган түзмөк.
  - `DeviceStatus` (PENDING/APPROVED/REVOKED), `devices.approved_at/approved_by_id/revoked_at` жана `schools.device_binding_enabled` — `f46a2dc8e006` migration. Бар түзмөктөр APPROVED (эски `is_active=false` болсо REVOKED) кылып backfill кылынды, эч ким бөгөттөлбөйт.
  - Биринчи түзмөк каттоодо эле ырасталат (болбосо эч ким каттай албай калмак), кийинкиси PENDING. Админ ырастаганда мугалимдин мурункусу автоматтык REVOKED болот. REVOKED түзмөк кайра каттоо менен тирилбейт. Бардык өзгөрүүлөр audit log'до.
  - Chek-in/check-out `DeviceService.enforce_binding` аркылуу өтөт. Чектөө **мектеп боюнча күйгүзүлөт жана демейде өчүк** — талаадагы 1.1.3 версиялары `device_id` жөнөтпөйт, ошондуктан аларды бузбайт. Күйгүзүлгөндө `device_id` жок сурам `DEVICE_REQUIRED`, ырасталбаган түзмөк `DEVICE_NOT_APPROVED` алат; экөө тең audit'ке шектүү скан катары жазылат.
  - Mobile: `DeviceIdentityService` — secure storage'да туруктуу id (reinstall жаңы түзмөк катары ырастоону күтөт, бул атайылап). Login жана session restore'до каттайт, эки сканда тең `device_id` жөнөтөт; жаңы ката коддору кыргызча билдирүүгө айландырылды.
  - Web admin: Жөндөөлөр экранында «Катталган түзмөктөр» карточкасы — чектөө которгучу, күтүүдөгү/ырасталган түзмөктөр, ырастоо жана жокко чыгаруу.

### Phase 3 — performance (аткарылды)
- [x] `ResolvedSchedules` — мектептин бардык графиги бир суроодо жүктөлүп, эсте индекстелет. Admin dashboard'догу мугалим башына эки суроо жоголду; тест 5 мугалим кошулганда суроолордун саны **өзгөрбөй турганын** текшерет.
- [x] `get_teacher_history`: year/month эми SQL'де чыпкаланат (мурда бардык саптар жүктөлүп Python'да чыпкаланчу), `start_date`/`end_date`, `skip`/`limit` кошулду. Сабак кечигүүлөрү кайтарылган күндөр боюнча гана суралат. Суроолордун саны саптардын санына көз каранды эмес (≤3).
- [x] Жаңы `GET /attendance/history` — мектеп боюнча пагинацияланган отчет (`items`/`total`/`skip`/`limit`). Web admin отчеттору эми 1+N HTTP сурам ордуна бир пагинацияланган чакырык кылат; мезгилди сервер чыпкалайт.
- [x] `a7b93ef1d007` migration: `daily_attendance(school_id,date)`, `daily_attendance(teacher_id,date)`, `attendance_events(teacher_id,event_time)`, `lesson_delays(school_id,date)`, `lesson_delays(teacher_id,date)`, `audit_logs(school_id,action,created_at)`. Модель metadata'сы менен шайкеш, `alembic check` таза, downgrade roundtrip өттү.
- [x] Absence pass: график жана мугалимдер тизмеси бүт диапазон үчүн бир жолу жүктөлөт; күнүнө бир окуу менен кайсы мугалим өзгөрүшү мүмкүн экени аныкталып, lock жана кайра окуу ошолорго гана колдонулат. Race коргоосу сакталды (чечим ар дайым lock астындагы окуудан алынат). Idempotency тест менен бекитилди.

### Phase 4 — client correctness (аткарылды)
- [x] `DateTimeUtils`'тен UTC+6 hardcode'у толугу менен алынды. `formatBishkekTime` → `formatSchoolTime`: backend ар бир timestamp'ты мектептин timezone'уна которуп жиберет, ошондуктан клиент жөн гана келген саатты көрсөтөт, эч кандай жылдыруу жасабайт. Колдонулбаган `bishkekNow` өчүрүлдү.
- [x] Microsecond багы оңдолду: эски шарт `contains('-') && length > 19` эле, ал эми ар бир ISO датада дефис бар — ошондуктан `2026-09-18T08:07:00.123456` UTC деп эсептелип +6 саат жылчу. Regression тест менен жабылды (UTC+6, UTC+3, UTC-5 жана naive варианттары).
- [x] Offline cache'тин күн чеги: жаңы `TodayStatusResponse.utc_offset_minutes` — сервер мектептин учурдагы UTC offset'ин билдирет, кэш ошол мектептин күнү боюнча эскирет. Эски жазуулар үчүн default 0. Мурдагы тест `+6`ны өзү эсептеп, UTC боюнча 18:00дөн кийин flaky боло турган; эми offset ачык берилет.
- [x] Mobile 40 → 51 тест (datetime_utils жана кеңейтилген cache тесттери), backend 107.

### Phase 5 — maintainability (релизди тоспойт)
- [ ] `web_admin`'дин 7 feature'инин 5'и Cubit'ти айланып өтөт (dashboard, teachers, schedules, reports, settings — `setState` + түз repository). AGENTS.md #3.
- [ ] API жообунун формасы эки башка: `/auth/*` → `StandardResponse`, калгандары → түз модель.
- [ ] `attendance_service.py` ~900 сап; `DailyAttendanceRead` 6 жолу, `LessonDelayRead` 5 жолу кол менен түзүлөт — mapper'лерге чыгаруу.
- [ ] Өлүк код: `AppConstants.defaultBaseUrl` setter жана `keyBaseUrl` эч жерде колдонулбайт.
- [ ] Default'тордун карама-каршылыгы: `SchoolBase.grace_minutes`=5 жана `ScheduleCreate.grace_minutes`=15, ал эми модель default'у 0 жана PROJECT.md 0. Бул кимдин LATE экенин үнсүз өзгөртөт — админ менен макулдашып чечүү керек.
- [ ] Mobile ичиндеги админ панели (5 519 сап, `lib`'тин 44%) web_admin менен кайталанат — продукт чечими же жалпы пакетке чыгаруу.
- [ ] `attendance_start_date`'ти орнотуу үчүн web admin settings экранына талаа кошуу (азыр `PATCH /schools/{id}` аркылуу гана).

### Deploy — 2026-09-18 аткарылды
- [x] `73f11b2` → `23fb5cd` `origin/main`'ге push кылынды, Render автоматтык деплой жүрдү. Үч migration (`e35f1cb7d005`, `f46a2dc8e006`, `a7b93ef1d007`) `preDeployCommand` аркылуу колдонулду.
- [x] Production текшерилди: `/health` healthy, OpenAPI'де `/attendance/history`, `/auth/change-password`, `/attendance/admin/catch-up-absences`, `/devices/{id}/approve|revoke`, `/devices/me` бар; `TodayStatusResponse.utc_offset_minutes`, `AttendanceScanRequest.device_id`, `SchoolRead.attendance_start_date` жана `device_binding_enabled` схемада; авторизациясыз `/attendance/history` 401 кайтарат.
- [x] `SECRETS_ENCRYPTION_KEY` Render'де коюлду (user).
- [x] CI `35317084366` толугу менен SUCCESS (backend, postgres-integration, контейнер, mobile, web_admin, iOS).

### Деплойдон кийин калгандар
- [ ] Render'де `teacher-attendance-finalize-absences` cron сервисин түзүү. Ал жок болгондуктан **азыр ABSENT автоматтык жазылбайт** — dashboard'дун `display_status`'у мурдагыдай туура, бирок тарых/отчет үчүн админ `POST /attendance/admin/catch-up-absences` чакырышы керек.
- [ ] Чечим керек: demo аккаунт эми geofence'тен өтпөйт (мурда `if not user.is_demo` менен айланып өтчү). Бул PROJECT.md §13 «demo backdoor болбошу керек» талабына дал келет, бирок **App Review'га тоскоол**: Cupertino'догу рецензент Бишкектеги мектептин радиусуна кире албайт. Тандоо: (а) рецензент үчүн өзүнчө demo мектеп координаты/чоң радиус, (б) `review_demo` tenant, (в) demo bypass'ты кайтаруу.
- [ ] Түзмөк чектөөсүн (`device_binding_enabled`) качан күйгүзүү — азыр өчүк. Мугалимдер 1.1.3+5 версиясына өткөндөн кийин гана күйгүзүү керек.

# POST-MVP

## Уруксат агымы жана mobile release — 2026-09-09

- [x] 2026-09-10: GitHub CI `34308414691` толугу менен SUCCESS — backend, PostgreSQL integration, контейнер, mobile/web Flutter жана iOS. Signing кайра текшерилди: Android key.properties жок, Apple Development гана бар.

- [x] Teacher → PENDING арыз (күн/себеп), admin → APPROVED/REJECTED (чечимдин себеби); мектеп/роль чектөөсү, 50 саптык pagination, бир күнгө бир арыз, кайталанган бирдей request idempotent.
- [x] APPROVED гана EXCUSED түзөт; катышуу бар болсо конфликт; чечим, катышуу өзгөрүүсү жана аудит бир transaction ичинде. EXCUSED күндү QR менен үнсүз алмаштырууга тыюу салынды.
- [x] Mobile teacher/admin жана web admin уруксат экрандары: screen → Cubit → repository → API. Home мектеп маалыматын attendance Cubit аркылуу алат; history loading/error/race өзүнчө Cubit'ке бөлүндү.
- [x] Server attendance status resolver; mobile home/history/dashboard жана web dashboard/analytics чыпкалары статус боюнча бирдей эсептейт. Сабак кечигүү мүнөттөрү өзүнчө метрика, ON_TIME'ды client тарапта LATE кылбайт.
- [x] Refresh token суроолору mobile repository'лер арасында сериализацияланды; offline refresh токенди өчүрбөйт, revoked session login'ге өткөрөт; duplicate loading/submission жана disposed Cubit корголду.
- [x] `d24f5ca6e004` migration: өзүнчө локалдык PostgreSQL базасында upgrade жана `alembic check` өттү. SQLite roundtrip/role/decision/audit tests кошулду.
- [x] Reset диалогу жаңы уруксат арыздары да тазаланарын көрсөтөт; операция аккаунттарды жана аудитти сактайт. Production reset аткарылган жок.
- [x] Regression: backend 78, mobile 30 (анын ичинде cross-repository refresh), web 7; analyzer/Ruff таза; iOS Simulator жана Android debug build 1.1.0+2 даяр.
- [x] Backend `75270d1` Render Live (`dep-dagdd6ajnfac73f2n51g`), health 200, жаңы төрт leave route OpenAPI'де бар, авторизациясыз list endpoint'тери 401. Web Vercel READY (`dpl_3d59DPWScEWDWYfvFF2dJVifhBMy`), stable alias JS SHA256 жергиликтүү текшерилген build менен бирдей; CORS туура. Production маалыматтарга тесттик арыз жөнөтүлгөн жок.
- [x] iOS device release `--no-codesign` компиляциясы ийгиликтүү (20.1MB); бул кол коюлган IPA эмес.
- [x] Android production signing: 2026-09-10 user жаңы release key түзүүгө макул болду. Keystore ignored/0600, password Keychain'де; Gradle environment credentials жана кайра build кылуучу script даяр.
- [x] iOS version 1.1.1/build 3: `pubspec.yaml` жана generated Xcode config текшерилди; bundle ID/signing сакталды. TestFlight upload жасалган жок.
- [x] Android 1.1.1 release APK даяр: ARM64 27.3MB (versionCode 2003), ARMv7 23.3MB (1003); Flutter split-per-ABI offset колдонулат. Эки файл apksigner verify'дан өттү, release RSA3072 сертификаты бирдей, debug flag жок. Артефакттар `releases/teacher-1.1.1-build3-arm64.apk` жана `releases/teacher-1.1.1-build3-arm32.apk`.
- [x] iOS production signing: 2026-09-10 Cloud Managed Apple Distribution аркылуу App Store IPA 1.1.1/build 3 экспорттолду (`releases/ios-1.1.1-build3/teacher_mobile.ipa`). Transporter export конфигурациясы кошулду; user-owned үч iOS файл сакталды. Apple'га upload жасалган жок.
- [ ] Реалдуу iOS/Android камера/GPS E2E жана Transporter/App Store Connect validation/upload; кол коюлган Android APK жана iOS IPA даяр, бирок бул түзмөктөгү acceptance тесттин ордун баспайт.

## Mobile production UI — 1–3 (2026-09-09)

- [x] Mobile login/splash жана authenticated экрандардагы hardcoded «№1 Орто Мектеп» алынды; реалдуу school name серверден, жүктөлбөсө мектеп аты ойлоп табылбайт.
- [x] Teacher home жөнөкөйлөтүлдү: сервердин күнү/статусу, реалдуу график, келүү/кетүү, негизги QR action, тарых; loading/error/retry жана app resume/scan return refresh. Болжолдуу график жана телефон сааты алынды.
- [x] `/attendance/today` additive `display_status`: PENDING/ABSENT/EXCUSED/DAY_OFF/NO_SCHEDULE/ON_TIME/LATE. Мектептин сервер убактысы жана графиктин end_time чеги колдонулат; explicit records сакталат; жаңы DB enum же migration керек эмес.
- [x] Regression: backend 73, mobile 26, web 7 tests; mobile analyze, backend changed-file Ruff жана diff whitespace таза. 320px/1.8× text бардык 7 статус үчүн текшерилди.
- [x] Android debug APK жана iOS Simulator debug build ийгиликтүү. Учурдагы user-owned үч iOS конфигурация файлы өзгөртүлгөн жок.
- [x] Бул этаптын backend өзгөрүүсү мобилдик релизден мурда production'го чыгарылды (`display_status` жана school_name даяр).
- [ ] Физикалык iOS/Android түзмөктө камера/GPS end-to-end жана release signing текшерүү; бул этапта production deploy/маалымат тазалоо аткарылган жок.

- [x] Мугалимдин сапын басуу → өзүнчө URL менен аналитика экраны; профиль, 6 KPI, статус/айлык кечигүү графиктери, мезгил чыпкалары жана тарых.
- [x] Мугалим аналитикасы: сервердик дата, 1/7/30/бардык күн чектери, бош тарых, KPI/график суммалары unit test менен текшерилди.

- [x] Admin dashboard: бардык 5 KPI карточкасынан чыпкаланган деталдуу тизме ачылат.
- [x] Admin отчеттор: бүгүн, акыркы 7 күн, акыркы 30 күн жана бардык сакталган тарых; статус чыпкасы, дата, жүктөө катасын кайра аракет кылуу.
- [x] Иш күндөрдү bounded диапазондо автоматтык ABSENT кылуу; EXCUSED жазуулары өзгөртүлбөйт.
- [x] Admin attendance reset endpoint: так `RESET ATTENDANCE` ырастоосу жана audit log менен мектептин катышуу жазууларын тазалоо.
- [x] Web regression: карточка чыпкалары, мектеп убактысынын көрсөтүлүшү, деталдар жана бош тизме тесттери.
- [x] Чоң мектептер үчүн сервердик пагинацияланган жалпы отчет endpoint'и — `GET /attendance/history` (2026-09-18).

- [x] Registered device binding
- [ ] School Wi-Fi verification
- [ ] Dynamic QR optional mode
- [ ] Multiple campuses
- [x] Leave/permission requests
- [ ] Sick leave
- [ ] Telegram admin reports
- [ ] Payroll integration
- [ ] Student attendance module
- [ ] Multi-school SaaS
