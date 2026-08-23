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
> Apple App Reviewer can test the full end-to-end check-in and check-out workflow from any location in the world without being physically inside the school geofence by using the dedicated Demo credentials below.

### Reviewer Credentials:
- **Teacher Account:** `demo_teacher`
- **Password:** `demo123`
- **Role:** Teacher (with `is_demo = true` bypass flag)

### Reviewer Step-by-Step Instructions:
1. Open the app on iPhone / iPad simulator or real device.
2. Log in using `demo_teacher` and `demo123`.
3. Tap on the prominent **"КЕЛҮҮ QR СКАНЕРЛӨӨ"** (Scan QR) button on the Home screen.
4. Allow Camera and Location permissions when prompted.
5. Scan the following JSON payload rendered on another screen or printable paper:
```json
{
  "school_id": "a6195276-01ee-408a-955b-d97194fd3db3",
  "qr_token": "school-qr-demo-token-12345"
}
```
6. The app will immediately register the Check-in and show a green success dialog.
7. Return to the Home screen to see the updated status and check-in timestamp.
8. Tap on **"КЕТҮҮ QR СКАНЕРЛӨӨ"** (Scan Check-out QR) to register check-out and view total worked minutes.
9. Tap on **"Каттоо тарыхы"** (History) to see the recorded attendance history.

---

## 3. Privacy & Permission Strings in `Info.plist`

- `NSCameraUsageDescription`: *"Мектептин эшигиндеги же дубалындагы QR-кодду сканерлөө үчүн камерага уруксат керек."* (Required to scan the official school QR code for attendance check-in).
- `NSLocationWhenInUseUsageDescription`: *"Мугалим мектептин аймагында экендигин текшерүү үчүн геолокация колдонулат. Колдонмо фондо иштебейт жана координаталар базада сакталбайт."* (Used strictly during QR scan to verify teacher presence within the school premises).
