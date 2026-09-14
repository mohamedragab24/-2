const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const bucket = admin.storage().bucket();

// How long a signed video URL stays valid before the app must ask again.
const SIGNED_URL_TTL_MS = 10 * 60 * 1000; // 10 minutes

/**
 * Callable function: getSignedVideoUrl({ courseId, lessonId })
 *
 * This is the entire content-protection mechanism described in the
 * project spec: the app never holds a real video URL — it asks this
 * function every time it wants to play (or resume, or move to the next
 * lesson), and only gets a URL back if all checks pass.
 */
exports.getSignedVideoUrl = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "لازم تسجل الدخول أولاً");
  }

  const { courseId, lessonId } = request.data || {};
  if (!courseId || !lessonId) {
    throw new HttpsError("invalid-argument", "بيانات الدرس غير مكتملة");
  }

  const lessonDoc = await db
    .collection("courses").doc(courseId)
    .collection("lessons").doc(lessonId)
    .get();

  if (!lessonDoc.exists) {
    throw new HttpsError("not-found", "الدرس غير موجود");
  }
  const lesson = lessonDoc.data();

  // Preview lessons (e.g. the intro) are playable without a purchase.
  if (!lesson.isPreview) {
    const purchaseDoc = await db.collection("purchases").doc(`${uid}_${courseId}`).get();
    const purchased = purchaseDoc.exists && purchaseDoc.data().status === "completed";
    if (!purchased) {
      throw new HttpsError("permission-denied", "لازم تشتري الكورس الأول");
    }
  }

  if (!lesson.storagePath) {
    throw new HttpsError("failed-precondition", "ملف الفيديو غير متاح حاليًا");
  }

  const [url] = await bucket.file(lesson.storagePath).getSignedUrl({
    version: "v4",
    action: "read",
    expires: Date.now() + SIGNED_URL_TTL_MS,
  });

  // Optional: record a session so "مراقبة الجلسات" (session monitoring)
  // from the spec has something to look at, and so you can rate-limit or
  // revoke abusive accounts later.
  await db.collection("sessions").add({
    uid,
    courseId,
    lessonId,
    issuedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { url, expiresAtMs: Date.now() + SIGNED_URL_TTL_MS };
});

/**
 * Firestore trigger: whenever a payment document is marked completed,
 * automatically create/update the matching purchase document so the
 * client's hasPurchased() check and getSignedVideoUrl() both see it
 * immediately, without the app having to write purchases itself
 * (writing purchases directly from the client would let a user fake
 * a purchase — this must happen server-side, driven by your real
 * payment webhook writing into `payments`).
 */
exports.onPaymentCompleted = onDocumentCreated("payments/{paymentId}", async (event) => {
  const payment = event.data?.data();
  if (!payment || payment.status !== "completed") return;

  await db.collection("purchases").doc(`${payment.uid}_${payment.courseId}`).set({
    uid: payment.uid,
    courseId: payment.courseId,
    status: "completed",
    purchasedAt: admin.firestore.FieldValue.serverTimestamp(),
    paymentId: event.params.paymentId,
  });
});
