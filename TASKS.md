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
- [ ] Android release signing key provisioning — debug-key fallback алынды, fail-closed config даяр
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

### Phase 3 — performance (кийинки)
- [ ] Admin dashboard N+1: `resolve_schedule_for_date` ар бир мугалим үчүн өзүнчө чакырылат (`attendance_service.py`).
- [ ] `get_teacher_history` бардык саптарды жүктөп, year/month'ту Python'да чыпкалайт; SQL чыпкасы + pagination керек.
- [ ] Composite index: `daily_attendance(school_id, date)`, `attendance_events(teacher_id, event_time)`, `lesson_delays(school_id, date)`.
- [ ] `finalize_absences`'ти batch query'ге өткөрүү (азыр күн × мугалим боюнча цикл).

### Phase 4 — client correctness (кийинки)
- [ ] `DateTimeUtils`'те UTC+6 катып калган (3 жер) — backend `school.timezone`'ду туура колдонот, клиент аны эске албайт.
- [ ] `formatBishkekTime`: microsecond'у бар naive ISO сап (`contains('-') && length > 19`) UTC деп эсептелип, +6 саат жылдырылат.
- [ ] Offline cache'тин күн чеги клиенттин саатына таянат (`attendance_repository.dart`).

### Phase 5 — maintainability (релизди тоспойт)
- [ ] `web_admin`'дин 7 feature'инин 5'и Cubit'ти айланып өтөт (dashboard, teachers, schedules, reports, settings — `setState` + түз repository). AGENTS.md #3.
- [ ] API жообунун формасы эки башка: `/auth/*` → `StandardResponse`, калгандары → түз модель.
- [ ] `attendance_service.py` ~900 сап; `DailyAttendanceRead` 6 жолу, `LessonDelayRead` 5 жолу кол менен түзүлөт — mapper'лерге чыгаруу.
- [ ] Өлүк код: `AppConstants.defaultBaseUrl` setter жана `keyBaseUrl` эч жерде колдонулбайт.
- [ ] Default'тордун карама-каршылыгы: `SchoolBase.grace_minutes`=5 жана `ScheduleCreate.grace_minutes`=15, ал эми модель default'у 0 жана PROJECT.md 0. Бул кимдин LATE экенин үнсүз өзгөртөт — админ менен макулдашып чечүү керек.
- [ ] Mobile ичиндеги админ панели (5 519 сап, `lib`'тин 44%) web_admin менен кайталанат — продукт чечими же жалпы пакетке чыгаруу.
- [ ] `attendance_start_date`'ти орнотуу үчүн web admin settings экранына талаа кошуу (азыр `PATCH /schools/{id}` аркылуу гана).

### Deploy эскертүүсү
- [ ] `e35f1cb7d005` migration'ды production'го жүргүзүү, Render'де `teacher-attendance-finalize-absences` cron сервисин жана `SECRETS_ENCRYPTION_KEY` env var'ын түзүү (ал жок болсо SECRET_KEY'ге түшөт — бул учурда SECRET_KEY rotate кылынганда Telegram токен окулбай калат). Cron түзүлгөнгө чейин ABSENT жазуулары автоматтык жазылбайт (dashboard'дун `display_status`'у мурдагыдай туура иштейт, тарых/отчет үчүн кол менен `POST /attendance/admin/catch-up-absences` чакырса болот).

# POST-MVP

## Уруксат агымы жана mobile release — 2026-09-09

- [x] Teacher → PENDING арыз (күн/себеп), admin → APPROVED/REJECTED (чечимдин себеби); мектеп/роль чектөөсү, 50 саптык pagination, бир күнгө бир арыз, кайталанган бирдей request idempotent.
- [x] APPROVED гана EXCUSED түзөт; катышуу бар болсо конфликт; чечим, катышуу өзгөрүүсү жана аудит бир transaction ичинде. EXCUSED күндү QR менен үнсүз алмаштырууга тыюу салынды.
- [x] Mobile teacher/admin жана web admin уруксат экрандары: screen → Cubit → repository → API. Home мектеп маалыматын attendance Cubit аркылуу алат; history loading/error/race өзүнчө Cubit'ке бөлүндү.
- [x] Server attendance status resolver; mobile home/history/dashboard жана web dashboard/analytics чыпкалары статус боюнча бирдей эсептейт. Сабак кечигүү мүнөттөрү өзүнчө метрика, ON_TIME'ды client тарапта LATE кылбайт.
- [x] Refresh token суроолору mobile repository'лер арасында сериализацияланды; offline refresh токенди өчүрбөйт, revoked session login'ге өткөрөт; duplicate loading/submission жана disposed Cubit корголду.
- [x] `d24f5ca6e004` migration: өзүнчө локалдык PostgreSQL базасында upgrade жана `alembic check` өттү. SQLite roundtrip/role/decision/audit tests кошулду.
- [x] Reset диалогу жаңы уруксат арыздары да тазаланарын көрсөтөт; операция аккаунттарды жана аудитти сактайт. Production reset аткарылган жок.
- [x] Regression: backend 78, mobile 29 жалпы + cross-repository refresh жаңы тести, web 7; analyzer/Ruff таза; iOS Simulator жана Android debug build 1.1.0+2 даяр.
- [ ] Backend жана web deployment smoke текшерүүлөрүн толуктоо.
- [ ] Android production signing: `mobile/android/key.properties` жана keystore жок; эски signing key керек (жаңы ачкыч өз алдынча түзүлгөн жок).
- [ ] iOS production signing: Apple Development identity бар, Apple Distribution жок; Distribution сертификаты/private key жана provisioning керек. User-owned үч iOS файл сакталды.
- [ ] Реалдуу iOS/Android камера/GPS E2E жана кол коюлган APK/AAB/IPA; debug/unsigned build production release катары берилбейт.

## Mobile production UI — 1–3 (2026-09-09)

- [x] Mobile login/splash жана authenticated экрандардагы hardcoded «№1 Орто Мектеп» алынды; реалдуу school name серверден, жүктөлбөсө мектеп аты ойлоп табылбайт.
- [x] Teacher home жөнөкөйлөтүлдү: сервердин күнү/статусу, реалдуу график, келүү/кетүү, негизги QR action, тарых; loading/error/retry жана app resume/scan return refresh. Болжолдуу график жана телефон сааты алынды.
- [x] `/attendance/today` additive `display_status`: PENDING/ABSENT/EXCUSED/DAY_OFF/NO_SCHEDULE/ON_TIME/LATE. Мектептин сервер убактысы жана графиктин end_time чеги колдонулат; explicit records сакталат; жаңы DB enum же migration керек эмес.
- [x] Regression: backend 73, mobile 26, web 7 tests; mobile analyze, backend changed-file Ruff жана diff whitespace таза. 320px/1.8× text бардык 7 статус үчүн текшерилди.
- [x] Android debug APK жана iOS Simulator debug build ийгиликтүү. Учурдагы user-owned үч iOS конфигурация файлы өзгөртүлгөн жок.
- [ ] Бул этаптын backend өзгөрүүсүн мобилдик релизден мурда deploy кылуу (`display_status` жок эски серверде белгисиз статус коопсуз түрдө QR action'ду өчүрөт).
- [ ] Физикалык iOS/Android түзмөктө камера/GPS end-to-end жана release signing текшерүү; бул этапта production deploy/маалымат тазалоо аткарылган жок.

- [x] Мугалимдин сапын басуу → өзүнчө URL менен аналитика экраны; профиль, 6 KPI, статус/айлык кечигүү графиктери, мезгил чыпкалары жана тарых.
- [x] Мугалим аналитикасы: сервердик дата, 1/7/30/бардык күн чектери, бош тарых, KPI/график суммалары unit test менен текшерилди.

- [x] Admin dashboard: бардык 5 KPI карточкасынан чыпкаланган деталдуу тизме ачылат.
- [x] Admin отчеттор: бүгүн, акыркы 7 күн, акыркы 30 күн жана бардык сакталган тарых; статус чыпкасы, дата, жүктөө катасын кайра аракет кылуу.
- [x] Иш күндөрдү bounded диапазондо автоматтык ABSENT кылуу; EXCUSED жазуулары өзгөртүлбөйт.
- [x] Admin attendance reset endpoint: так `RESET ATTENDANCE` ырастоосу жана audit log менен мектептин катышуу жазууларын тазалоо.
- [x] Web regression: карточка чыпкалары, мектеп убактысынын көрсөтүлүшү, деталдар жана бош тизме тесттери.
- [ ] Чоң мектептер үчүн сервердик пагинацияланган жалпы отчет endpoint'и (азыр бардык teacher pages + 4 параллелдүү history request колдонулат).

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
