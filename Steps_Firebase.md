# خطوات إعداد Firebase والخدمات الخارجية
## PSGA Personal Security Guard App

**ملاحظة:** لقد تم نقل توثيق الخدمات الخارجية الشاملة إلى ملف منفصل:  
📄 **External_Services_Setup.md** - يحتوي على كل التفاصيل عن Firebase و Google Maps APIs

---

## 📋 متطلبات Pre-Setup

- [ ] Firebase Project تم إنشاؤه
- [ ] Firestore Database تم تفعيله
- [ ] Authentication تم تفعيله
- [ ] google-services.json تم تحميله

---

## ✅ خطوات الإعداد الكاملة

### 1. Firebase Console Setup

```
1. انتقل إلى https://console.firebase.google.com
2. اختر المشروع أو أنشِ جديداً
3. اذهب إلى Firestore Database
4. اختر Start in Production Mode
5. حدد المنطقة (مثل: us-central1)
6. في Authentication، فعّل:
   - Email/Password
   - Google Sign-In
7. قم بتحميل google-services.json في المشروع
```

### 2. Firestore Rules (Production)

اذهب إلى Firestore → Rules وأضف:

```firebase
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
      allow read: if request.auth != null && 
                     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Routes collection
    match /routes/{routeId} {
      allow read, write: if request.auth.uid == resource.data.userId;
      allow create: if request.auth.uid == request.resource.data.userId;
    }
    
    // Trips collection
    match /trips/{tripId} {
      allow read, write: if request.auth.uid == resource.data.userId;
      allow create: if request.auth.uid == request.resource.data.userId;
    }
    
    // Alerts collection
    match /alerts/{alertId} {
      allow read, write: if request.auth.uid == resource.data.userId;
      allow create: if request.auth.uid == request.resource.data.userId;
    }
    
    // Contacts collection
    match /contacts/{contactId} {
      allow read, write: if request.auth.uid == resource.data.userId;
      allow create: if request.auth.uid == request.resource.data.userId;
    }
  }
}
```

### 3. التحقق من Collections في Firestore

يجب أن تظهر هذه Collections تلقائياً عند أول عملية sync:

```
firestore/
├── users/
├── routes/
├── trips/
├── alerts/
└── contacts/
```

---

## 🔄 آلية المزامنة - Phase 5

### التدفق الكامل:

```
┌─────────────────────────────────────────┐
│  المستخدم ينفذ عملية (create/update)   │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  1. حفظ محلي في Hive (فوراً)           │
│  2. إضافة إلى SyncQueue                │
│  3. إرجاع البيانات للـ UI              │
└──────────────┬──────────────────────────┘
               │
               ▼ (في الخلفية)
┌─────────────────────────────────────────┐
│  SyncManager يراقب:                    │
│  • حالة الاتصال                        │
│  • SyncQueue (بيانات جديدة)            │
│  • مؤقت للمزامنة التلقائية             │
└──────────────┬──────────────────────────┘
               │
        عند وجود اتصال
               │
               ▼
┌─────────────────────────────────────────┐
│  مزامنة Batch مع Firebase:             │
│  • جمع كل العناصر في SyncQueue         │
│  • إرسالها إلى Firestore               │
│  • معالجة التعارضات (أحدث يفوز)       │
│  • حذفها من SyncQueue                  │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  ✅ انتهت المزامنة                     │
│  البيانات الآن متزامنة بين:            │
│  • Hive (محلي)                        │
│  • Firebase (سحابي)                    │
└─────────────────────────────────────────┘
```

---

## 📊 Firestore Database Schema

### Collection: users

```json
{
  "id": "user123",
  "email": "user@example.com",
  "name": "أحمد محمد",
  "phone": "+966501234567",
  "profilePicture": "url/to/image",
  "alertConfig": {
    "deviationThreshold": 500,
    "lowBatteryThreshold": 20,
    "notificationsEnabled": true
  },
  "createdAt": "2025-12-18T10:30:00Z",
  "updatedAt": "2025-12-18T10:30:00Z",
  "syncedAt": "2025-12-18T10:30:05Z"
}
```

### Collection: routes

```json
{
  "id": "route123",
  "userId": "user123",
  "name": "مسار المنزل إلى العمل",
  "waypoints": [...],
  "usageCount": 5,
  "isFavorite": true,
  "createdAt": "2025-12-18T10:30:00Z",
  "updatedAt": "2025-12-18T10:30:00Z",
  "syncedAt": "2025-12-18T10:30:05Z"
}
```

### Collection: trips

```json
{
  "id": "trip123",
  "userId": "user123",
  "routeId": "route123",
  "status": "completed",
  "startTime": "2025-12-18T08:00:00Z",
  "endTime": "2025-12-18T08:45:00Z",
  "locationHistory": [...],
  "deviations": [...],
  "alertsTriggered": 1,
  "totalDistance": 15.5,
  "averageSpeed": 18.5,
  "createdAt": "2025-12-18T08:00:00Z",
  "updatedAt": "2025-12-18T08:45:00Z",
  "syncedAt": "2025-12-18T08:45:05Z"
}
```

---

## 🆘 استكشاف الأخطاء

### المشكلة: البيانات لا تُمزامن
**الحل:**
```
1. تحقق من اتصال الإنترنت
2. افتح Firebase Console
3. تحقق من SyncQueue في Hive
4. تحقق من Firestore Rules
5. افحص الأخطاء في AppLogger
```

### المشكلة: تعارضات البيانات
**الحل:**
```
1. تُحل تلقائياً بـ "الأحدث يفوز"
2. تحقق من timestamp في المستندات
3. افحص ConflictResolver logs
```

---

## 📍 Google Maps APIs - المرحلة 6

### متطلبات Pre-Setup
- [ ] Google Cloud Project تم إنشاؤه
- [ ] Google Maps API Key تم إنشاؤه
- [ ] Maps SDK for Android/iOS مُفعّل
- [ ] Geocoding API مُفعّل
- [ ] Directions API مُفعّل

### إضافة Location History Collection

يتم إنشاء collection جديدة لحفظ سجل الموقع:

```firestore
firestore/
├── location_history/
│   └── loc_<timestamp>
│       - userId
│       - tripId
│       - latitude, longitude
│       - address
│       - timestamp
│       - isDeviated
│       - deviationDistance
```

### الـ APIs المفعّلة

| API | الحالة | الاستخدام |
|-----|--------|----------|
| Maps SDK Android | ✅ | عرض خريطة |
| Maps SDK iOS | ✅ | عرض خريطة |
| Geocoding API | ✅ | تحويل إحداثيات ↔ عناوين |
| Directions API | ✅ | حساب المسارات |
| Places API | ✅ | البحث عن أماكن |
| Roads API | ✅ | تحسين المسارات |

### إضافة Permissions

**Android:**
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

**iOS:**
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>نحتاج لموقعك لتتبع آمن</string>
```

---

## 🚀 خطوات التشغيل الأول

```
1. ✅ إعداد Firebase Project
2. ✅ تحميل google-services.json
3. ✅ تشغيل التطبيق
4. ✅ تسجيل حساب جديد
5. ✅ مراقبة البيانات في Firestore Console
6. ✅ اختبر بدون اتصال (بيانات محفوظة محلياً)
7. ✅ أعد الاتصال (المزامنة تبدأ)
8. ✅ تحقق من Firestore
```

---

---

## 📚 موارد إضافية

- 📄 **External_Services_Setup.md** - توثيق شامل لكل الخدمات الخارجية
- 📄 **PHASE_HANDOVER.md** - تفاصيل كل مرحلة
- 📄 **PROJECT_STATUS.md** - حالة المشروع الحالية

---

**آخر تحديث:** 22 ديسمبر 2025
**الحالة:** Phases 1-6 ✅ مكتملة
**التطبيق:** جاهز مع Offline-First + Google Maps
