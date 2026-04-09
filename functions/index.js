const admin = require("firebase-admin");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { Resend } = require("resend");

admin.initializeApp();

const db = admin.firestore();

const RESEND_API_KEY = defineSecret("RESEND_API_KEY");
const RESEND_SENDER_EMAIL = defineSecret("RESEND_SENDER_EMAIL");

function generateCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

function isValidEmail(email) {
  return /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/.test(email);
}

function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function normalizeUsername(username) {
  return String(username || "").trim().toLowerCase();
}

exports.sendParentVerificationCode = onCall(
  {
    secrets: [RESEND_API_KEY, RESEND_SENDER_EMAIL],
  },
  async (request) => {
    try {
      const email = normalizeEmail(request.data?.email);
      const username = normalizeUsername(request.data?.username);

      if (!email || !username) {
        throw new HttpsError(
          "invalid-argument",
          "البريد الإلكتروني واسم المستخدم مطلوبان."
        );
      }

      if (!isValidEmail(email)) {
        throw new HttpsError(
          "invalid-argument",
          "صيغة البريد الإلكتروني غير صحيحة."
        );
      }

      if (!/^[a-z0-9_]+$/.test(username) || username.length < 4) {
        throw new HttpsError(
          "invalid-argument",
          "اسم المستخدم غير صالح."
        );
      }

      const existingUserByEmail = await db
        .collection("users")
        .where("email", "==", email)
        .limit(1)
        .get();

      if (!existingUserByEmail.empty) {
        throw new HttpsError(
          "already-exists",
          "البريد الإلكتروني مستخدم مسبقًا."
        );
      }

      const existingUserByUsername = await db
        .collection("users")
        .where("username", "==", username)
        .limit(1)
        .get();

      if (!existingUserByUsername.empty) {
        throw new HttpsError(
          "already-exists",
          "اسم المستخدم مستخدم مسبقًا."
        );
      }

      const existingPendingByEmail = await db
        .collection("registration_requests")
        .where("parentInfo.email", "==", email)
        .where("status", "==", "pending")
        .limit(1)
        .get();

      if (!existingPendingByEmail.empty) {
        throw new HttpsError(
          "already-exists",
          "يوجد طلب تسجيل قيد المراجعة بنفس البريد الإلكتروني."
        );
      }

      const existingPendingByUsername = await db
        .collection("registration_requests")
        .where("parentInfo.username", "==", username)
        .where("status", "==", "pending")
        .limit(1)
        .get();

      if (!existingPendingByUsername.empty) {
        throw new HttpsError(
          "already-exists",
          "يوجد طلب تسجيل قيد المراجعة بنفس اسم المستخدم."
        );
      }

      const code = generateCode();
      const now = admin.firestore.Timestamp.now();
      const expiresAt = admin.firestore.Timestamp.fromMillis(
        Date.now() + 10 * 60 * 1000
      );

      await db.collection("email_verification_codes").doc(email).set({
        email,
        username,
        code,
        verified: false,
        attempts: 0,
        createdAt: now,
        updatedAt: now,
        expiresAt,
      });

      const resend = new Resend(RESEND_API_KEY.value());

      await resend.emails.send({
        from: RESEND_SENDER_EMAIL.value(),
        to: email,
        subject: "رمز التحقق - طمّني",
        html: `
          <div dir="rtl" style="font-family: Arial, sans-serif; line-height: 1.8; color: #222;">
            <h2 style="margin-bottom: 8px;">التحقق من البريد الإلكتروني</h2>
            <p>مرحبًا،</p>
            <p>رمز التحقق الخاص بك في تطبيق <strong>طمّني</strong> هو:</p>
            <div style="font-size: 32px; font-weight: bold; letter-spacing: 4px; color: #2D6CDF; margin: 16px 0;">
              ${code}
            </div>
            <p>صلاحية الرمز <strong>10 دقائق</strong>.</p>
            <p>إذا لم تطلب هذا الرمز، يمكنك تجاهل الرسالة.</p>
          </div>
        `,
      });

      return {
        success: true,
        message: "تم إرسال كود التحقق بنجاح.",
      };
    } catch (error) {
      console.error("sendParentVerificationCode error:", error);

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        "internal",
        error.message || "فشل إرسال كود التحقق."
      );
    }
  }
);

exports.verifyParentVerificationCode = onCall(async (request) => {
  try {
    const email = normalizeEmail(request.data?.email);
    const code = String(request.data?.code || "").trim();

    if (!email || !code) {
      throw new HttpsError(
        "invalid-argument",
        "البريد الإلكتروني والكود مطلوبان."
      );
    }

    const docRef = db.collection("email_verification_codes").doc(email);
    const docSnap = await docRef.get();

    if (!docSnap.exists) {
      return {
        verified: false,
        message: "لم يتم العثور على كود تحقق لهذا البريد.",
      };
    }

    const data = docSnap.data();

    if (!data) {
      return {
        verified: false,
        message: "بيانات التحقق غير صالحة.",
      };
    }

    if (data.verified === true) {
      return {
        verified: true,
        message: "تم التحقق مسبقًا.",
      };
    }

    const expiresAtMs = data.expiresAt?.toMillis?.() || 0;
    if (Date.now() > expiresAtMs) {
      return {
        verified: false,
        message: "انتهت صلاحية كود التحقق.",
      };
    }

    if ((data.attempts || 0) >= 5) {
      return {
        verified: false,
        message: "تم تجاوز عدد المحاولات المسموح بها. أعد إرسال الكود.",
      };
    }

    if (data.code !== code) {
      await docRef.update({
        attempts: (data.attempts || 0) + 1,
        updatedAt: admin.firestore.Timestamp.now(),
      });

      return {
        verified: false,
        message: "كود التحقق غير صحيح.",
      };
    }

    await docRef.update({
      verified: true,
      verifiedAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
    });

    return {
      verified: true,
      message: "تم التحقق من البريد الإلكتروني بنجاح.",
    };
  } catch (error) {
    console.error("verifyParentVerificationCode error:", error);

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError(
      "internal",
      error.message || "فشل التحقق من الكود."
    );
  }
});