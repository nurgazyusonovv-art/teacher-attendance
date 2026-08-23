# PROJECT.md

## 1. Project

**Working name:** Teacher Attendance  
**Type:** School employee attendance system  
**Platforms:** iOS, Android, Web Admin

Аталыш кийин бренд тандалганда өзгөртүлөт.

---

## 2. Максат

Мугалимдердин мектепке келген жана кеткен убактысын QR-код аркылуу так, тез жана борборлоштурулган түрдө каттоо.

Система төмөнкү маселелерди чечиши керек:

- кагаз журналды алып салуу;
- ким канчада келгенин автоматтык сактоо;
- кечигүүнү автоматтык эсептөө;
- келбегендерди аныктоо;
- администрацияга реалдуу убакыттагы маалымат берүү;
- апталык/айлык отчет түзүү;
- мугалимдин өзүнүн attendance тарыхын көрсөтүү;
- жалган каттоону мүмкүн болушунча азайтуу.

---

## 3. Негизги продукт чечими

### 3.1 QR

Мектепте **бир туруктуу QR-код** болот.

QR ичиндеги маалыматта:
- `school_id`
- `qr_token`

болот.

QR мугалимдин ким экенин аныктабайт.

Мугалимди:
- authentication token;
- teacher account

аныктайт.

### 3.2 Location

QR сканерленген учурда гана location алынат.

Система:
- мектептин координатын;
- мугалимдин учурдагы координатын;
- GPS accuracy;
- уруксат берилген радиусту

салыштырат.

Default MVP:

```text
allowed_radius = 80 m
maximum_accuracy = 50 m
```

Бул маанилер Admin Settings аркылуу өзгөртүлө тургандай архитектура курулат.

### 3.3 Time

Attendance убактысы телефондон алынбайт.

Backend өзүнүн server time'ын колдонот.

Мектептин timezone'у:

```text
Asia/Bishkek
```

### 3.4 Attendance

Негизги event типтери:

- `CHECK_IN`
- `CHECK_OUT`

Негизги status:

- `ON_TIME`
- `LATE`
- `ABSENT`
- `EXCUSED`
- `DAY_OFF`

MVP'де автоматтык түрдө:
- `ON_TIME`
- `LATE`

эсептелет.

`ABSENT` белгилөө scheduler/report логикасы аркылуу жүргүзүлөт.

---

## 4. Колдонуучу ролдору

### 4.1 Teacher

Мүмкүнчүлүктөр:
- login;
- QR scan;
- location permission;
- check-in;
- check-out;
- бүгүнкү статус;
- өзүнүн тарыхы;
- кечигүү статистикасы;
- logout.

Teacher жаңы аккаунтту өз алдынча түзбөйт.

### 4.2 Admin

Мүмкүнчүлүктөр:
- login;
- dashboard;
- мугалимдерди CRUD;
- schedule түзүү;
- бүгүнкү attendance;
- кечигүүлөр;
- келбегендер;
- attendance detail;
- manual correction;
- reports;
- school settings;
- QR configuration;
- demo/review data management.

### 4.3 Super Admin

MVP үчүн милдеттүү эмес.

Кийин SaaS/multi-school версия болсо кошулат.

---

## 5. Teacher App экрандары

1. Splash
2. Login
3. Home
4. QR Scanner
5. Scan Result
6. Attendance History
7. Attendance Detail
8. Profile
9. Permission Help
10. Offline/Error State

### Home

Көрсөтөт:
- мугалимдин аты;
- бүгүнкү дата;
- жумуш башталчу убакыт;
- check-in статус;
- check-out статус;
- чоң `QR СКАНЕРЛӨӨ` кнопкасы;
- айлык кыска статистика.

---

## 6. Admin Panel экрандары

1. Login
2. Dashboard
3. Today Attendance
4. Teachers
5. Teacher Detail
6. Schedules
7. Reports
8. Attendance Corrections
9. School Settings
10. QR Settings
11. Audit Log

### Dashboard KPI

- Жалпы мугалим
- Келди
- Өз убагында
- Кечикти
- Каттала элек
- Бүгүнкү орточо кечигүү

---

## 7. Attendance workflow

### Check-in

```text
Teacher taps Scan
→ camera opens
→ school QR detected
→ app requests/reads current location
→ app sends QR + location to API
→ backend verifies JWT
→ backend verifies QR
→ backend validates GPS accuracy
→ backend calculates distance
→ backend checks radius
→ backend gets server time
→ backend loads teacher schedule
→ backend calculates status and late_minutes
→ backend checks duplicate
→ backend saves attendance event
→ result returned
```

### Check-out

Ушундай эле flow, event type `CHECK_OUT`.

---

## 8. Кечигүүнү эсептөө

Мисал:

```text
scheduled_start = 08:00
grace_minutes = 0
server_check_in = 08:07
late_minutes = 7
status = LATE
```

Optional:

```text
grace_minutes = 5
08:04 → ON_TIME
08:06 → LATE 1 min
```

Grace period мектеп настройкасынан башкарылат.

---

## 9. Geofence

Backend Haversine формуласы же PostGIS колдонуп аралыкты эсептейт.

MVP үчүн кадимки формула жетиштүү.

Validation:

```text
if accuracy > maximum_accuracy:
    reject

if distance > allowed_radius:
    reject

else:
    location_verified = true
```

Location координатын attendance record'до сактабоо — default чечим.

Сакталуучу metadata:

```text
distance_meters
location_accuracy_meters
location_verified
```

---

## 10. QR Security

QR туруктуу болгону үчүн негизги коргоо QR эмес.

Коргоо катмарлары:

1. authenticated teacher;
2. valid school QR;
3. GPS geofence;
4. GPS accuracy;
5. server time;
6. duplicate protection;
7. audit log;
8. optional registered device.

MVPден кийин:
- device binding;
- school Wi-Fi validation;
- jailbreak/root signals;
- dynamic QR

кошууга болот.

---

## 11. Notifications

MVP Phase 2:

Teacher:
- жумуш башталганга 10 мүнөт калганда;
- check-in каттала элек болсо;
- кечигүү катталганда.

Admin:
- белгилүү убакытта келбегендердин саны;
- күндүн attendance summary.

Push:
- Firebase Cloud Messaging / APNs.

---

## 12. Privacy

Location:
- QR сканерлөө процессинде гана;
- background tracking жок;
- `When In Use` permission;
- location attendance текшерүү үчүн гана.

Так координаталарды тарыхта сактабоо.

Privacy Policy төмөнкүлөрдү түшүндүрөт:
- кандай маалымат чогултулат;
- эмне үчүн;
- ким көрө алат;
- канча убакыт сакталат;
- өчүрүү тартиби.

---

## 13. App Store Strategy

iOS үчүн:

1. Production app даярдоо.
2. Privacy Policy даярдоо.
3. App Privacy answers толтуруу.
4. Camera жана Location usage descriptions.
5. App Review үчүн demo account.
6. Review режимде GPS тоскоолдугун алып салган **атайын demo dataset/workflow**.
7. Reviewer үчүн Demo QR.
8. Review Notes ичинде production geofence логикасын түшүндүрүү.
9. App Review өткөндөн кийин Unlisted distribution сурап көрүү.

Demo Mode production security'ди айланып өтүүчү жашыруун backdoor болбошу керек.

Сунуш:
- backend'де өзүнчө `review_demo` tenant/data;
- real teacher data жок;
- demo account гана demo workflow колдонот.

---

## 14. Технология

### Flutter Teacher App

- Flutter latest stable
- Dart
- flutter_bloc / cubit
- go_router
- dio
- flutter_secure_storage
- mobile_scanner
- geolocator
- permission_handler

### Flutter Web Admin

- Flutter Web
- flutter_bloc
- go_router
- dio
- responsive layout

### Backend

- Python
- FastAPI
- PostgreSQL
- SQLAlchemy 2
- Alembic
- Pydantic v2
- JWT
- passlib/argon2
- Docker

---

## 15. Backend Modules

```text
app/
├── api/
├── core/
├── models/
├── schemas/
├── services/
├── repositories/
├── security/
├── utils/
└── main.py
```

Domain modules:

- auth
- teachers
- schools
- attendance
- schedules
- qr
- reports
- notifications
- audit

---

## 16. Core entities

- User
- Teacher
- School
- WorkSchedule
- AttendanceEvent
- DailyAttendance
- QrCredential
- Device
- AuditLog
- Notification

---

## 17. Non-goals MVP

MVPде жок:

- Face ID аркылуу attendance
- fingerprint attendance
- background location monitoring
- salary calculation
- payroll
- student attendance
- multi-school SaaS
- complex HR management
- biometric database

---

## 18. Definition of Done

MVP даяр деп эсептелет, эгер:

- Teacher login иштейт;
- бир туруктуу QR сканерленет;
- GPS мектеп радиусун сервер текшерет;
- убакыт серверден алынат;
- late_minutes автоматтык эсептелет;
- check-in/check-out базага түшөт;
- duplicate scan блоктолот;
- teacher history иштейт;
- admin today dashboard иштейт;
- reports иштейт;
- permission/error states иштелген;
- real coordinates attendance тарыхында сакталбайт;
- audit log бар;
- App Review demo account иштейт;
- iOS жана Android production build алынат.
