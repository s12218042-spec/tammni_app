const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { Resend } = require("resend");

admin.initializeApp();

const resend = new Resend(process.env.RESEND_API_KEY);

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

function generateCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

exports.sendParentVerificationCode = functions.https.onCall(async (data, context) => {
  const email = (data.email || "").toString().trim().toLowerCase();
  const username = (data.username || "").toString().trim().toLowerCase();

  if (!email) {
    throw new functions.https.HttpsError("invalid-argument", "البريد الإلكتروني مطلوب");
  }

  if (!username) {
    throw new functions.https.HttpsError("invalid-argument", "اسم المستخدم مطلوب");
  }

  const emailRegex = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;
  if (!emailRegex.test(email)) {
    throw new functions.https.HttpsError("invalid-argument", "البريد الإلكتروني غير صالح");
  }

  try {
    const code = generateCode();
    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 10 * 60 * 1000)
    );

    await admin.firestore().collection("email_verifications").doc(email).set({
      email,
      username,
      code,
      verified: false,
      createdAt: now,
      updatedAt: now,
      expiresAt,
      attempts: 0,
    }, { merge: true });

    await resend.emails.send({
      from: process.env.EMAIL_FROM,
      to: email,
      subject: "كود التحقق - طمني",
      html: `
        <div style="font-family: Arial, sans-serif; direction: rtl; text-align: right;">
          <h2>كود التحقق</h2>
          <p>مرحبًا،</p>
          <p>كود التحقق الخاص بك هو:</p>
          <h1 style="letter-spacing: 4px;">${code}</h1>
          <p>صلاحية الكود 10 دقائق.</p>
          <p>إذا لم تطلب هذا الكود، يمكنك تجاهل الرسالة.</p>
        </div>
      `,
    });

    return { success: true };
  } catch (error) {
    console.error("خطأ في إرسال كود التحقق:", error);
    throw new functions.https.HttpsError("internal", "فشل إرسال كود التحقق");
  }
});

exports.verifyParentVerificationCode = functions.https.onCall(async (data, context) => {
  const email = (data.email || "").toString().trim().toLowerCase();
  const code = (data.code || "").toString().trim();

  if (!email || !code) {
    throw new functions.https.HttpsError("invalid-argument", "البريد والكود مطلوبان");
  }

  try {
    const docRef = admin.firestore().collection("email_verifications").doc(email);
    const doc = await docRef.get();

    if (!doc.exists) {
      return { verified: false };
    }

    const verificationData = doc.data();

    if (!verificationData) {
      return { verified: false };
    }

    const expiresAt = verificationData.expiresAt?.toDate?.();
    if (!expiresAt || expiresAt.getTime() < Date.now()) {
      return { verified: false, reason: "expired" };
    }

    if (verificationData.code !== code) {
      await docRef.update({
        attempts: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.Timestamp.now(),
      });

      return { verified: false, reason: "invalid_code" };
    }

    await docRef.update({
      verified: true,
      verifiedAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
    });

    return { verified: true };
  } catch (error) {
    console.error("خطأ في التحقق من الكود:", error);
    throw new functions.https.HttpsError("internal", "فشل التحقق من الكود");
  }
});