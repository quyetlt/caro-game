# Phát hành lên Google Play — quy trình build & upload

Quy trình lặp lại mỗi lần ra bản mới cho app **Cờ Caro** (`co-caro` /
`co-caro-b645d`).

## 0. Trước khi build

- [ ] Code cần phát hành đã merge/đúng nhánh.
- [ ] Nếu bản này đi kèm thay đổi Firestore rules → đọc
  [firestore-rules-rollout.md](firestore-rules-rollout.md) để biết thứ tự
  deploy (app trước, rules strict sau).

## 1. Tăng version

Sửa `version` trong [pubspec.yaml](../pubspec.yaml): dạng `versionName+versionCode`.

```yaml
version: 1.1.1+7
#        ^^^^^ ^
#        |     └─ versionCode: SỐ NGUYÊN, phải TĂNG DẦN mỗi lần upload (cho nhảy số)
#        └─────── versionName: chuỗi người dùng thấy (vd 1.1.1)
```

> ⚠️ Google Play **từ chối** nếu `versionCode` trùng hoặc nhỏ hơn bản đã upload.
> Cho phép gap (vd 6 → 7 dù 6 chưa dùng). Khi không chắc số nào đã dùng → cứ
> tăng lên số lớn hơn.

Lịch sử: versionCode 5 đã dùng trên Play → 1.1.0+6 → hiện tại **1.1.1+7**.

## 2. Build Android App Bundle (.aab)

Google Play yêu cầu **AAB** (không phải APK).

```bash
flutter build appbundle --release
```

- Kết quả: `build/app/outputs/bundle/release/app-release.aab`
- Cảnh báo "failed to strip debug symbols" là **warning**, không chặn — file
  vẫn tạo ra bình thường.

## 3. Xác minh đã ký bằng release key

```bash
jarsigner -verify -verbose:summary -certs \
  build/app/outputs/bundle/release/app-release.aab | grep -E "jar verified|CN="
```

- Phải thấy `jar verified.` và `CN=Quyet LT, OU=Dev, O=quyetlt, ...`
  (đó là key `caro-key`). Nếu thấy debug key → sai, Play sẽ từ chối.

## 4. Cấu hình ký (đã thiết lập sẵn — chỉ tham khảo khi hỏng)

- **Keystore:** `android/app/caro-key.jks` (cũng có bản sao ở gốc repo).
- **Mật khẩu/alias:** `android/key.properties` (alias `caro-key`).
- **Build script:** `android/app/build.gradle.kts` đọc `key.properties` cho
  `signingConfigs.release`.
- ⚠️ `*.jks` và `key.properties` **bị `.gitignore`** — KHÔNG commit. Sao lưu
  keystore ở nơi an toàn; mất là không cập nhật được app nữa.

## 5. Upload lên Play Console

1. [Play Console](https://play.google.com/console) → app **Cờ Caro**.
2. Chọn track: **Internal testing** (thử) hoặc **Production** (chính thức).
3. **Create new release** → **Upload** file `app-release.aab` ở bước 2.
4. Điền **Release notes** (song ngữ nếu cần).
5. **Review release** → **Start rollout**.

## 6. Sau khi phát hành

- [ ] Tạo git tag cho bản phát hành (vd `git tag v1.1.1+7 && git push --tags`).
- [ ] Nếu có rules strict đang chờ (STEP 2): đợi người dùng cập nhật rồi mới
  `firebase deploy --only firestore:rules --project co-caro-b645d`.

## Tham khảo nhanh — toàn bộ lệnh

```bash
# 1. (sửa version trong pubspec.yaml)
# 2. build
flutter build appbundle --release
# 3. verify
jarsigner -verify build/app/outputs/bundle/release/app-release.aab
# 4. upload thủ công qua Play Console
```
