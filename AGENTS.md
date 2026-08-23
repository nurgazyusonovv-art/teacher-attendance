# AGENTS.md

Бул файл Codex/AI агент проектте иштегенде аткара турган эрежелерди аныктайт.

## 1. Негизги принцип

Тапшырманы аткарууда биринчи орунда:

1. Security
2. Attendance data integrity
3. Privacy
4. Maintainability
5. UX
6. Performance

---

## 2. Архитектураны бузбоо

Өз алдынча төмөнкүлөрдү өзгөртпө:

- Flutter → башка mobile framework;
- FastAPI → башка backend;
- PostgreSQL → башка database;
- server-side attendance time;
- QR + GPS validation;
- location privacy концепциясы.

Мындай чоң өзгөртүү керек болсо, TASKS.md ичинде өзүнчө сунуш катары белгиленсин.

---

## 3. Mobile architecture

Feature-first структура колдон:

```text
lib/
├── app/
├── core/
├── features/
│   ├── auth/
│   ├── attendance/
│   ├── history/
│   └── profile/
└── main.dart
```

Ар бир feature:

```text
feature/
├── data/
├── domain/
└── presentation/
```

State management:
- Cubit/Bloc.

Networking:
- Dio.

Token:
- flutter_secure_storage.

---

## 4. Backend architecture

Business logic router ичинде жазылбасын.

Тартип:

```text
router
→ service
→ repository
→ database
```

Attendance validation service өзүнчө болсун.

Мисалы:

```text
AttendanceService.register_check_in()
LocationVerificationService.verify()
QrService.validate()
ScheduleService.resolve_schedule()
```

---

## 5. Attendance time

КАТУУ ЭРЕЖЕ:

Mobile client жиберген `current_time` attendance үчүн ишенимдүү маалымат катары колдонулбасын.

Backend:

```python
server_now = current_time_in_school_timezone()
```

колдонот.

---

## 6. Location

GPS validation backendде аткарылат.

Client:
- latitude;
- longitude;
- accuracy

жиберет.

Backend:
- distance эсептейт;
- radius текшерет;
- accuracy текшерет.

Attendance негизги таблицасына latitude/longitude сакталбасын.

---

## 7. QR

QR payload эч качан teacher identity болбошу керек.

QR:
- school identifier;
- credential/token

үчүн гана.

QR token source code'го hardcode кылынбасын.

---

## 8. Security

Талаптар:

- JWT access token
- refresh token
- secure password hash
- rate limiting үчүн даяр структура
- failed login protections
- admin authorization
- audit trail
- input validation

Admin endpoint'тер роль аркылуу корголсун.

---

## 9. Privacy

Background location кошпо.

Location:
- attendance scan учурда гана;
- мүмкүн болушунча кыска убакыт колдонулат.

Sensitive маалыматты log'го чыгарба:
- password;
- JWT;
- raw GPS;
- refresh token.

---

## 10. Error handling

User-facing ката техникалык stack trace болбошу керек.

Мисал:

```text
LOCATION_OUTSIDE_SCHOOL
LOCATION_ACCURACY_TOO_LOW
QR_INVALID
ALREADY_CHECKED_IN
NO_SCHEDULE
PERMISSION_DENIED
NETWORK_ERROR
```

Client бул коддорду кыргызча түшүнүктүү билдирүүгө айландырат.

---

## 11. UI

Teacher App:
- жөнөкөй;
- бир кол менен колдонууга ыңгайлуу;
- негизги action — QR Scan;
- статус дароо көрүнсүн.

Admin:
- desktop-first responsive;
- таблицалар;
- фильтрлер;
- KPI;
- export үчүн даяр структура.

---

## 12. Testing

Ар бир attendance business rule unit test менен жабылсын.

Милдеттүү test cases:

- on time;
- late;
- outside radius;
- poor GPS accuracy;
- invalid QR;
- duplicate check-in;
- duplicate check-out;
- check-out before check-in;
- no schedule;
- demo account;
- timezone.

---

## 13. Database migrations

Schema өзгөрсө:
- Alembic migration сөзсүз.

Production database кол менен өзгөртүлбөсүн.

---

## 14. API versioning

REST:

```text
/api/v1/
```

колдон.

Breaking API өзгөртүү болсо жаңы version талап кылынат.

---

## 15. Git workflow

Commit майда жана түшүнүктүү болсун.

Мисал:

```text
feat(attendance): add geofence validation
fix(auth): refresh expired access token
test(attendance): cover duplicate check-in
```

---

## 16. TASKS.md

Ар бир тапшырма бүткөндө:
- checkbox жаңырт;
- acceptance criteria аткарылганын текшер;
- кийинки phase'ге өз алдынча өтүүдөн мурда regression тест жүргүз.

---

## 17. App Review

Demo/review flow production teacher data'га жетпесин.

Review mode:
- өзүнчө demo user;
- өзүнчө demo records;
- production geofence'ти глобалдык disable кылбашы керек.

---

## 18. Do not

Тыюу салынат:

- phone time'га ишенүү;
- raw password сактоо;
- GPS'ти күнү бою track кылуу;
- координаталарды attendance history'ге негизсиз сактоо;
- QR сканерленди деп location текшербей attendance түзүү;
- admin permission'сиз attendance correction;
- audit log'суз manual correction;
- production secrets Git'ке кошуу.
