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

/**
 * Admin-only course review. The admin may approve or reject a pending course.
 * Rejection requires a non-empty reason. Every decision is appended to the
 * course's reviews subcollection for an audit trail.
 */
exports.reviewCourse = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "لازم تسجل الدخول أولاً");

  const profile = await db.collection("users").doc(uid).get();
  const isAdmin = request.auth.token?.admin === true || profile.data()?.role === "admin";
  if (!isAdmin) throw new HttpsError("permission-denied", "ليس لديك صلاحية الأدمن");

  const data = request.data || {};
  const courseId = String(data.courseId || "").trim();
  const decision = String(data.decision || "").trim();
  const rejectionReason = String(data.rejectionReason || "").trim();
  if (!courseId || !["approved", "rejected"].includes(decision)) {
    throw new HttpsError("invalid-argument", "بيانات المراجعة غير صحيحة");
  }
  if (decision === "rejected" && !rejectionReason) {
    throw new HttpsError("invalid-argument", "سبب الرفض مطلوب");
  }

  const courseRef = db.collection("courses").doc(courseId);
  const courseSnap = await courseRef.get();
  if (!courseSnap.exists) throw new HttpsError("not-found", "الكورس غير موجود");
  const course = courseSnap.data() || {};
  if (course.status && course.status !== "pending") {
    throw new HttpsError("failed-precondition", "الكورس ليس قيد المراجعة حاليًا");
  }

  const reviewerName = request.auth.token?.name || profile.data()?.name || request.auth.token?.email || uid;
  const now = admin.firestore.FieldValue.serverTimestamp();
  const reviewRef = courseRef.collection("reviews").doc();

  const update = decision === "approved"
    ? {
        status: "published",
        isPublished: true,
        rejectionReason: admin.firestore.FieldValue.delete(),
        reviewedAt: now,
        reviewedBy: uid,
      }
    : {
        status: "rejected",
        isPublished: false,
        rejectionReason,
        reviewedAt: now,
        reviewedBy: uid,
      };

  const batch = db.batch();
  batch.update(courseRef, update);
  batch.set(reviewRef, {
    reviewerUid: uid,
    reviewerName,
    decision,
    rejectionReason: decision === "rejected" ? rejectionReason : null,
    reviewedAt: now,
  });
  await batch.commit();

  // Notify the course owner when available.
  const ownerUid = course.ownerUid || course.instructorUid || course.createdBy;
  if (ownerUid) {
    await db.collection("users").doc(String(ownerUid)).collection("notifications").add({
      type: "course_review",
      courseId,
      decision,
      rejectionReason: decision === "rejected" ? rejectionReason : null,
      createdAt: now,
      read: false,
    });
  }

  return { ok: true, status: update.status };
});
