const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const jwt = require('jsonwebtoken');

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
 * Keep the public instructor name on the owner's courses in sync with
 * the profile name. This runs with Admin SDK so users cannot edit course
 * metadata directly.
 */
exports.onUserProfileUpdated = onDocumentUpdated("users/{userId}", async (event) => {
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};
  if ((before.name || "") === (after.name || "")) return;

  const courses = await db.collection("courses")
    .where("ownerUid", "==", event.params.userId)
    .get();

  if (courses.empty) return;
  const batch = db.batch();
  for (const doc of courses.docs) {
    batch.update(doc.ref, { instructorName: String(after.name || "") });
  }
  await batch.commit();
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

/** Create an admin account from the in-app admin panel. */
exports.createAdminAccount = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'لازم تسجل الدخول أولاً');
  const me = await db.collection('users').doc(uid).get();
  const isAdmin = request.auth.token?.admin === true || me.data()?.isAdmin === true || me.data()?.role === 'admin';
  if (!isAdmin) throw new HttpsError('permission-denied', 'ليس لديك صلاحية الأدمن');
  const { email, password, name } = request.data || {};
  if (!email || !password || String(password).length < 8) throw new HttpsError('invalid-argument', 'البريد وكلمة المرور غير صحيحة');
  const created = await admin.auth().createUser({ email: String(email).trim(), password: String(password), displayName: String(name || '').trim() });
  await db.collection('users').doc(created.uid).set({ uid: created.uid, email: created.email, name: String(name || ''), role: 'admin', isAdmin: true, mode: 'mostafhem', createdAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  await admin.auth().setCustomUserClaims(created.uid, { admin: true });
  return { uid: created.uid };
});

/** Temporarily block a user and disable Firebase Authentication. */
exports.setUserBan = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'لازم تسجل الدخول أولاً');
  const me = await db.collection('users').doc(uid).get();
  if (!(request.auth.token?.admin === true || me.data()?.isAdmin === true || me.data()?.role === 'admin')) throw new HttpsError('permission-denied', 'ليس لديك صلاحية الأدمن');
  const targetUid = String(request.data?.uid || '').trim();
  const days = Math.max(1, Math.min(3650, Number(request.data?.days || 1)));
  const reason = String(request.data?.reason || '').trim();
  if (!targetUid || !reason) throw new HttpsError('invalid-argument', 'السبب مطلوب');
  const until = new Date(Date.now() + days * 86400000);
  await admin.auth().updateUser(targetUid, { disabled: true });
  await db.collection('users').doc(targetUid).set({ status: 'blocked', banReason: reason, banDays: days, bannedAt: admin.firestore.FieldValue.serverTimestamp(), bannedUntil: admin.firestore.Timestamp.fromDate(until) }, { merge: true });
  return { ok: true, bannedUntil: until.toISOString() };
});

/** Queue an FCM notification for a specific time. */
exports.scheduleNotification = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'لازم تسجل الدخول أولاً');
  const me = await db.collection('users').doc(uid).get();
  if (!(request.auth.token?.admin === true || me.data()?.isAdmin === true || me.data()?.role === 'admin')) throw new HttpsError('permission-denied', 'ليس لديك صلاحية الأدمن');
  const { title, body, imageUrl, campaign, description, sendAt, audience } = request.data || {};
  const date = new Date(String(sendAt || ''));
  if (!title || !body || Number.isNaN(date.getTime()) || date.getTime() <= Date.now()) throw new HttpsError('invalid-argument', 'بيانات الإشعار أو الموعد غير صحيحة');
  const ref = await db.collection('scheduledNotifications').add({ title: String(title), body: String(body), imageUrl: String(imageUrl || ''), campaign: String(campaign || ''), description: String(description || ''), audience: String(audience || 'all'), sendAt: admin.firestore.Timestamp.fromDate(date), status: 'pending', createdBy: uid, createdAt: admin.firestore.FieldValue.serverTimestamp() });
  return { id: ref.id };
});

/** When a paid session gets a scheduled time, queue reminders for both participants. */
exports.onIstifhamScheduled = onDocumentUpdated('istifhams/{requestId}', async (event) => {
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};
  if (after.status !== 'paid' || !after.meetingTime) return;
  if (String(before.status || '') === 'paid' && String(before.meetingTime || '') === String(after.meetingTime || '')) return;
  const date = new Date(String(after.meetingTime));
  if (Number.isNaN(date.getTime()) || date.getTime() <= Date.now()) return;
  const targetUids = [after.mustafhemId, after.mufhemId].filter(Boolean);
  await db.collection('scheduledNotifications').add({
    title: `موعد المحاضرة: ${String(after.title || 'محاضرة')}`,
    body: `المحاضرة تبدأ في ${date.toLocaleString('ar-EG')}. اضغط على الإشعار للدخول من التطبيق.`,
    imageUrl: String(after.mufhemPhotoUrl || after.imageUrl || ''),
    audience: 'users',
    targetUids,
    action: 'meeting',
    requestId: event.params.requestId,
    sendAt: admin.firestore.Timestamp.fromDate(new Date(date.getTime() - 5 * 60 * 1000)),
    status: 'pending',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
});

/** Runs every minute and delivers due scheduled notifications. */
exports.dispatchScheduledNotifications = require('firebase-functions/v2/scheduler').onSchedule('every 1 minutes', async () => {
  const now = admin.firestore.Timestamp.now();
  const snap = await db.collection('scheduledNotifications').where('status', '==', 'pending').where('sendAt', '<=', now).limit(20).get();
  for (const doc of snap.docs) {
    const n = doc.data();
    await doc.ref.update({ status: 'processing', processingAt: admin.firestore.FieldValue.serverTimestamp() });
    const allUsers = await db.collection('users').get();
    const targetIds = Array.isArray(n.targetUids) && n.targetUids.length ? new Set(n.targetUids.map(String)) : null;
    const users = allUsers.docs.filter(u => !targetIds || targetIds.has(u.id));
    const tokens = [];
    for (const u of users) {
      const ts = await u.ref.collection('fcmTokens').get();
      for (const t of ts.docs) { const token = t.data().token; if (token) tokens.push(token); }
    }
    let sent = 0;
    for (let i = 0; i < tokens.length; i += 500) {
      const chunk = tokens.slice(i, i + 500);
      const response = await admin.messaging().sendEachForMulticast({ tokens: chunk, notification: { title: n.title, body: n.body, ...(n.imageUrl ? { imageUrl: n.imageUrl } : {}) }, data: { type: n.action || 'admin_campaign', notificationId: doc.id, campaign: String(n.campaign || ''), description: String(n.description || ''), ...(n.requestId ? { requestId: String(n.requestId) } : {}) } });
      sent += response.successCount;
    }
    const batch = db.batch();
    for (const u of users.docs) batch.set(u.ref.collection('notifications').doc(doc.id), { title: n.title, body: n.body, imageUrl: n.imageUrl || '', campaign: n.campaign || '', description: n.description || '', type: 'admin_campaign', createdAt: admin.firestore.FieldValue.serverTimestamp(), read: false }, { merge: true });
    await batch.commit();
    await doc.ref.update({ status: 'sent', sentCount: sent, sentAt: admin.firestore.FieldValue.serverTimestamp() });
  }
});

/** Mint a short-lived JaaS JWT for an authenticated app user. */
exports.getJaasMeetingToken = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'لازم تسجل الدخول أولاً');
  const profile = await db.collection('users').doc(uid).get();
  const p = profile.data() || {};
  if (p.status === 'blocked') throw new HttpsError('permission-denied', 'الحساب محظور');
  const appId = process.env.JAAS_APP_ID;
  const keyId = process.env.JAAS_KEY_ID;
  const privateKey = process.env.JAAS_PRIVATE_KEY;
  if (!appId || !keyId || !privateKey) throw new HttpsError('failed-precondition', 'إعدادات JaaS JWT غير مكتملة على الخادم');
  const room = String(request.data?.room || '').trim();
  if (!room || room.includes('/')) throw new HttpsError('invalid-argument', 'اسم الغرفة غير صحيح');
  const now = Math.floor(Date.now() / 1000);
  const moderator = p.isAdmin === true || p.role === 'admin' || p.mode === 'mofahhem';
  const token = jwt.sign({
    aud: 'jitsi',
    iss: 'chat',
    sub: appId,
    room,
    nbf: now - 5,
    exp: now + 2 * 60 * 60,
    context: { user: { id: uid, name: String(p.name || request.auth.token.name || request.auth.token.email || uid), email: String(p.email || request.auth.token.email || ''), avatar: String(p.photoUrl || ''), moderator: String(moderator) }, features: { recording: moderator, livestreaming: false, transcription: false } }
  }, privateKey.replace(/\\n/g, '\n'), { algorithm: 'RS256', keyid: keyId, header: { typ: 'JWT' } });
  return { token, appId };
});

/** JaaS webhook: preserve uploaded lecture recordings in Firebase Storage. */
exports.jaasRecordingWebhook = require('firebase-functions/v2/https').onRequest(async (req, res) => {
  try {
    const event = req.body || {};
    const type = String(event.event || event.type || '').toUpperCase();
    if (type !== 'RECORDING_UPLOADED' && type !== 'RECORDING_ENDED') { res.status(200).send('ignored'); return; }
    const data = event.data || event;
    const url = data.preAuthenticatedLink || data.preAuthenticatedUrl || data.recordingUrl || data.url;
    if (!url) { res.status(400).send('missing recording url'); return; }
    const room = String(data.roomName || data.room || data.conferenceId || 'unknown-room');
    const requestId = String(data.requestId || data.meetingId || room.replace(/^.*Fahimni_/, ''));
    const response = await fetch(url);
    if (!response.ok) throw new Error(`recording download failed: ${response.status}`);
    const buffer = Buffer.from(await response.arrayBuffer());
    const storagePath = `meeting-recordings/${requestId}/${Date.now()}.mp4`;
    const file = bucket.file(storagePath);
    await file.save(buffer, { metadata: { contentType: 'video/mp4', metadata: { source: 'jaas', requestId } } });
    await db.collection('istifhams').doc(requestId).set({ recordingStoragePath: storagePath, recordingSavedAt: admin.firestore.FieldValue.serverTimestamp(), recordingSource: 'jaas' }, { merge: true });
    res.status(200).json({ ok: true, storagePath });
  } catch (e) { console.error(e); res.status(500).send('webhook error'); }
});
