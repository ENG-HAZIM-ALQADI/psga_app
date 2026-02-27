/**
 * Firebase Cloud Functions للإشعارات
 * النسخة المحسّنة والمتوافقة مع firebase-functions v2
 */

// ✅ تحميل متغيرات البيئة من .env
require('dotenv').config();

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");

// تهيئة Firebase Admin
admin.initializeApp();

// إعدادات عامة
setGlobalOptions({
  region: "us-central1",
  maxInstances: 10,
});

// ==================== إرسال إشعارات عند إنشاء تنبيه ====================

/**
 * عند إنشاء تنبيه جديد، يتم إرسال إشعارات لجميع جهات الاتصال
 * المسار: users/{userId}/alerts/{alertId}
 */
exports.sendAlertNotifications = onDocumentCreated(
  "users/{userId}/alerts/{alertId}",
  async (event) => {
    try {
      const snapshot = event.data;
      const alertData = snapshot.data();
      const { userId, alertId } = event.params;

      console.log(`[Alert] تنبيه جديد: ${alertId} للمستخدم: ${userId}`);
      console.log(
        `[Alert] النوع: ${alertData.type}, ` + `الخطورة: ${alertData.severity}`,
      );

      // جلب جهات الاتصال
      const contactsSnapshot = await admin
        .firestore()
        .collection("users")
        .doc(userId)
        .collection("contacts")
        .get();

      if (contactsSnapshot.empty) {
        console.log("[Alert] لا توجد جهات اتصال للمستخدم");
        return null;
      }

      console.log(`[Alert] عدد جهات الاتصال: ${contactsSnapshot.size}`);

      // جلب معلومات المستخدم
      const userDoc = await admin
        .firestore()
        .collection("users")
        .doc(userId)
        .get();

      const userData = userDoc.data();
      const userName = (userData && userData.name) || "مستخدم";

      // تحضير رابط الموقع
      let locationUrl = "";
      if (alertData.location) {
        const lat = alertData.location.latitude;
        const lng = alertData.location.longitude;
        locationUrl = `https://maps.google.com/?q=${lat},${lng}`;
      }

      // إعداد الإشعارات
      const messages = [];
      const contactsNotified = [];

      contactsSnapshot.forEach((doc) => {
        const contact = doc.data();
        const fcmToken = contact.fcmToken;

        // إرسال فقط للجهات التي لديها FCM Token ومفعّلة
        if (
          fcmToken &&
          fcmToken.trim() !== "" &&
          contact.receivesPushNotification
        ) {
          const priority =
            alertData.severity === "critical" ? "high" : "default";
          const sound = alertData.type === "sos" ? "sos_sound" : "default";

          messages.push({
            token: fcmToken,
            notification: {
              title: alertData.title || "⚠️ تنبيه أمني",
              body: alertData.message || `${userName} بحاجة للمساعدة`,
            },
            data: {
              type: "alert",
              alertId: alertId,
              alertType: alertData.type || "general",
              userId: userId,
              userName: userName,
              severity: alertData.severity || "medium",
              latitude: alertData.location ?
                alertData.location.latitude.toString() :
                "",
              longitude: alertData.location ?
                alertData.location.longitude.toString() :
                "",
              locationUrl: locationUrl,
              timestamp: alertData.triggeredAt || new Date().toISOString(),
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            android: {
              priority: priority,
              notification: {
                channelId:
                  alertData.type === "sos" ? "sos_channel" : "alerts_channel",
                sound: sound,
                priority: priority,
                defaultSound: sound === "default",
                defaultVibrateTimings: false,
                vibrateTimingsMillis:
                  alertData.type === "sos" ?
                    [0, 1000, 500, 1000, 500, 1000] :
                    [0, 500, 250, 500],
                color:
                  alertData.severity === "critical" ? "#FF0000" : "#F44336",
                tag: `alert_${alertId}`,
              },
            },
            apns: {
              payload: {
                aps: {
                  sound:
                    alertData.type === "sos" ? "sos_sound.aiff" : "default",
                  badge: 1,
                  alert: {
                    title: alertData.title || "⚠️ تنبيه أمني",
                    body: alertData.message || `${userName} بحاجة للمساعدة`,
                  },
                  "interruption-level":
                    alertData.severity === "critical" ?
                      "critical" :
                      "time-sensitive",
                },
              },
            },
          });

          contactsNotified.push(contact.id);
        }
      });

      // إرسال الإشعارات FCM (إذا وُجدت)
      let successCount = 0;
      let failureCount = 0;
      const failedTokens = []; // ✅ تعريف خارج الـ if block

      if (messages.length > 0) {
        console.log(`[Alert] جاري إرسال ${messages.length} إشعار FCM`);

        const response = await admin.messaging().sendEach(messages);

        // تسجيل النتائج
      response.responses.forEach((resp, idx) => {
        if (resp.success) {
          successCount++;
        } else {
          failureCount++;
          console.error(
            `[Alert] فشل إرسال للتوكن ${idx}:`,
            resp.error ? resp.error.message : "unknown",
          );

          // حذف التوكنات غير الصالحة
          if (
            resp.error &&
            (resp.error.code === "messaging/invalid-registration-token" ||
              resp.error.code === "messaging/registration-token-not-registered")
          ) {
            failedTokens.push(messages[idx].token);
          }
        }
      });

      console.log(`[Alert] ✅ FCM نجح: ${successCount}, ❌ فشل: ${failureCount}`);
      } else {
        console.log("[Alert] لا توجد FCM tokens - سيتم إرسال Emails فقط");
      }

      // ✅ إرسال Email notifications لجهات الاتصال (سواء كان لديهم FCM أم لا)
      const emailPromises = [];
      contactsSnapshot.forEach((doc) => {
        const contact = doc.data();

        // إرسال email إذا كان لديه email (بغض النظر عن FCM)
        if (contact.email && contact.email.trim() !== "") {
          const alertTypeArabic = {
            sos: "🚨 طوارئ SOS",
            deviation: "⚠️ انحراف عن المسار",
            checkpoint: "✅ وصول لنقطة تفتيش",
            lowBattery: "🔋 بطارية منخفضة",
            noMovement: "⏸️ عدم حركة",
            speedLimit: "⚡ تجاوز السرعة",
            geofence: "📍 خروج من المنطقة",
          };

          const alertTitle = alertTypeArabic[alertData.type] || "⚠️ تنبيه أمني";

          const emailBody = `
            <div dir="rtl" style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f5f5f5;">
              <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                <h1 style="color: #d32f2f; text-align: center; margin-bottom: 20px;">
                  ${alertTitle}
                </h1>
                
                <div style="background-color: #ffebee; padding: 15px; border-radius: 5px; margin-bottom: 20px; border-right: 4px solid #d32f2f;">
                  <p style="margin: 0; font-size: 16px; color: #333;">
                    <strong>${userName}</strong> ${alertData.message || "بحاجة للمساعدة"}
                  </p>
                </div>
                
                <div style="margin-bottom: 20px;">
                  <h3 style="color: #555; margin-bottom: 10px;">معلومات التنبيه:</h3>
                  <ul style="list-style: none; padding: 0;">
                    <li style="padding: 8px 0; border-bottom: 1px solid #eee;">
                      <strong>النوع:</strong> ${alertTitle}
                    </li>
                    <li style="padding: 8px 0; border-bottom: 1px solid #eee;">
                      <strong>الخطورة:</strong> ${alertData.severity === "critical" ? "🔴 حرج" : alertData.severity === "high" ? "🟠 عالي" : alertData.severity === "medium" ? "🟡 متوسط" : "🟢 منخفض"}
                    </li>
                    <li style="padding: 8px 0; border-bottom: 1px solid #eee;">
                      <strong>الوقت:</strong> ${new Date().toLocaleString("ar-EG")}
                    </li>
                    ${locationUrl ? `
                    <li style="padding: 8px 0;">
                      <strong>الموقع:</strong> <a href="${locationUrl}" style="color: #1976d2; text-decoration: none;">عرض على الخريطة 📍</a>
                    </li>
                    ` : ""}
                  </ul>
                </div>
                
                ${locationUrl ? `
                <div style="text-align: center; margin-top: 30px;">
                  <a href="${locationUrl}" style="display: inline-block; background-color: #d32f2f; color: white; padding: 15px 40px; text-decoration: none; border-radius: 5px; font-size: 16px; font-weight: bold;">
                    🗺️ عرض الموقع على الخريطة
                  </a>
                </div>
                ` : ""}
                
                <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; text-align: center; color: #777; font-size: 12px;">
                  <p>هذا تنبيه تلقائي من تطبيق PSGA - نظام الحماية الشخصية</p>
                  <p>للمزيد من المعلومات، يرجى الاتصال بـ ${userName} مباشرة</p>
                </div>
              </div>
            </div>
          `;

          emailPromises.push(
            sendEmailHelper(contact.email, alertTitle, emailBody, true)
              .then(() => {
                console.log(`[Alert] ✅ تم إرسال Email لـ ${contact.name}`);
                return true;
              })
              .catch((error) => {
                console.error(`[Alert] ❌ فشل إرسال Email لـ ${contact.name}:`, error);
                return false;
              })
          );
        }
      });

      // انتظار إرسال جميع الـ emails
      const emailResults = await Promise.allSettled(emailPromises);
      const emailsSent = emailResults.filter((r) => r.status === "fulfilled" && r.value === true).length;
      console.log(`[Alert] 📧 تم إرسال ${emailsSent} email من ${emailPromises.length}`);

      // حذف التوكنات غير الصالحة
      if (failedTokens.length > 0) {
        console.log(`[Alert] حذف ${failedTokens.length} توكن غير صالح`);
        const batch = admin.firestore().batch();

        for (const token of failedTokens) {
          const contactQuery = await admin
            .firestore()
            .collection("users")
            .doc(userId)
            .collection("contacts")
            .where("fcmToken", "==", token)
            .limit(1)
            .get();

          if (!contactQuery.empty) {
            batch.update(contactQuery.docs[0].ref, {
              fcmToken: admin.firestore.FieldValue.delete(),
            });
          }
        }

        await batch.commit();
      }

      // تحديث التنبيه بعدد الإشعارات المرسلة
      await snapshot.ref.update({
        notifiedContacts: contactsNotified,
        isSent: successCount > 0,
        notificationsSent: successCount,
        notificationsFailed: failureCount,
        notificationsTimestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: successCount,
        failure: failureCount,
      };
    } catch (error) {
      console.error("[Alert] ❌ خطأ في إرسال الإشعارات:", error);

      // تحديث التنبيه بحالة الفشل
      try {
        await event.data.ref.update({
          notificationError: error.message,
          isSent: false,
        });
      } catch (updateError) {
        console.error("[Alert] فشل تحديث حالة الخطأ:", updateError);
      }

      return null;
    }
  },
);

// ==================== إرسال إشعار SOS ====================

/**
 * دالة يمكن استدعاؤها من التطبيق لإرسال SOS فوري
 */
exports.sendSOSAlert = onCall(async (request) => {
  try {
    // التحقق من المصادقة
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً");
    }

    const userId = request.auth.uid;
    const { title, message, location } = request.data;

    console.log(`[SOS] 🚨 طوارئ من المستخدم: ${userId}`);

    // جلب جهات الاتصال
    const contactsSnapshot = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .collection("contacts")
      .get();

    if (contactsSnapshot.empty) {
      throw new HttpsError("not-found", "لا توجد جهات اتصال");
    }

    // جلب معلومات المستخدم
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();

    const userData = userDoc.data();
    const userName = (userData && userData.name) || "مستخدم";

    // تحضير رابط الموقع
    let locationUrl = "";
    if (location) {
      locationUrl = `https://maps.google.com/?q=${location.latitude},${location.longitude}`;
    }

    // إعداد الرسالة
    const messages = [];
    const contactsNotified = [];

    contactsSnapshot.forEach((doc) => {
      const contact = doc.data();
      const fcmToken = contact.fcmToken;

      // SOS يُرسل للجميع بغض النظر عن receivesPushNotification
      if (fcmToken && fcmToken.trim() !== "") {
        messages.push({
          token: fcmToken,
          notification: {
            title: "🚨 طوارئ SOS",
            body: message || `${userName} يحتاج مساعدة عاجلة!`,
          },
          data: {
            type: "sos",
            userId: userId,
            userName: userName,
            latitude: location ? location.latitude.toString() : "",
            longitude: location ? location.longitude.toString() : "",
            locationUrl: locationUrl,
            timestamp: new Date().toISOString(),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "sos_channel",
              sound: "sos_sound",
              priority: "max",
              defaultSound: false,
              defaultVibrateTimings: false,
              vibrateTimingsMillis: [0, 1000, 500, 1000, 500, 1000],
              color: "#FF0000",
              tag: "sos",
              sticky: true,
            },
          },
          apns: {
            payload: {
              aps: {
                sound: {
                  critical: 1,
                  name: "sos_sound.aiff",
                  volume: 1.0,
                },
                badge: 1,
                "interruption-level": "critical",
              },
            },
          },
        });

        contactsNotified.push(contact.id);
      }
    });

    if (messages.length === 0) {
      throw new HttpsError("not-found", "لا توجد جهات اتصال بتوكنات صالحة");
    }

    // إرسال الإشعارات
    console.log(`[SOS] جاري إرسال ${messages.length} إشعار طوارئ`);

    const response = await admin.messaging().sendEach(messages);

    let successCount = 0;
    let failureCount = 0;

    response.responses.forEach((resp) => {
      if (resp.success) {
        successCount++;
      } else {
        failureCount++;
        console.error(
          "[SOS] ❌ فشل إرسال:",
          resp.error ? resp.error.message : "unknown",
        );
      }
    });

    console.log(`[SOS] ✅ نجح: ${successCount}, ❌ فشل: ${failureCount}`);

    // حفظ سجل SOS في Firestore
    const alertRef = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .collection("alerts")
      .add({
        type: "sos",
        title: title || "🚨 طوارئ SOS",
        message: message || `${userName} يحتاج مساعدة عاجلة!`,
        severity: "critical",
        status: "triggered",
        location: location || null,
        triggeredAt: admin.firestore.FieldValue.serverTimestamp(),
        notifiedContacts: contactsNotified,
        isSent: successCount > 0,
        notificationsSent: successCount,
        notificationsFailed: failureCount,
      });

    console.log(`[SOS] تم حفظ التنبيه: ${alertRef.id}`);

    return {
      success: true,
      notificationsSent: successCount,
      notificationsFailed: failureCount,
      alertId: alertRef.id,
    };
  } catch (error) {
    console.error("[SOS] ❌ خطأ:", error);
    throw new HttpsError("internal", error.message);
  }
});

// ==================== تنظيف التوكنات غير الصالحة ====================

/**
 * دالة دورية لتنظيف FCM Tokens غير الصالحة
 * تعمل كل 24 ساعة
 */
exports.cleanupInvalidTokens = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "Asia/Riyadh",
  },
  async () => {
    try {
      console.log("[Cleanup] 🧹 بدء تنظيف التوكنات غير الصالحة");

      const usersSnapshot = await admin.firestore().collection("users").get();

      let totalChecked = 0;
      let totalRemoved = 0;

      for (const userDoc of usersSnapshot.docs) {
        const contactsSnapshot = await userDoc.ref
          .collection("contacts")
          .where("fcmToken", "!=", null)
          .get();

        for (const contactDoc of contactsSnapshot.docs) {
          const contact = contactDoc.data();
          const fcmToken = contact.fcmToken;

          if (fcmToken && fcmToken.trim() !== "") {
            totalChecked++;

            try {
              // محاولة إرسال رسالة اختبار (dryRun)
              await admin.messaging().send({
                token: fcmToken,
                data: { test: "true" },
                dryRun: true,
              });
            } catch (error) {
              // إذا كان التوكن غير صالح، احذفه
              if (
                error.code === "messaging/invalid-registration-token" ||
                error.code === "messaging/registration-token-not-registered"
              ) {
                console.log(
                  `[Cleanup] حذف توكن غير صالح للمستخدم: ${userDoc.id}`,
                );
                await contactDoc.ref.update({
                  fcmToken: admin.firestore.FieldValue.delete(),
                  fcmTokenRemovedAt:
                    admin.firestore.FieldValue.serverTimestamp(),
                });
                totalRemoved++;
              }
            }
          }
        }
      }

      console.log(
        `[Cleanup] ✅ تم فحص ${totalChecked} توكن, ` +
          `حذف ${totalRemoved} توكن`,
      );
      return null;
    } catch (error) {
      console.error("[Cleanup] ❌ خطأ:", error);
      return null;
    }
  },
);

// ==================== إحصائيات الإشعارات ====================

/**
 * دالة للحصول على إحصائيات إرسال الإشعارات
 */
exports.getNotificationStats = onCall(async (request) => {
  try {
    // التحقق من المصادقة
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "غير مصرح");
    }

    const authUserId = request.auth.uid;
    const { startDate, endDate } = request.data;

    console.log(`[Stats] جلب إحصائيات للمستخدم: ${authUserId}`);

    // جلب التنبيهات في الفترة المحددة
    let query = admin
      .firestore()
      .collection("users")
      .doc(authUserId)
      .collection("alerts");

    if (startDate) {
      query = query.where("triggeredAt", ">=", new Date(startDate));
    }
    if (endDate) {
      query = query.where("triggeredAt", "<=", new Date(endDate));
    }

    const alertsSnapshot = await query.get();

    let totalAlerts = 0;
    let totalNotificationsSent = 0;
    let totalNotificationsFailed = 0;

    const alertsBySeverity = {
      low: 0,
      medium: 0,
      high: 0,
      critical: 0,
    };

    const alertsByType = {
      deviation: 0,
      sos: 0,
      checkpoint: 0,
      speedLimit: 0,
      lowBattery: 0,
      noMovement: 0,
      geofence: 0,
      custom: 0,
    };

    alertsSnapshot.forEach((doc) => {
      const alert = doc.data();
      totalAlerts++;
      totalNotificationsSent += alert.notificationsSent || 0;
      totalNotificationsFailed += alert.notificationsFailed || 0;

      const severity = alert.severity || "medium";
      if (alertsBySeverity[severity] !== undefined) {
        alertsBySeverity[severity]++;
      }

      const type = alert.type || "custom";
      if (alertsByType[type] !== undefined) {
        alertsByType[type]++;
      }
    });

    const stats = {
      totalAlerts,
      totalNotificationsSent,
      totalNotificationsFailed,
      alertsBySeverity,
      alertsByType,
      averageNotificationsPerAlert:
        totalAlerts > 0 ?
          parseFloat((totalNotificationsSent / totalAlerts).toFixed(2)) :
          0,
      successRate:
        totalNotificationsSent > 0 ?
          parseFloat(
              (
                (totalNotificationsSent /
                  (totalNotificationsSent + totalNotificationsFailed)) *
                100
              ).toFixed(2),
            ) :
          0,
    };

    console.log("[Stats] ✅ الإحصائيات:", stats);

    return stats;
  } catch (error) {
    console.error("[Stats] ❌ خطأ:", error);
    throw new HttpsError("internal", error.message);
  }
});

// ==================== اختبار الإشعارات ====================

/**
 * دالة اختبار لإرسال إشعار تجريبي
 */
exports.testNotification = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "غير مصرح");
    }

    const { fcmToken, title, message } = request.data;

    if (!fcmToken) {
      throw new HttpsError("invalid-argument", "FCM Token مطلوب");
    }

    const result = await admin.messaging().send({
      token: fcmToken,
      notification: {
        title: title || "اختبار الإشعارات",
        body: message || "هذا إشعار تجريبي من Cloud Functions",
      },
      data: {
        type: "test",
        timestamp: new Date().toISOString(),
      },
    });

    console.log(`[Test] ✅ تم إرسال إشعار اختبار: ${result}`);

    return {
      success: true,
      messageId: result,
    };
  } catch (error) {
    console.error("[Test] ❌ خطأ:", error);
    throw new HttpsError("internal", error.message);
  }
});

// ==================== إرسال تنبيه انحراف ====================

/**
 * دالة لإرسال تنبيه عند انحراف عن المسار
 */
exports.sendDeviationAlert = onCall(async (request) => {
  try {
    // التحقق من المصادقة
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً");
    }

    const authUserId = request.auth.uid;
    const { userId, tripId, severity, location, distance, timestamp } = request.data;

    // التحقق من أن المستخدم يطلب عن نفسه
    if (authUserId !== userId) {
      throw new HttpsError("permission-denied", "غير مصرح");
    }

    console.log(`[Deviation] ⚠️ انحراف للمستخدم: ${userId}, الرحلة: ${tripId}`);
    console.log(`[Deviation] الخطورة: ${severity}, المسافة: ${distance}م`);

    // جلب جهات الاتصال
    const contactsSnapshot = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .collection("contacts")
      .where("receivesPushNotification", "==", true)
      .get();

    if (contactsSnapshot.empty) {
      console.log("[Deviation] لا توجد جهات اتصال مفعلة");
      return {
        success: true,
        notificationsSent: 0,
        message: "لا توجد جهات اتصال",
      };
    }

    // جلب معلومات المستخدم
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();

    const userData = userDoc.data();
    const userName = (userData && userData.name) || "مستخدم";

    // تحضير رابط الموقع
    let locationUrl = "";
    if (location && location.latitude && location.longitude) {
      const lat = location.latitude;
      const lng = location.longitude;
      locationUrl = `https://maps.google.com/?q=${lat},${lng}`;
    }

    // إعداد الإشعارات
    const messages = [];
    const contactsNotified = [];

    // تحديد مستوى الخطورة
    const severityLabel = {
      low: "منخفض",
      medium: "متوسط",
      high: "عالي",
      critical: "حرج",
    }[severity] || "متوسط";

    const alertTitle = `⚠️ تنبيه انحراف ${severityLabel}`;
    const alertMessage = `${userName} انحرف عن المسار بمسافة ${Math.round(distance)}م`;

    contactsSnapshot.forEach((doc) => {
      const contact = doc.data();
      const fcmToken = contact.fcmToken;

      if (fcmToken && fcmToken.trim() !== "") {
        const priority = severity === "critical" || severity === "high" ? "high" : "default";

        messages.push({
          token: fcmToken,
          notification: {
            title: alertTitle,
            body: alertMessage,
          },
          data: {
            type: "deviation",
            userId: userId,
            userName: userName,
            tripId: tripId,
            severity: severity,
            distance: distance.toString(),
            latitude: location?.latitude?.toString() || "",
            longitude: location?.longitude?.toString() || "",
            locationUrl: locationUrl,
            timestamp: timestamp || new Date().toISOString(),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: {
            priority: priority,
            notification: {
              channelId: "alerts_channel",
              sound: "default",
              priority: priority,
              color: severity === "critical" ? "#FF0000" : "#FFA500",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
                alert: {
                  title: alertTitle,
                  body: alertMessage,
                },
                "interruption-level": severity === "critical" ? "critical" : "time-sensitive",
              },
            },
          },
        });

        contactsNotified.push(contact.id);
      }
    });

    if (messages.length === 0) {
      return {
        success: true,
        notificationsSent: 0,
        message: "لا توجد tokens صالحة",
      };
    }

    // إرسال الإشعارات
    console.log(`[Deviation] جاري إرسال ${messages.length} إشعار`);

    const response = await admin.messaging().sendEach(messages);

    let successCount = 0;
    let failureCount = 0;

    response.responses.forEach((resp) => {
      if (resp.success) {
        successCount++;
      } else {
        failureCount++;
        console.error(
          "[Deviation] ❌ فشل إرسال:",
          resp.error ? resp.error.message : "unknown",
        );
      }
    });

    console.log(`[Deviation] ✅ نجح: ${successCount}, ❌ فشل: ${failureCount}`);

    // حفظ سجل الانحراف في Firestore
    await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .collection("alerts")
      .add({
        type: "deviation",
        title: alertTitle,
        message: alertMessage,
        severity: severity,
        status: "triggered",
        tripId: tripId,
        location: location || null,
        distance: distance,
        triggeredAt: admin.firestore.FieldValue.serverTimestamp(),
        notifiedContacts: contactsNotified,
        isSent: successCount > 0,
        notificationsSent: successCount,
        notificationsFailed: failureCount,
      });

    return {
      success: true,
      notificationsSent: successCount,
      notificationsFailed: failureCount,
    };
  } catch (error) {
    console.error("[Deviation] ❌ خطأ:", error);
    throw new HttpsError("internal", error.message);
  }
});

// ==================== إرسال إشعارات لـ tokens محددة ====================

/**
 * دالة لإرسال إشعارات لقائمة tokens محددة
 */
exports.sendNotificationToTokens = onCall(async (request) => {
  try {
    // التحقق من المصادقة
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً");
    }

    const { tokens, title, body, data } = request.data;

    if (!tokens || !Array.isArray(tokens) || tokens.length === 0) {
      throw new HttpsError("invalid-argument", "قائمة tokens مطلوبة");
    }

    console.log(`[SendToTokens] إرسال لـ ${tokens.length} توكن`);

    const messages = tokens.map((token) => ({
      token: token,
      notification: {
        title: title || "تنبيه",
        body: body || "لديك إشعار جديد",
      },
      data: data || {},
      android: {
        priority: "high",
        notification: {
          channelId: "alerts_channel",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    }));

    const response = await admin.messaging().sendEach(messages);

    let successCount = 0;
    let failureCount = 0;

    response.responses.forEach((resp) => {
      if (resp.success) {
        successCount++;
      } else {
        failureCount++;
      }
    });

    console.log(`[SendToTokens] ✅ نجح: ${successCount}, ❌ فشل: ${failureCount}`);

    return {
      success: true,
      notificationsSent: successCount,
      notificationsFailed: failureCount,
    };
  } catch (error) {
    console.error("[SendToTokens] ❌ خطأ:", error);
    throw new HttpsError("internal", error.message);
  }
});

// ==================== Email Service Functions ====================

const nodemailer = require("nodemailer");

/**
 * Helper function لإرسال Email (يُستخدم من sendAlertNotifications)
 * @param {string} to - عنوان البريد الإلكتروني للمستلم
 * @param {string} subject - موضوع الرسالة
 * @param {string} body - محتوى الرسالة
 * @param {boolean} isHtml - هل المحتوى HTML أم نص عادي
 * @return {Promise<void>}
 */
async function sendEmailHelper(to, subject, body, isHtml = false) {
  const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: process.env.EMAIL_USER || "your-email@gmail.com",
      pass: process.env.EMAIL_APP_PASSWORD || "your-app-password",
    },
  });

  const mailOptions = {
    from: `PSGA App <${process.env.EMAIL_USER}>`,
    to: to,
    subject: subject,
  };

  if (isHtml) {
    mailOptions.html = body;
  } else {
    mailOptions.text = body;
  }

  await transporter.sendMail(mailOptions);
}

// إعداد Nodemailer transporter
const transporter = nodemailer.createTransport({
  service: "gmail", // يمكن استبداله بـ SMTP آخر
  auth: {
    user: process.env.EMAIL_USER || "your-email@gmail.com",
    pass: process.env.EMAIL_APP_PASSWORD || "your-app-password",
  },
});

/**
 * إرسال Email واحد
 */
exports.sendEmail = onCall(async (request) => {
  try {
    const { to, subject, body, isHtml } = request.data;

    console.log(`[Email] إرسال email إلى: ${to}`);

    if (!to || !subject || !body) {
      throw new HttpsError(
        "invalid-argument",
        "يجب توفير to و subject و body",
      );
    }

    const mailOptions = {
      from: `PSGA App <${process.env.EMAIL_USER}>`,
      to: to,
      subject: subject,
    };

    if (isHtml) {
      mailOptions.html = body;
    } else {
      mailOptions.text = body;
    }

    await transporter.sendMail(mailOptions);

    console.log(`[Email] ✅ تم الإرسال بنجاح`);

    return {
      success: true,
      message: "تم إرسال Email بنجاح",
    };
  } catch (error) {
    console.error("[Email] ❌ خطأ:", error);
    return {
      success: false,
      error: error.message,
    };
  }
});

/**
 * إرسال Email متعدد (Bulk)
 */
exports.sendBulkEmail = onCall(async (request) => {
  // تم نقل التعريف هنا ليكون متاحاً في try و catch
  const { recipients, subject, body, isHtml } = request.data;

  try {
    console.log(`[BulkEmail] إرسال لـ ${recipients ? recipients.length : 0} عنوان`);

    if (!recipients || !Array.isArray(recipients) || recipients.length === 0) {
      throw new HttpsError("invalid-argument", "يجب توفير قائمة recipients");
    }

    if (!subject || !body) {
      throw new HttpsError("invalid-argument", "يجب توفير subject و body");
    }

    let successCount = 0;
    let failureCount = 0;

    // إرسال على دفعات (batch) لتجنب rate limiting
    const batchSize = 10;
    for (let i = 0; i < recipients.length; i += batchSize) {
      const batch = recipients.slice(i, i + batchSize);

      const promises = batch.map(async (email) => {
        try {
          const mailOptions = {
            from: `PSGA App <${process.env.EMAIL_USER}>`,
            to: email,
            subject: subject,
          };

          if (isHtml) {
            mailOptions.html = body;
          } else {
            mailOptions.text = body;
          }

          await transporter.sendMail(mailOptions);
          successCount++;
          console.log(`[BulkEmail] ✅ تم إرسال إلى: ${email}`);
        } catch (error) {
          failureCount++;
          console.error(`[BulkEmail] ❌ فشل إرسال إلى ${email}:`, error);
        }
      });

      await Promise.all(promises);

      // انتظار قصير بين الدفعات
      if (i + batchSize < recipients.length) {
        await new Promise((resolve) => setTimeout(resolve, 1000));
      }
    }

    console.log(
      `[BulkEmail] ✅ نجح: ${successCount}, ❌ فشل: ${failureCount}`,
    );

    return {
      success: true,
      sent: successCount,
      failed: failureCount,
      total: recipients.length,
    };
  } catch (error) {
    console.error("[BulkEmail] ❌ خطأ:", error);
    return {
      success: false,
      error: error.message,
      sent: 0,
      failed: recipients ? recipients.length : 0, // استخدام آمن للمتغير
    };
  }
});

/**
 * اختبار Email Service
 */
exports.testEmail = onCall(async (request) => {
  try {
    const { to } = request.data;

    console.log(`[TestEmail] اختبار الإرسال إلى: ${to || "default"}`);

    const testEmail = to || process.env.EMAIL_USER;

    const mailOptions = {
      from: `PSGA App <${process.env.EMAIL_USER}>`,
      to: testEmail,
      subject: "اختبار Email Service - PSGA App",
      html: `
        <div style="font-family: Arial, sans-serif; padding: 20px;">
          <h2>🎉 Email Service يعمل بنجاح!</h2>
          <p>هذا email تجريبي من تطبيق PSGA.</p>
          <p><strong>الوقت:</strong> ${new Date().toLocaleString("ar")}</p>
        </div>
      `,
    };

    await transporter.sendMail(mailOptions);

    console.log(`[TestEmail] ✅ تم الإرسال بنجاح`);

    return {
      success: true,
      message: "تم إرسال email اختبار بنجاح",
      sentTo: testEmail,
    };
  } catch (error) {
    console.error("[TestEmail] ❌ خطأ:", error);
    return {
      success: false,
      error: error.message,
    };
  }
});