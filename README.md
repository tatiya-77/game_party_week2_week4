# Game Party Week 2–4

มีหน้า Login/Register, โพสต์ Firestore, ค้นหา, แชทชุมชน และแนบรูป Firebase Storage

## ติดตั้งและเชื่อม Firebase
1. แตก ZIP แล้วเปิดโฟลเดอร์ใน VS Code
2. `flutter pub get`
3. ติดตั้ง/ล็อกอิน/ตั้งค่า Firebase: `dart pub global activate flutterfire_cli` จากนั้น `firebase login` และ `flutterfire configure`
4. คำสั่ง `flutterfire configure` จะสร้าง `lib/firebase_options.dart` แทนไฟล์ placeholder ที่ให้มา
5. ใน Firebase Console เปิด Email/Password ใน Authentication, สร้าง Firestore Database และเปิด Storage
6. รัน `flutter run -d chrome` หรือเลือก Android device แล้ว `flutter run`

ต้องผูก Firebase project ของคุณก่อนใช้งานจริง; ZIP ไม่สามารถมี config หรือ credential ของบัญชีคุณได้

ตัวอย่าง Firestore rules สำหรับเดโมที่ต้องล็อกอิน:
```javascript
rules_version = '2';
service cloud.firestore {
 match /databases/{database}/documents {
  function signedIn(){return request.auth != null;}
  match /posts/{id} { allow read: if signedIn(); allow create: if signedIn() && request.resource.data.uid == request.auth.uid; allow update: if signedIn(); allow delete: if signedIn() && resource.data.uid == request.auth.uid; }
  match /messages/{id} { allow read: if signedIn(); allow create: if signedIn() && request.resource.data.uid == request.auth.uid; allow update, delete: if false; }
 }
}
```
ปรับ rules และจำกัด Storage access ก่อนเผยแพร่แอป
