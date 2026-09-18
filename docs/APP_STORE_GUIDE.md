# App Store Submission & Reviewer Guide

## 1. App Store Connect Metadata

- **App Name:** Мугалим — Катышууну көзөмөлдөө (Mugalim — Teacher Attendance)
- **Subtitle:** Мектептеги катышууну санарип каттоо
- **Primary Category:** Education (Билим берүү)
- **Secondary Category:** Productivity (Өндүрүмдүүлүк)
- **Age Rating:** 4+
- **Languages:** Kyrgyz (Primary), Russian, English
- **Keywords:** мугалим, катышуу, мектеп, билим берүү, сабак, attendance, teacher, school, qr scanner, kyrgyzstan

### Description (Кыргызча / English):
"Мугалим: Катышууну көзөмөлдөө" — мектептер жана билим берүү мекемелери үчүн мугалимдердин жумушка келүү-кетүүсүн автоматташтырылган түрдө эсепке алуучу мобилдик тиркеме. 
- Мектептин расмий QR-кодун заматта сканерлөө;
- GPS Geofence аркылуу мектеп аймагында гана каттоого мүмкүндүк берүү;
- Жумалык жумуш графигин жана катышуу тарыхын көрүү;
- Сервердик так убакыт менен кечиккен мүнөттөрдү ачык-айкын эсептөө.

---

## 2. App Review Test Credentials (App Store Reviewer)

> [!IMPORTANT]
> The App Reviewer can complete the full check-in and check-out workflow from
> anywhere in the world. This works through an **isolated review tenant**, not
> through a bypass in the production code path.

### How it works

The reviewer account belongs to its own school (`DEMO-001`, "App Review Demo
School") that is flagged `is_review_demo` and configured with a worldwide
`allowed_radius_meters`. Every request runs the same QR, GPS, server-time and
duplicate checks as production — only this one school's radius is wide.

Two guarantees keep the production system unaffected:

- The review school contains no real teacher data.
- A non-demo account that tries to record attendance against the review school
  is rejected with `REVIEW_SCHOOL_FORBIDDEN`, so the wide radius can never
  serve a real teacher.

The production school keeps its real geofence (80 m by default). There is no
account flag that skips the geofence: an account marked `is_demo` inside an
ordinary school is rejected outside that school's radius exactly like any
other teacher.

### Provisioning the tenant on a deployment

The review tenant is created by its own script, never by `scripts/seed.py` —
the full seed would also insert a fake administrator and a fake teacher into
the real school, where they would appear in the dashboard, the reports and the
absence counts.

```
ALLOW_REVIEW_TENANT_PROVISION=true REVIEW_DEMO_PASSWORD='...' \
  python scripts/provision_review_tenant.py
```

It is idempotent and never rotates an existing password, so it is safe to
re-run. It prints the `school_id` and `qr_token` for the review notes;
`scripts/print_review_demo_qr.py` reprints them later without writing anything.

To set a new password, add `REVIEW_DEMO_ROTATE_PASSWORD=true`. This is the only
way to change it: an administrator is scoped to their own school and cannot
reach the demo account. Rotating revokes every existing session.

### Verifying before submission

```
REVIEW_DEMO_PASSWORD='...' python scripts/verify_review_flow.py
```

Signs in as the demo teacher and performs the reviewer's exact sequence —
check-in and check-out from Cupertino coordinates, history, and a rejected
invalid QR — against the live API. Attendance rows land in the demo tenant
only.

### Reviewer Credentials:
- **Teacher Account:** `demo_teacher`
- **Password:** provided in App Store Connect review notes
- **Role:** Teacher, in the isolated App Review Demo School

### Reviewer Step-by-Step Instructions:
1. Open the app on iPhone / iPad simulator or real device.
2. Log in using the demo credentials from the review notes.
3. Tap the prominent **"КЕЛҮҮ QR СКАНЕРЛӨӨ"** (Scan QR) button on the Home screen.
4. Allow Camera and Location permissions when prompted.
5. Scan the demo school QR code supplied with the submission. Its payload has
   the shape below; the real `school_id` and `qr_token` are issued per
   deployment and included in the review notes, because the QR token is
   generated randomly and rotated rather than hardcoded.
```json
{
  "type": "school_attendance",
  "school_id": "<demo school id from review notes>",
  "qr_token": "<demo qr token from review notes>"
}
```
6. The app registers the check-in and shows a green success dialog.
7. Return to the Home screen to see the updated status and check-in timestamp.
8. Tap **"КЕТҮҮ QR СКАНЕРЛӨӨ"** (Scan Check-out QR) to register check-out and view total worked minutes.
9. Tap **"Каттоо тарыхы"** (History) to see the recorded attendance history.

> [!NOTE]
> Device binding (one approved device per teacher) is off by default and is not
> enabled for the review tenant, so the reviewer never needs an approval step.

---

## 3. Privacy & Permission Strings in `Info.plist`

- `NSCameraUsageDescription`: *"Мектептин эшигиндеги же дубалындагы QR-кодду сканерлөө үчүн камерага уруксат керек."* (Required to scan the official school QR code for attendance check-in).
- `NSLocationWhenInUseUsageDescription`: *"Мугалим мектептин аймагында экендигин текшерүү үчүн геолокация колдонулат. Колдонмо фондо иштебейт жана координаталар базада сакталбайт."* (Used strictly during QR scan to verify teacher presence within the school premises).
