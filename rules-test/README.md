# Kiểm thử Firestore rules

Test bảo mật cho [`../firestore.rules`](../firestore.rules) chạy trên Firebase
Emulator (không đụng dữ liệu thật — dùng project giả `demo-caro`).

## Yêu cầu
- Node + Firebase CLI (`npm i -g firebase-tools`)
- Java (cho Firestore Emulator)

## Chạy
```bash
npm install
npm test
```
Script tự copy `../firestore.rules` vào thư mục này (vì emulator không cho tham
chiếu file ngoài project) rồi chạy `test.mjs` bên trong emulator.

Bao phủ: khóa đọc `users`/`matches`, bảng tra cứu `friendCodes`, và chống gian
lận khi cập nhật ván (đúng lượt, thêm đúng một quân, không tráo/ghi đè bàn cờ).
