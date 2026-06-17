# Bật chế độ chơi Online (Firebase)

App chạy được ngay mà **không cần** Firebase (chế độ *Chơi với AI* và *Hai người 1 máy*).
Chế độ **Chơi online** (ghép trận, mã phòng, kết bạn) cần một project Firebase.
Mỗi project chỉ cần làm 1 lần.

## 1. Tạo project Firebase
1. Vào https://console.firebase.google.com → **Add project**.
2. Vào **Build → Authentication → Sign-in method** → bật **Anonymous**.
3. Vào **Build → Firestore Database** → **Create database** (chọn vùng gần bạn,
   khởi tạo ở chế độ *production*).

## 2. Gắn Firebase vào app Flutter
Cài CLI một lần:
```bash
dart pub global activate flutterfire_cli
# Đăng nhập Firebase nếu chưa: npm i -g firebase-tools && firebase login
```
Rồi trong thư mục dự án:
```bash
flutterfire configure
```
Lệnh này tự sinh lại `lib/firebase_options.dart` với cấu hình thật và thêm
file cấu hình cho Android/iOS.

## 3. Bật cờ online
Mở `lib/firebase_config.dart` và đổi:
```dart
const bool kFirebaseEnabled = true;
```

## 4. Nạp security rules
Trong Firebase Console → **Firestore → Rules**, dán nội dung file
[`firestore.rules`](firestore.rules) rồi **Publish**. (Hoặc dùng Firebase CLI:
`firebase deploy --only firestore:rules`.)

## 5. (Khuyến nghị) Index ghép trận ngẫu nhiên
Truy vấn ghép trận lọc theo `mode` + `status`. Nếu Firestore yêu cầu composite
index, console sẽ hiện link tạo index tự động khi chạy lần đầu — bấm vào link đó.

---

## Mô hình dữ liệu
- `users/{uid}`: `displayName`, `friendCode`, `online`, `lastSeen`
  - `friends/{friendUid}`: `{ name }`
  - `invites/{id}`: `{ matchId, fromUid, fromName }`
- `matches/{id}`: `mode` (room|random|friend), `status`
  (waiting|playing|finished|abandoned), `hostUid/hostName` (X),
  `guestUid/guestName` (O), `moves[]`, `turn`, `winner`, `roomCode`,
  cờ `rematchHost/rematchGuest`.

Logic đánh cờ và kiểm tra thắng/hòa chạy trong **transaction** phía client để
chống tranh chấp; server (rules) đảm bảo chỉ người trong ván mới ghi được.
