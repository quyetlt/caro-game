# Triển khai Firestore Rules — quy trình & trạng thái

Tài liệu vận hành cho `firestore.rules`. Đọc trước khi deploy rules để không
làm hỏng các bản app đang chạy.

## Hai file rules

| File | Vai trò | `/users` đọc | Đã deploy? |
|---|---|---|---|
| `firestore.transitional.rules` | Bản chuyển tiếp, tương thích ngược | **Mở** (`signedIn`) | ✅ Đang chạy trên production |
| `firestore.rules` | Bản đích (strict) | **Khóa** (self + bạn bè, tắt `list`) | ⏳ Chưa — chờ app release |

Cả hai **giống hệt nhau** ở phần `matches` (chống gian lận) và `friendCodes`.
Chỉ khác ở khối `/users`.

## Vì sao phải 2 bước

Bản app v1.1.0 đã phát hành tra cứu bạn bằng cách **query `/users`** theo
`friendCode`. Nếu khóa `/users` (bản strict) trước khi người dùng cập nhật app,
tính năng kết bạn-bằng-mã sẽ **hỏng trên mọi bản đã cài**.

Giải pháp: app mới (>= 1.1.1) tra cứu qua collection **`/friendCodes`** thay vì
`/users`. Khi đa số người dùng đã cập nhật → mới khóa `/users`.

- **Code liên quan:** [auth_service.dart](../lib/services/auth_service.dart)
  (ghi `friendCodes/{code}`), [friend_service.dart](../lib/services/friend_service.dart)
  (tra cứu qua `friendCodes`).

## Trạng thái hiện tại (cập nhật 2026-06-18)

- ✅ **STEP 1 đã xong:** `firestore.transitional.rules` đã deploy lên
  production (`co-caro-b645d`). Chống gian lận `matches` + `/friendCodes` đã
  có hiệu lực; `/users` vẫn mở nên không bản app nào bị hỏng.
- ✅ App **1.1.1+7** đã build (chứa lookup `/friendCodes`) — chờ phát hành Play.
- ⏳ **STEP 2 chưa làm:** deploy `firestore.rules` (strict) để khóa `/users`.

## STEP 2 — làm khi nào & thế nào

**Điều kiện:** app 1.1.1+ đã lên Google Play và **đa số người dùng đã cập nhật**
(thường đợi vài ngày sau khi rollout).

**Lệnh deploy** (file `firebase.json` đã trỏ sẵn vào `firestore.rules`):

```bash
firebase deploy --only firestore:rules --project co-caro-b645d
```

Sau STEP 2: người dùng cũ chưa cập nhật sẽ không kết bạn-bằng-mã được nữa —
đây là sự đánh đổi đã chấp nhận.

## Test rules trước khi deploy

Bộ test chạy trên Firebase Emulator (không đụng dữ liệu thật):

```bash
cd rules-test
npm install        # lần đầu
npm test           # test bản strict (firestore.rules) — 24 assertion
```

- Test bản strict: `rules-test/test.mjs`
- Test bản chuyển tiếp: `rules-test/test_transitional.mjs`
- Yêu cầu: Node, Firebase CLI, Java (cho emulator).

## Tóm tắt nội dung rules

- **users**: (strict) chỉ đọc hồ sơ của mình hoặc bạn bè; tắt `list`.
- **friendCodes**: tra cứu bằng mã chính xác; không liệt kê; chỉ ghi mã trỏ về
  chính mình.
- **matches read**: chỉ đọc ván mình chơi hoặc ván `waiting` (ghép trận).
- **matches update (chống gian lận)**: khóa `hostUid/guestUid/mode/roomCode/createdAt`;
  đánh quân phải đúng lượt, thêm đúng 1 quân của mình, lượt chuyển đối thủ;
  cập nhật khác không được tráo/ghi đè bàn cờ (chỉ xóa sạch để chơi lại).
