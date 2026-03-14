const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendUpdateNotification = functions.firestore
  .document("updates/{updateId}")
  .onCreate(async (snap, context) => {
    const update = snap.data();

    if (!update) return null;

    const childId = update.childId;
    const childName = update.childName || "طفلك";
    const type = update.type || "تحديث";
    const note = update.note || "";
    const byRole = update.byRole || "";
    const hasMedia = update.hasMedia === true;
    const mediaType = update.mediaType || null;

    if (!childId) return null;

    try {
      const childDoc = await admin.firestore().collection("children").doc(childId).get();

      if (!childDoc.exists) {
        console.log("الطفل غير موجود");
        return null;
      }

      const childData = childDoc.data();
      const parentUid = childData.parentUid;

      if (!parentUid) {
        console.log("parentUid غير موجود");
        return null;
      }

      const userDoc = await admin.firestore().collection("users").doc(parentUid).get();

      if (!userDoc.exists) {
        console.log("المستخدم غير موجود");
        return null;
      }

      const userData = userDoc.data();
      const fcmTokens = userData.fcmTokens || [];

      if (!Array.isArray(fcmTokens) || fcmTokens.length === 0) {
        console.log("لا يوجد FCM tokens");
        return null;
      }

      let senderText = "المؤسسة";
      if (byRole === "nursery") senderText = "موظفة الحضانة";
      if (byRole === "teacher") senderText = "المعلمة";

      let body = `تم إرسال ${type} جديد بخصوص ${childName}`;
      if (note) {
        body = `${senderText}: ${note}`;
      }

      if (hasMedia && mediaType === "image") {
        body += " 📷";
      } else if (hasMedia && mediaType === "video") {
        body += " 🎥";
      }

      const message = {
        tokens: fcmTokens,
        notification: {
          title: `تحديث جديد لطفلك ${childName}`,
          body: body,
        },
        data: {
          childId: String(childId),
          type: String(type),
          byRole: String(byRole),
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "tammni_updates_channel",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      };

      const response = await admin.messaging().sendEachForMulticast(message);

      console.log("تم إرسال الإشعار", response.successCount);

      if (response.failureCount > 0) {
        const invalidTokens = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.log("فشل token:", fcmTokens[idx], resp.error);
            invalidTokens.push(fcmTokens[idx]);
          }
        });

        if (invalidTokens.length > 0) {
          await admin.firestore().collection("users").doc(parentUid).update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
          });
        }
      }

      return null;
    } catch (error) {
      console.error("خطأ في إرسال الإشعار:", error);
      return null;
    }
  });