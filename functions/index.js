/**
 * STAYHUB PRODUCTION PAYMENT ENGINE v3.3
 * Updated: 2026-05-19 (Node 22 + Full Firebase Functions v2 Migration)
 */

const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { defineSecret } = require("firebase-functions/params");
const { v4: uuidv4 } = require("uuid");
const axios = require("axios");
const crypto = require("crypto");

admin.initializeApp();

// --- SECRETS ---
const PAYSTACK_SECRET_KEY = defineSecret("PAYSTACK_SECRET_KEY");
const RESEND_API_KEY = defineSecret("RESEND_API_KEY");

function getPaystackSecretKey() {
  try {
    return PAYSTACK_SECRET_KEY.value();
  } catch (e) {
    console.error("PAYSTACK_SECRET_KEY is not defined in Secret Manager:", e.message);
    return null;
  }
}

// --- HELPERS ---

// --- EMAIL HELPERS ---

async function sendResendEmail(apiKey, to, subject, html) {
  try {
    await axios.post("https://api.resend.com/emails", {
      from: "StayHub <noreply@stayhubgh.com>",
      to: Array.isArray(to) ? to : [to],
      subject,
      html,
    }, { headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" } });
  } catch (e) {
    console.error(`[sendResendEmail] Failed to send to ${to}:`, e.response?.data || e.message);
  }
}

function emailShell(content) {
  return `<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>StayHub</title></head>
<body style="margin:0;padding:0;background:#F1F5F9;font-family:'Segoe UI',Arial,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#F1F5F9;padding:32px 0;">
  <tr><td align="center">
    <table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
      <!-- HEADER -->
      <tr><td style="background:linear-gradient(135deg,#1E1A8C 0%,#2E2AB7 60%,#4A46D0 100%);padding:32px 40px;">
        <table width="100%" cellpadding="0" cellspacing="0"><tr>
          <td><span style="color:#fff;font-size:26px;font-weight:900;letter-spacing:2px;">STAYHUB</span><br>
          <span style="color:rgba(255,255,255,0.65);font-size:11px;font-weight:700;letter-spacing:2px;">STUDENT HOUSING PLATFORM</span></td>
          <td align="right"><span style="background:rgba(255,255,255,0.15);color:#fff;padding:6px 14px;border-radius:20px;font-size:11px;font-weight:700;letter-spacing:1px;">stayhubgh.com</span></td>
        </tr></table>
      </td></tr>
      <!-- BODY -->
      <tr><td style="padding:40px;">
        ${content}
      </td></tr>
      <!-- FOOTER -->
      <tr><td style="background:#F8FAFC;border-top:1px solid #E2E8F0;padding:24px 40px;">
        <table width="100%" cellpadding="0" cellspacing="0"><tr>
          <td><span style="color:#94A3B8;font-size:11px;">© ${new Date().getFullYear()} StayHub Ghana. All rights reserved.</span></td>
          <td align="right"><a href="https://stayhubgh.com" style="color:#2E2AB7;font-size:11px;text-decoration:none;font-weight:700;">stayhubgh.com</a></td>
        </tr></table>
      </td></tr>
    </table>
  </td></tr>
</table>
</body></html>`;
}

function buildOtpEmailHtml(otp) {
  return emailShell(`
    <p style="margin:0 0 8px;color:#64748B;font-size:13px;font-weight:700;letter-spacing:1px;text-transform:uppercase;">Email Verification</p>
    <h1 style="margin:0 0 16px;color:#0F172A;font-size:28px;font-weight:900;">Verify your account</h1>
    <p style="margin:0 0 32px;color:#475569;font-size:15px;line-height:1.6;">Use the code below to verify your StayHub account. This code expires in <strong>10 minutes</strong>.</p>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:32px;">
      <tr><td align="center">
        <div style="display:inline-block;background:#F0F4FF;border:2px dashed #2E2AB7;border-radius:16px;padding:24px 48px;">
          <span style="font-size:42px;font-weight:900;letter-spacing:12px;color:#2E2AB7;font-family:monospace;">${otp}</span>
        </div>
      </td></tr>
    </table>
    <table width="100%" cellpadding="0" cellspacing="0" style="background:#FEF3C7;border-radius:10px;margin-bottom:24px;">
      <tr><td style="padding:16px 20px;">
        <span style="color:#92400E;font-size:13px;">⚠️ <strong>Never share this code</strong> with anyone, including StayHub staff. We will never ask for it.</span>
      </td></tr>
    </table>
    <p style="margin:0;color:#94A3B8;font-size:13px;">If you didn't request this, you can safely ignore this email.</p>
  `);
}

function buildPasswordResetEmailHtml(link) {
  return emailShell(`
    <p style="margin:0 0 8px;color:#64748B;font-size:13px;font-weight:700;letter-spacing:1px;text-transform:uppercase;">Account Security</p>
    <h1 style="margin:0 0 16px;color:#0F172A;font-size:28px;font-weight:900;">Reset your password</h1>
    <p style="margin:0 0 32px;color:#475569;font-size:15px;line-height:1.6;">We received a request to reset your StayHub password. Click the button below to set a new password. This link expires in <strong>1 hour</strong>.</p>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:32px;">
      <tr><td align="center">
        <a href="${link}" style="display:inline-block;background:linear-gradient(135deg,#1E1A8C,#2E2AB7);color:#fff;text-decoration:none;padding:16px 40px;border-radius:12px;font-size:15px;font-weight:900;letter-spacing:0.5px;">Reset My Password</a>
      </td></tr>
    </table>
    <p style="margin:0 0 16px;color:#64748B;font-size:13px;">Or copy and paste this link into your browser:</p>
    <p style="margin:0 0 32px;background:#F1F5F9;padding:12px 16px;border-radius:8px;word-break:break-all;font-size:12px;color:#2E2AB7;">${link}</p>
    <table width="100%" cellpadding="0" cellspacing="0" style="background:#FEF3C7;border-radius:10px;">
      <tr><td style="padding:16px 20px;">
        <span style="color:#92400E;font-size:13px;">⚠️ If you did not request a password reset, please ignore this email or contact support immediately at <strong>support@stayhubgh.com</strong>.</span>
      </td></tr>
    </table>
  `);
}

function fmtGhs(amount) {
  return `GHS ${Number(amount || 0).toFixed(2)}`;
}

function fmtDate(val) {
  if (!val) return "—";
  const d = val?.toDate ? val.toDate() : new Date(val);
  if (isNaN(d.getTime())) return "—";
  return d.toLocaleDateString("en-GH", { day: "numeric", month: "long", year: "numeric" });
}

function receiptRow(label, value, highlight = false) {
  return `<tr>
    <td style="padding:10px 0;color:#64748B;font-size:13px;font-weight:600;border-bottom:1px solid #F1F5F9;">${label}</td>
    <td style="padding:10px 0;color:${highlight ? "#2E2AB7" : "#0F172A"};font-size:13px;font-weight:${highlight ? "900" : "700"};text-align:right;border-bottom:1px solid #F1F5F9;">${value}</td>
  </tr>`;
}

function buildStudentReceiptEmailHtml(bData, bookingId) {
  const amt = bData.amounts || {};
  const ref = bData.paymentReference || "—";
  const hostel = bData.hostelSnapshot?.name || bData.hostelName || "—";
  const room = (bData.roomType || "Standard").replace(/-/g, " ").replace(/\b\w/g, c => c.toUpperCase());

  return emailShell(`
    <!-- Status badge -->
    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:32px;">
      <tr><td align="center">
        <div style="display:inline-block;background:#DCFCE7;border:1.5px solid #86EFAC;border-radius:24px;padding:10px 28px;">
          <span style="color:#15803D;font-size:13px;font-weight:900;letter-spacing:1px;">✓ PAYMENT SUCCESSFUL</span>
        </div>
      </td></tr>
    </table>

    <p style="margin:0 0 8px;color:#64748B;font-size:13px;font-weight:700;letter-spacing:1px;text-transform:uppercase;">Booking Receipt</p>
    <h1 style="margin:0 0 8px;color:#0F172A;font-size:28px;font-weight:900;">Your room is secured! 🎉</h1>
    <p style="margin:0 0 32px;color:#475569;font-size:15px;line-height:1.6;">Hi <strong>${bData.userName || "Student"}</strong>, your payment has been confirmed and your booking is now active. Keep this receipt for your records.</p>

    <!-- Amount highlight -->
    <table width="100%" cellpadding="0" cellspacing="0" style="background:linear-gradient(135deg,#1E1A8C,#2E2AB7);border-radius:16px;margin-bottom:32px;">
      <tr><td style="padding:28px;text-align:center;">
        <p style="margin:0 0 4px;color:rgba(255,255,255,0.7);font-size:11px;font-weight:700;letter-spacing:2px;">TOTAL AMOUNT PAID</p>
        <p style="margin:0;color:#fff;font-size:40px;font-weight:900;letter-spacing:-1px;">${fmtGhs(amt.total || bData.price)}</p>
      </td></tr>
    </table>

    <!-- Booking details table -->
    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:32px;">
      ${receiptRow("Booking ID", bookingId, true)}
      ${receiptRow("Payment Reference", ref, true)}
      ${receiptRow("Hostel", hostel)}
      ${receiptRow("Room Type", room)}
      ${receiptRow("Check-in", fmtDate(bData.checkIn))}
      ${receiptRow("Check-out", fmtDate(bData.checkOut))}
      ${receiptRow("Base Rent", fmtGhs(amt.base || bData.price))}
      ${receiptRow("Service Charge (10%)", fmtGhs(amt.serviceCharge))}
      <tr>
        <td style="padding:14px 0;color:#0F172A;font-size:15px;font-weight:900;">Total Paid</td>
        <td style="padding:14px 0;color:#2E2AB7;font-size:15px;font-weight:900;text-align:right;">${fmtGhs(amt.total || bData.price)}</td>
      </tr>
    </table>

    <!-- QR hint -->
    <table width="100%" cellpadding="0" cellspacing="0" style="background:#F0F4FF;border-radius:12px;margin-bottom:32px;">
      <tr><td style="padding:20px 24px;">
        <p style="margin:0 0 6px;color:#2E2AB7;font-size:14px;font-weight:900;">📱 Check-in with the app</p>
        <p style="margin:0;color:#475569;font-size:13px;line-height:1.6;">Open StayHub → Bookings → tap your booking to view your QR ticket. Show it to the hostel agent when you arrive.</p>
      </td></tr>
    </table>

    <p style="margin:0;color:#94A3B8;font-size:13px;line-height:1.6;">Need help? Contact us at <a href="mailto:support@stayhubgh.com" style="color:#2E2AB7;">support@stayhubgh.com</a></p>
  `);
}

function buildAgentPaymentNotificationHtml(bData, bookingId) {
  const amt = bData.amounts || {};
  const hostel = bData.hostelSnapshot?.name || bData.hostelName || "—";
  const room = (bData.roomType || "Standard").replace(/-/g, " ").replace(/\b\w/g, c => c.toUpperCase());

  return emailShell(`
    <!-- Status badge -->
    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:32px;">
      <tr><td align="center">
        <div style="display:inline-block;background:#DCFCE7;border:1.5px solid #86EFAC;border-radius:24px;padding:10px 28px;">
          <span style="color:#15803D;font-size:13px;font-weight:900;letter-spacing:1px;">💰 PAYMENT RECEIVED</span>
        </div>
      </td></tr>
    </table>

    <p style="margin:0 0 8px;color:#64748B;font-size:13px;font-weight:700;letter-spacing:1px;text-transform:uppercase;">Payment Notification</p>
    <h1 style="margin:0 0 8px;color:#0F172A;font-size:28px;font-weight:900;">A student has paid!</h1>
    <p style="margin:0 0 32px;color:#475569;font-size:15px;line-height:1.6;"><strong>${bData.userName || "A student"}</strong> has successfully completed payment for a room at <strong>${hostel}</strong>. Their booking is now confirmed.</p>

    <!-- Amount highlight -->
    <table width="100%" cellpadding="0" cellspacing="0" style="background:linear-gradient(135deg,#065F46,#10B981);border-radius:16px;margin-bottom:32px;">
      <tr><td style="padding:28px;text-align:center;">
        <p style="margin:0 0 4px;color:rgba(255,255,255,0.7);font-size:11px;font-weight:700;letter-spacing:2px;">TOTAL PAYMENT RECEIVED</p>
        <p style="margin:0;color:#fff;font-size:40px;font-weight:900;letter-spacing:-1px;">${fmtGhs(amt.total || bData.price)}</p>
      </td></tr>
    </table>

    <!-- Booking details -->
    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:32px;">
      ${receiptRow("Booking ID", bookingId, true)}
      ${receiptRow("Payment Reference", bData.paymentReference || "—", true)}
      ${receiptRow("Student", bData.userName || "—")}
      ${receiptRow("Student Email", bData.userEmail || "—")}
      ${receiptRow("Hostel", hostel)}
      ${receiptRow("Room Type", room)}
      ${receiptRow("Check-in", fmtDate(bData.checkIn))}
      ${receiptRow("Check-out", fmtDate(bData.checkOut))}
      ${receiptRow("Base Rent (Your Share)", fmtGhs(amt.base || bData.price))}
      ${receiptRow("Service Charge", fmtGhs(amt.serviceCharge))}
      <tr>
        <td style="padding:14px 0;color:#0F172A;font-size:15px;font-weight:900;">Total Collected</td>
        <td style="padding:14px 0;color:#10B981;font-size:15px;font-weight:900;text-align:right;">${fmtGhs(amt.total || bData.price)}</td>
      </tr>
    </table>

    <!-- Verify hint -->
    <table width="100%" cellpadding="0" cellspacing="0" style="background:#F0FFF4;border:1.5px solid #86EFAC;border-radius:12px;margin-bottom:32px;">
      <tr><td style="padding:20px 24px;">
        <p style="margin:0 0 6px;color:#15803D;font-size:14px;font-weight:900;">🔍 Verify student on arrival</p>
        <p style="margin:0;color:#475569;font-size:13px;line-height:1.6;">Open StayHub → Ticket Scanner → scan the student's QR code to verify their identity and mark them as checked in.</p>
      </td></tr>
    </table>

    <p style="margin:0;color:#94A3B8;font-size:13px;line-height:1.6;">Questions? <a href="mailto:support@stayhubgh.com" style="color:#2E2AB7;">support@stayhubgh.com</a></p>
  `);
}

async function sendPaymentReceiptEmails(bData, bookingId, resendApiKey) {
  if (!resendApiKey) return;

  const db = admin.firestore();
  const promises = [];

  // Send to student
  const studentEmail = bData.userEmail || bData.email || null;
  if (studentEmail) {
    promises.push(sendResendEmail(
      resendApiKey,
      studentEmail,
      `✅ Payment Confirmed – ${bData.hostelName || "Your Hostel"} | StayHub`,
      buildStudentReceiptEmailHtml(bData, bookingId)
    ));
  } else if (bData.userId) {
    try {
      const userRecord = await admin.auth().getUser(bData.userId);
      if (userRecord.email) {
        promises.push(sendResendEmail(
          resendApiKey,
          userRecord.email,
          `✅ Payment Confirmed – ${bData.hostelName || "Your Hostel"} | StayHub`,
          buildStudentReceiptEmailHtml(bData, bookingId)
        ));
      }
    } catch (e) { console.warn("[receiptEmail] Could not fetch student email:", e.message); }
  }

  // Send to agent/owner
  const agentId = bData.hostelSnapshot?.agentId || bData.agentId || null;
  const ownerId = bData.hostelSnapshot?.ownerId || bData.ownerId || null;
  const notifyId = agentId || ownerId;

  if (notifyId) {
    try {
      let agentEmail = null;
      const agentDoc = await db.collection("agents").doc(notifyId).get();
      if (agentDoc.exists) agentEmail = agentDoc.data().email || null;
      if (!agentEmail) {
        const agentAuth = await admin.auth().getUser(notifyId);
        agentEmail = agentAuth.email || null;
      }
      if (agentEmail) {
        promises.push(sendResendEmail(
          resendApiKey,
          agentEmail,
          `💰 Payment Received – ${bData.hostelName || "Your Hostel"} | StayHub`,
          buildAgentPaymentNotificationHtml(bData, bookingId)
        ));
      }
    } catch (e) { console.warn("[receiptEmail] Could not fetch agent email:", e.message); }
  }

  await Promise.allSettled(promises);
}

async function createAuditLog(bookingId, action, actor, metadata = {}) {
  try {
    await admin.firestore().collection("bookingAuditLogs").add({
      bookingId,
      action,
      actor,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      metadata,
    });
  } catch (e) {
    console.error("Audit Log Failure:", e.message);
  }
}

function getMs(val) {
  if (!val) return NaN;
  if (typeof val.toMillis === "function") return val.toMillis();
  if (typeof val.toDate === "function") return val.toDate().getTime();
  if (val._seconds) return val._seconds * 1000;
  if (typeof val === "number") return val;
  const ms = new Date(val).getTime();
  return isNaN(ms) ? NaN : ms;
}

function isOverlapping(s1, e1, s2, e2) {
  const start1 = getMs(s1);
  const end1 = getMs(e1);
  const start2 = getMs(s2);
  const end2 = getMs(e2);
  if (isNaN(start1) || isNaN(end1) || isNaN(start2) || isNaN(end2)) {
    console.warn(`[isOverlapping] Invalid dates detected:`, { s1, e1, s2, e2 });
    return false;
  }
  return start1 < end2 && end1 > start2;
}

async function fetchCommissionConfig(db) {
  try {
    const doc = await db.collection("config").doc("commission").get();
    if (doc.exists) {
      const d = doc.data();
      return {
        serviceChargePercent: ((d.serviceChargePercent ?? 10)) / 100,
        agentSplitPercent: ((d.agentSplitPercent ?? 50)) / 100,
        paystackFeePercent: ((d.paystackFeePercent ?? 1.5)) / 100,
      };
    }
  } catch (e) { console.warn("[config] fetchCommissionConfig failed:", e.message); }
  return { serviceChargePercent: 0.10, agentSplitPercent: 0.50, paystackFeePercent: 0.015 };
}

function calculateStayHubSplit(basePrice, hasAgent, cfg = {}) {
  const scRate = cfg.serviceChargePercent ?? 0.10;
  const agentRate = cfg.agentSplitPercent ?? 0.50;
  const pstkRate = cfg.paystackFeePercent ?? 0.015;
  const serviceCharge = parseFloat((basePrice * scRate).toFixed(2));
  const total = parseFloat((basePrice + serviceCharge).toFixed(2));
  const paystackFee = parseFloat((total * pstkRate).toFixed(2));
  const netCommission = parseFloat((serviceCharge - paystackFee).toFixed(2));
  const agentShare = hasAgent ? parseFloat((netCommission * agentRate).toFixed(2)) : 0;
  const platformShare = parseFloat((netCommission - agentShare).toFixed(2));
  return { basePrice, serviceCharge, total, paystackFee, netCommission, agentShare, platformShare, ownerShare: basePrice };
}

async function resolveSubaccount(db, userId, collection = "agents") {
  if (!userId) return null;
  const snap = await db.collection(collection).doc(userId).get();
  if (snap.exists) {
    const data = snap.data();
    const code = data.paystack_subaccount_code || data.paystackSubaccountCode;
    if (code) return code;
  }
  const otherCollection = collection === "agents" ? "users" : "agents";
  const otherSnap = await db.collection(otherCollection).doc(userId).get();
  if (otherSnap.exists) {
    const otherData = otherSnap.data();
    return otherData.paystack_subaccount_code || otherData.paystackSubaccountCode || null;
  }
  return null;
}

function buildPaystackSplit(ownerSubaccount, agentSubaccount, splitCalc) {
  const subaccounts = [
    { subaccount: ownerSubaccount, share: Math.round(splitCalc.ownerShare * 100) },
  ];
  if (agentSubaccount && splitCalc.agentShare > 0) {
    subaccounts.push({
      subaccount: agentSubaccount,
      share: Math.round(splitCalc.agentShare * 100),
    });
  }
  return { type: "flat", bearer_type: "account", subaccounts };
}

async function postPaystackInitialize(secretKey, payload) {
  return axios.post("https://api.paystack.co/transaction/initialize", payload, {
    headers: { Authorization: `Bearer ${secretKey}`, "Content-Type": "application/json" },
  });
}

async function initializePaystackWithFallback(secretKey, basePayload, options) {
  const { ownerSubaccount, agentSubaccount, splitCalc, settlementMeta } = options;
  const attempts = [];

  if (ownerSubaccount) {
    attempts.push({
      label: "owner+agent split",
      payload: { ...basePayload, split: buildPaystackSplit(ownerSubaccount, agentSubaccount, splitCalc) },
      meta: { ...settlementMeta, ownerSubaccountUsed: true, paystackSplitUsed: true, agentSettledViaPaystack: !!(agentSubaccount && splitCalc.agentShare > 0) },
    });
    attempts.push({
      label: "owner-only split",
      payload: { ...basePayload, split: buildPaystackSplit(ownerSubaccount, null, splitCalc) },
      meta: { ...settlementMeta, ownerSubaccountUsed: true, paystackSplitUsed: true, agentSettledViaPaystack: false },
    });
    attempts.push({
      label: "legacy subaccount charge",
      payload: { ...basePayload, subaccount: ownerSubaccount, transaction_charge: Math.round(splitCalc.serviceCharge * 100), bearer: "account" },
      meta: { ...settlementMeta, ownerSubaccountUsed: true, paystackSplitUsed: false, agentSettledViaPaystack: false },
    });
  }

  attempts.push({
    label: "no split",
    payload: { ...basePayload },
    meta: { ownerSubaccountUsed: false, paystackSplitUsed: false, agentSettledViaPaystack: false },
  });

  let lastError = "Paystack initialization failed";
  for (const attempt of attempts) {
    try {
      const res = await postPaystackInitialize(secretKey, attempt.payload);
      if (res.data?.status) {
        console.log(`[Paystack] Success via: ${attempt.label}`);
        return { response: res, settlementMeta: attempt.meta };
      }
      lastError = res.data?.message || lastError;
      console.warn(`[Paystack] ${attempt.label} declined:`, lastError);
    } catch (e) {
      lastError = e.response?.data?.message || e.message || lastError;
      console.warn(`[Paystack] ${attempt.label} error:`, lastError);
    }
  }
  throw new Error(lastError);
}

async function updateRoomStateRegistry(transaction, hostelId, roomId, lockId, status) {
  const db = admin.firestore();
  const roomStateRef = db.collection("hostelRoomStates").doc(`${hostelId}_${roomId}`);
  const roomStateSnap = await transaction.get(roomStateRef);

  if (roomStateSnap.exists) {
    const data = roomStateSnap.data();
    const now = Date.now();
    const reservations = (data.reservations || []).map(r => {
      if (r.id === lockId) return { ...r, status, expiresAt: null };
      return r;
    });

    const cleanedReservations = reservations.filter(r => {
      if (r.status === "CANCELLED" || r.status === "EXPIRED") return false;
      if (r.status === "PENDING") {
        const expiryMs = getMs(r.expiresAt);
        if (isNaN(expiryMs) || expiryMs < now) return false;
      }
      if (r.status === "PAID" || r.status === "CONFIRMED") {
        const checkOutMs = getMs(r.checkOut);
        if (!isNaN(checkOutMs) && checkOutMs < now - (24 * 60 * 60 * 1000)) return false;
      }
      return true;
    });

    transaction.update(roomStateRef, {
      reservations: cleanedReservations,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

// --- CORE CALLABLES ---

exports.prepareBooking = onCall({ secrets: [PAYSTACK_SECRET_KEY] }, async (request) => {
  const data = request.data;
  const userId = request.auth?.uid;

  console.log("[prepareBooking] INVOKED", { uid: userId || null, keys: data ? Object.keys(data) : [] });

  const stepLogs = [];
  const logStep = (step, info = {}) => {
    const msg = `[prepareBooking][Step: ${step}]`;
    try { console.log(msg, JSON.stringify(info)); } catch (_) { console.log(msg, String(info)); }
    stepLogs.push({ step, timestamp: Date.now(), ...info });
  };

  try {
    const { hostelId, roomId, checkIn, checkOut, idempotencyKey } = data || {};

    logStep("1_PAYLOAD_RECEIVED", { userId, hostelId, roomId, checkIn, checkOut, idempotencyKey });

    if (!userId) throw new HttpsError("unauthenticated", "Authentication required. Server did not receive a valid user identity.");
    if (!hostelId || !roomId || !checkIn || !checkOut) throw new HttpsError("invalid-argument", "Missing required booking details (hostel, room, or dates).");

    const db = admin.firestore();
    const safeRoomId = String(roomId).replace(/\s+/g, "_");
    const lockId = idempotencyKey || `LOCK_${userId}_${hostelId}_${safeRoomId}_${Date.now()}`;

    logStep("2_STARTING_TRANSACTION", { lockId });

    return await db.runTransaction(async (transaction) => {
      logStep("3_FETCHING_HOSTEL", { hostelId });
      const hostelSnap = await transaction.get(db.collection("hostels").doc(hostelId));
      if (!hostelSnap.exists) {
        logStep("ERROR_HOSTEL_NOT_FOUND", { hostelId });
        return { success: false, status: "ERROR", errorCode: "HOSTEL_NOT_FOUND", message: `Hostel not found: ${hostelId}` };
      }
      const hostelData = hostelSnap.data() || {};

      logStep("4_RESOLVING_ROOM_CONFIG", { roomId });
      let roomLimit = 1;
      let resolvedRoomName = roomId;

      const rooms = Array.isArray(hostelData.rooms) ? hostelData.rooms : [];
      const roomConfig = rooms.find((r) => r && (r.id === roomId || r.type === roomId));

      if (roomConfig) {
        roomLimit = parseInt(roomConfig.quantity || roomConfig.available || 1);
        resolvedRoomName = roomConfig.type || roomConfig.name || roomId;
        logStep("ROOM_CONFIG_FOUND", { roomLimit, resolvedRoomName });
      } else if (roomId === "legacy" || rooms.length === 0) {
        roomLimit = parseInt(hostelData.capacity || 1);
        resolvedRoomName = "Standard Room (Legacy)";
        logStep("ROOM_CONFIG_LEGACY_FALLBACK", { roomLimit, resolvedRoomName });
      } else {
        logStep("ERROR_ROOM_NOT_FOUND", { roomId, availableRooms: rooms.map(r => r.type) });
        return { success: false, status: "ERROR", errorCode: "ROOM_NOT_FOUND", message: `The selected room type "${roomId}" is no longer available in this hostel.` };
      }

      const roomStateId = `${hostelId}_${roomId}`;
      const roomStateRef = db.collection("hostelRoomStates").doc(roomStateId);
      logStep("5_FETCHING_ROOM_STATE", { roomStateId });
      const roomStateSnap = await transaction.get(roomStateRef);

      const rawReservations = roomStateSnap.exists ? roomStateSnap.data().reservations : [];
      const reservations = Array.isArray(rawReservations) ? rawReservations : [];
      const nowMs = Date.now();

      logStep("6_FILTERING_RESERVATIONS", { totalInRegistry: reservations.length });
      const activeReservations = reservations.filter(r => {
        if (r.status === "PAID" || r.status === "CONFIRMED" || r.status === "CHECKED_IN") return true;
        const expiryMs = getMs(r.expiresAt);
        if (!isNaN(expiryMs) && expiryMs > nowMs) return true;
        return false;
      });

      logStep("7_CHECKING_OVERLAP", { activeCount: activeReservations.length, roomLimit });
      const overlapping = activeReservations.filter(r => isOverlapping(checkIn, checkOut, r.checkIn, r.checkOut));

      if (overlapping.length >= roomLimit) {
        const existingMyLock = overlapping.find(r => r.userId === userId && r.status === "PENDING");
        if (existingMyLock) {
          logStep("IDEMPOTENT_RESUME", { lockId: existingMyLock.id });
          return { success: true, status: "IDEMPOTENT_RESUME", lockId: existingMyLock.id, bookingId: existingMyLock.id };
        }
        logStep("ERROR_CAPACITY_EXCEEDED", { overlappingCount: overlapping.length, roomLimit });
        return { success: false, status: "ERROR", errorCode: "ROOM_FULL", message: `The "${resolvedRoomName}" is fully booked for these dates.` };
      }

      logStep("8_CREATING_LOCK", { lockId });
      const expiresAt = admin.firestore.Timestamp.fromMillis(nowMs + 15 * 60 * 1000);
      const lockData = { id: lockId, userId, hostelId, roomId, roomName: resolvedRoomName, checkIn, checkOut, status: "PENDING", expiresAt, createdAt: admin.firestore.FieldValue.serverTimestamp() };

      logStep("9_COMMITTING_UPDATES");
      const newReservationEntry = { id: lockId, userId, checkIn, checkOut, status: "PENDING", expiresAt: expiresAt.toDate().toISOString() };

      transaction.set(roomStateRef, {
        reservations: [...activeReservations, newReservationEntry],
        hostelId, roomId,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      transaction.set(db.collection("paymentLocks").doc(lockId), lockData);
      logStep("TRANSACTION_SUCCESS", { lockId });
      return { success: true, status: "SUCCESS", lockId, bookingId: lockId };
    });
  } catch (error) {
    console.error("[prepareBooking] CRITICAL EXCEPTION:", error?.stack || error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", error?.message || String(error) || "Booking system failure");
  }
});

exports.getPaymentPortal = onCall(
  { secrets: [PAYSTACK_SECRET_KEY], region: "us-central1", minInstances: 1 },
  async (request) => {
    const auth = request.auth;
    const data = request.data;

    if (!auth) throw new HttpsError("unauthenticated", "Login required");

    const bookingId = data?.bookingId ?? null;
    if (!bookingId) throw new HttpsError("invalid-argument", "bookingId is required");

    const uid = auth.uid;
    const email = auth.token?.email || `user_${uid}@stayhub.com`;
    const db = admin.firestore();

    let snap = await db.collection("bookings").doc(bookingId).get();
    if (!snap.exists) snap = await db.collection("users").doc(uid).collection("bookings").doc(bookingId).get();
    if (!snap.exists) throw new HttpsError("not-found", "Booking not found");

    const b = snap.data();
    if (b.userId && b.userId !== uid) throw new HttpsError("permission-denied", "Not your booking");
    if (b.status === "PAID") return { status: "ERROR", message: "This booking is already paid." };
    if (!["CONFIRMED", "PAYMENT_PENDING"].includes(b.status)) {
      return { status: "ERROR", message: "Booking must be approved by the agent before payment." };
    }

    if (b.status === "PAYMENT_PENDING" && b.authorizationUrl && b.accessCode) {
      const existingRef = b.paymentReference || bookingId;
      console.log(`[getPaymentPortal] Reusing existing transaction ref=${existingRef}`);
      return { status: "SUCCESS", authorization_url: b.authorizationUrl, access_code: b.accessCode, total_amount: b.amounts?.total || parseFloat(b.price ?? 0), reference: existingRef };
    }

    const basePrice = parseFloat(b.amounts?.base ?? b.price ?? 0);
    if (!basePrice || basePrice <= 0) return { status: "ERROR", message: "Booking has no valid price. Ask the agent to re-approve." };

    let hostelId = b.hostelId;
    if (!hostelId && b.hostelName) {
      const byName = await db.collection("hostels").where("name", "==", b.hostelName).limit(1).get();
      if (!byName.empty) hostelId = byName.docs[0].id;
    }
    if (!hostelId) return { status: "ERROR", message: "Booking is missing hostel information." };

    const hostelSnap = await db.collection("hostels").doc(hostelId).get();
    const hostelData = hostelSnap.exists ? hostelSnap.data() : {};

    const agentId = hostelData.agentId || b.agentId || null;
    const partnerType = hostelData.partnerType || b.partnerType || "owner";
    // hasAgent = true only when a separate agent is managing someone else's property.
    // partnerType "agent" means the person who listed the hostel is acting as an agent for
    // a different property owner. partnerType "owner" means the lister owns it themselves.
    const hasAgent = partnerType === "agent" && agentId !== null;
    const commissionConfig = await fetchCommissionConfig(db);
    if (hasAgent && agentId) {
      try {
        const agentDoc = await db.collection("agents").doc(agentId).get();
        if (agentDoc.exists) {
          const agentCommissionRate = agentDoc.data().commissionRate;
          if (typeof agentCommissionRate === "number" && agentCommissionRate >= 0 && agentCommissionRate <= 100) {
            commissionConfig.agentSplitPercent = agentCommissionRate / 100;
            console.log(`[getPaymentPortal] Per-agent commission override: agentId=${agentId} rate=${agentCommissionRate}%`);
          }
        }
      } catch (e) {
        console.warn("[getPaymentPortal] Failed to read per-agent commission:", e.message);
      }
    }
    const splitCalc = calculateStayHubSplit(basePrice, hasAgent, commissionConfig);

    // Owner subaccount: saved to the hostel document during "Add Hostel" setup.
    // For owner-type listings this is the owner's own wallet account.
    // For agent-type listings this is the third-party owner's bank account.
    let ownerSubaccount = hostelData.ownerSubaccountCode || hostelData.owner_subaccount_code || hostelData.subaccount_code || null;
    // Fallback: resolve from the agent's own profile (handles owner-type where subcode
    // may not yet be stored on the hostel doc).
    if (!ownerSubaccount && agentId && !hasAgent) {
      ownerSubaccount = await resolveSubaccount(db, agentId, "agents");
    }

    // Agent subaccount: always from the agent's wallet page profile (agents/{agentId}).
    let agentSubaccount = null;
    if (hasAgent) {
      agentSubaccount = await resolveSubaccount(db, agentId, "agents");
    }

    console.log(`[getPaymentPortal] bookingId=${bookingId} base=${basePrice} total=${splitCalc.total} ownerSub=${ownerSubaccount || 'NONE'} agentSub=${agentSubaccount || 'NONE'} hasAgent=${hasAgent}`);

    if (hasAgent && !agentSubaccount) {
      console.warn(`[getPaymentPortal] Agent ${agentId} has no payout account — GHS ${splitCalc.agentShare.toFixed(2)} commission will be held.`);
      try {
        await db.collection("users").doc(agentId).collection("notifications").doc(`payout_warn_${bookingId}`).set({
          title: "Payout Account Required ⚠️",
          body: `A student is paying for a room. Set up your payout account to automatically receive your GHS ${splitCalc.agentShare.toFixed(2)} commission.`,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false, type: "PAYOUT_SETUP_REQUIRED", bookingId,
        });
      } catch (e) { console.error("[getPaymentPortal] Failed to send payout warning:", e.message); }
    }

    const secretKey = PAYSTACK_SECRET_KEY.value();
    if (!secretKey) throw new HttpsError("internal", "Paystack key not configured");

    const paystackRef = `${bookingId}-${Date.now()}`;
    const basePayload = {
      email, amount: Math.round(splitCalc.total * 100), reference: paystackRef, currency: "GHS",
      callback_url: "https://stayhubgh.com/app/#/payment-callback",
      metadata: { bookingId, userId: uid, hasAgent },
    };

    let paystackResponse, settlementMeta;
    try {
      const result = await initializePaystackWithFallback(secretKey, basePayload, {
        ownerSubaccount, agentSubaccount, splitCalc,
        settlementMeta: { ownerSubaccountUsed: false, agentSettledViaPaystack: false, paystackSplitUsed: false },
      });
      paystackResponse = result.response;
      settlementMeta = result.settlementMeta;
    } catch (e) {
      console.error("[getPaymentPortal] Paystack failed:", e.message);
      throw new HttpsError("internal", `Paystack error: ${e.message}`);
    }

    const authUrl = paystackResponse.data.data.authorization_url;
    const accessCode = paystackResponse.data.data.access_code;

    const paymentUpdate = {
      status: "PAYMENT_PENDING", paymentReference: paystackRef, accessCode, authorizationUrl: authUrl,
      subaccountUsed: ownerSubaccount || null,
      ownerSubaccountUsed: settlementMeta.ownerSubaccountUsed,
      agentSettledViaPaystack: settlementMeta.agentSettledViaPaystack,
      paystackSplitUsed: settlementMeta.paystackSplitUsed,
      amounts: { base: splitCalc.basePrice, serviceCharge: splitCalc.serviceCharge, paystackFee: splitCalc.paystackFee, netCommission: splitCalc.netCommission, agentShare: splitCalc.agentShare, platformShare: splitCalc.platformShare, total: splitCalc.total, currency: "GHS" },
      hostelSnapshot: { name: hostelData.name || b.hostelName || null, address: hostelData.location || null, ownerId: hostelData.ownerId || b.ownerId || null, agentId: agentId || null },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const globalRef = db.collection("bookings").doc(bookingId);
    const userRef = db.collection("users").doc(uid).collection("bookings").doc(bookingId);
    const globalExists = (await globalRef.get()).exists;

    await Promise.all([
      userRef.set(paymentUpdate, { merge: true }),
      globalExists ? globalRef.update(paymentUpdate) : globalRef.set({ ...b, ...paymentUpdate, bookingId, userId: uid }, { merge: true }),
    ]);

    await createAuditLog(bookingId, "PAYMENT_INITIATED", uid, { reference: paystackRef });
    console.log(`[getPaymentPortal] SUCCESS bookingId=${bookingId} ref=${paystackRef}`);

    return { status: "SUCCESS", authorization_url: authUrl, access_code: accessCode, total_amount: splitCalc.total, reference: paystackRef };
  }
);

exports.verifyBooking = onCall({ secrets: [PAYSTACK_SECRET_KEY, RESEND_API_KEY], minInstances: 1 }, async (request) => {
  if (!request.auth) return { status: "ERROR", message: "Authentication required" };

  const { reference } = request.data;
  if (!reference) return { status: "ERROR", message: "Missing reference" };

  const db = admin.firestore();

  try {
    // reference may be a paystackRef (bookingId-timestamp) or a bare bookingId (legacy).
    // Strip the trailing timestamp suffix to get the bookingId.
    const bookingId = reference.replace(/-\d{10,}$/, "");
    const bookingRef = db.collection("bookings").doc(bookingId);
    const bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) return { status: "ERROR", message: "Booking not found" };

    const bData = bookingSnap.data();
    if (bData.status === "PAID") return { status: "PAID" };

    let paystackData = null;
    try {
      const resp = await axios.get(
        `https://api.paystack.co/transaction/verify/${reference}`,
        { headers: { Authorization: `Bearer ${getPaystackSecretKey()}` }, timeout: 5000 }
      );
      if (resp.data?.data?.status === "success") paystackData = resp.data.data;
    } catch (e) { console.warn("[verifyBooking] Paystack verify failed:", e.message); }

    if (paystackData) {
      try {
        await processSuccessfulPayment(reference, paystackData);
      } catch (procError) {
        console.error("[verifyBooking] processSuccessfulPayment threw — direct write:", procError.message);
        await bookingRef.set(
          { status: "PAID", paidAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() },
          { merge: true }
        );
        const uid = bData?.userId;
        if (uid) {
          await db.collection("users").doc(uid).collection("bookings").doc(bookingId).set(
            { status: "PAID", paidAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() },
            { merge: true }
          );
        }
      }
      return { status: "PAID" };
    }

    return { status: bData.status };
  } catch (error) {
    console.error("[verifyBooking] FAILURE:", error.stack);
    return { status: "ERROR", message: error.message };
  }
});

async function processSuccessfulPayment(reference, paystackData) {
  const db = admin.firestore();
  const bookingId = paystackData.metadata?.bookingId || reference;

  await db.runTransaction(async (transaction) => {
    const webhookRef = db.collection("processedWebhooks").doc(reference);
    const webhookSnap = await transaction.get(webhookRef);
    if (webhookSnap.exists) return;

    const bookingRef = db.collection("bookings").doc(bookingId);
    const bookingSnap = await transaction.get(bookingRef);
    if (!bookingSnap.exists) throw new Error("Booking not found");
    const bData = bookingSnap.data();
    if (bData.status === "PAID") return;

    const updatePayload = {
      status: "PAID",
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    transaction.update(bookingRef, updatePayload);

    if (bData.userId) {
      const userBookingRef = db.collection("users").doc(bData.userId).collection("bookings").doc(bookingId);
      transaction.set(userBookingRef, updatePayload, { merge: true });
    }

    if (bData.lockId) {
      let roomStateHostelId = null;
      let roomStateRoomId = null;
      if (bData.resourceId) {
        const sepIdx = bData.resourceId.indexOf("_");
        if (sepIdx > 0) {
          roomStateHostelId = bData.resourceId.substring(0, sepIdx);
          roomStateRoomId = bData.resourceId.substring(sepIdx + 1);
        }
      }
      // Fallback: use hostelId + roomId directly from the booking document
      if (!roomStateHostelId && bData.hostelId && bData.roomId) {
        roomStateHostelId = bData.hostelId;
        roomStateRoomId = bData.roomId;
      }
      if (roomStateHostelId && roomStateRoomId) {
        await updateRoomStateRegistry(transaction, roomStateHostelId, roomStateRoomId, bData.lockId, "PAID");
      }
    }

    const ownerId = bData.hostelSnapshot?.ownerId || bData.ownerId || null;
    const agentId = bData.hostelSnapshot?.agentId || bData.agentId || null;
    const base = bData.amounts?.base || 0;
    const serviceCharge = bData.amounts?.serviceCharge || (base * 0.1);
    const agentCommission =
      (typeof bData.amounts?.agentShare === "number" && bData.amounts.agentShare > 0)
        ? bData.amounts.agentShare
        : serviceCharge * 0.5;

    if (ownerId) {
      const ownerRef = db.collection("agents").doc(ownerId);
      transaction.set(ownerRef.collection("transactions").doc(bookingId), {
        amount: base, date: admin.firestore.FieldValue.serverTimestamp(), type: "credit",
        description: "Booking Payment: " + (bData.hostelSnapshot?.name || bData.hostelName || "Hostel"),
        bookingId, status: "completed", settlementMethod: "PAYSTACK_DIRECT",
      }, { merge: true });

      transaction.set(db.collection("users").doc(ownerId).collection("notifications").doc(`earn_${bookingId}`), {
        title: "Payment Received! 🏠",
        body: `GHS ${base.toFixed(2)} from ${bData.hostelSnapshot?.name || bData.hostelName || "a booking"} was sent to your bank/MoMo by Paystack.`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(), isRead: false, type: "EARNINGS", bookingId,
      });
    }

    if (agentId && agentId !== ownerId && agentCommission > 0) {
      const agentRef = db.collection("agents").doc(agentId);
      const agentSettled = bData.agentSettledViaPaystack === true;
      const agentSettlementMethod = agentSettled ? "PAYSTACK_DIRECT" : "PENDING_PAYOUT";

      transaction.set(agentRef.collection("transactions").doc(bookingId), {
        amount: agentCommission, date: admin.firestore.FieldValue.serverTimestamp(), type: "credit",
        description: "Commission: " + (bData.hostelSnapshot?.name || bData.hostelName || "Hostel"),
        bookingId, status: agentSettled ? "completed" : "pending", settlementMethod: agentSettlementMethod,
      }, { merge: true });

      if (agentSettled) {
        transaction.set(agentRef, { total_earnings: admin.firestore.FieldValue.increment(agentCommission), updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
        transaction.set(db.collection("users").doc(agentId).collection("notifications").doc(`earn_${bookingId}`), {
          title: "Commission Received! 💰",
          body: `GHS ${agentCommission.toFixed(2)} from ${bData.hostelSnapshot?.name || bData.hostelName || "a booking"} was sent to your MoMo/bank by Paystack.`,
          timestamp: admin.firestore.FieldValue.serverTimestamp(), isRead: false, type: "EARNINGS", bookingId,
        });
      } else {
        transaction.set(db.collection("users").doc(agentId).collection("notifications").doc(`earn_${bookingId}`), {
          title: "Commission Pending ⚠️",
          body: `GHS ${agentCommission.toFixed(2)} from ${bData.hostelSnapshot?.name || bData.hostelName || "a booking"} is waiting. Set up your payout account to receive it.`,
          timestamp: admin.firestore.FieldValue.serverTimestamp(), isRead: false, type: "EARNINGS_PENDING", bookingId,
        });
      }
    } else if (agentId && agentId === ownerId) {
      transaction.set(db.collection("users").doc(agentId).collection("notifications").doc(`book_${bookingId}`), {
        title: "Booking Paid! ✅",
        body: `A student has paid for a room at ${bData.hostelSnapshot?.name || bData.hostelName || "your hostel"}.`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(), isRead: false, type: "BOOKING_CONFIRMED", bookingId,
      });
    }

    transaction.set(webhookRef, { bookingId, processedAt: admin.firestore.FieldValue.serverTimestamp(), source: "payment_system" });

    if (bData.lockId) transaction.delete(db.collection("paymentLocks").doc(bData.lockId));
  });

  await createAuditLog(bookingId, "PAYMENT_SUCCESS_SYNC", "SYSTEM", { reference });

  // Send receipt emails to student and agent/owner (non-blocking)
  try {
    const resendKey = RESEND_API_KEY.value();
    const finalSnap = await admin.firestore().collection("bookings").doc(bookingId).get();
    if (finalSnap.exists) {
      await sendPaymentReceiptEmails(finalSnap.data(), bookingId, resendKey);
    }
  } catch (e) { console.warn("[processSuccessfulPayment] Email send failed:", e.message); }
}

exports.handlePaystackWebhook = onRequest({ secrets: [PAYSTACK_SECRET_KEY, RESEND_API_KEY] }, async (req, res) => {
  const secret = getPaystackSecretKey();
  const signature = req.headers["x-paystack-signature"];
  const rawBody = req.rawBody.toString();
  const hash = crypto.createHmac("sha512", secret).update(rawBody).digest("hex");

  if (hash !== signature) {
    console.error("Webhook: Invalid Signature");
    return res.status(401).send("Invalid Signature");
  }

  const event = req.body;
  if (event.event !== "charge.success") return res.status(200).send("Event Ignored");

  const { reference } = event.data;
  const db = admin.firestore();

  try {
    await processSuccessfulPayment(reference, event.data);
    return res.status(200).send("OK");
  } catch (error) {
    console.error("Webhook Error:", error.message);
    await db.collection("failedWebhooks").add({ payload: event, error: error.message, timestamp: admin.firestore.FieldValue.serverTimestamp() });
    return res.status(500).send("Webhook Processing Failed");
  }
});

exports.fixMissedCredits = onCall({ secrets: [PAYSTACK_SECRET_KEY] }, async (request) => {
  const data = request.data;
  const isSuperAdmin =
    request.auth?.token?.email === "anonyemichael6@gmail.com" ||
    request.auth?.token?.email === "admin@stayhub.com";
  if (!isSuperAdmin) throw new HttpsError("permission-denied", "Admins only");

  const { bookingId } = data || {};
  if (!bookingId) throw new HttpsError("invalid-argument", "bookingId required");

  const db = admin.firestore();
  const bookingSnap = await db.collection("bookings").doc(bookingId).get();
  if (!bookingSnap.exists) throw new HttpsError("not-found", "Booking not found");

  const b = bookingSnap.data();
  if (b.status !== "PAID") throw new HttpsError("failed-precondition", `Booking status is ${b.status}, not PAID`);

  const agentId = b.hostelSnapshot?.agentId || b.agentId || null;
  const ownerId = b.hostelSnapshot?.ownerId || b.ownerId || null;
  const results = [];

  if (agentId && agentId !== ownerId && b.agentSettledViaPaystack !== true) {
    const txRef = db.collection("agents").doc(agentId).collection("transactions").doc(bookingId);
    const txSnap = await txRef.get();
    if (txSnap.exists) {
      results.push({ party: "agent", status: "already_credited", agentId });
    } else {
      const base = b.amounts?.base || 0;
      const serviceCharge = b.amounts?.serviceCharge || (base * 0.1);
      const agentCommission =
        (typeof b.amounts?.agentShare === "number" && b.amounts.agentShare > 0)
          ? b.amounts.agentShare
          : (b.amounts?.commission ? b.amounts.commission * 0.5 : serviceCharge * 0.5);

      const agentRef = db.collection("agents").doc(agentId);
      const batch = db.batch();
      batch.set(agentRef, { wallet_balance: admin.firestore.FieldValue.increment(agentCommission), updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      batch.set(txRef, { amount: agentCommission, date: admin.firestore.FieldValue.serverTimestamp(), type: "credit", description: "Commission (retroactive): " + (b.hostelSnapshot?.name || b.hostelName || "Hostel"), bookingId, status: "completed", settlementMethod: "APP_WALLET" });
      batch.set(db.collection("users").doc(agentId).collection("notifications").doc(), { title: "Commission Credited 💰", body: `GHS ${agentCommission.toFixed(2)} from ${b.hostelSnapshot?.name || b.hostelName || "a booking"} has been added to your wallet.`, timestamp: admin.firestore.FieldValue.serverTimestamp(), isRead: false, type: "EARNINGS", bookingId });
      await batch.commit();
      results.push({ party: "agent", status: "credited", agentId, amount: agentCommission });
    }
  }

  if (ownerId && b.ownerSubaccountUsed !== true && b.paystackSplitUsed !== true && !b.subaccountUsed) {
    const txRef = db.collection("agents").doc(ownerId).collection("transactions").doc(bookingId);
    const txSnap = await txRef.get();
    if (txSnap.exists) {
      results.push({ party: "owner", status: "already_credited", ownerId });
    } else {
      const ownerAmount = b.amounts?.base || 0;
      const ownerRef = db.collection("agents").doc(ownerId);
      const batch = db.batch();
      batch.set(ownerRef, { wallet_balance: admin.firestore.FieldValue.increment(ownerAmount), updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      batch.set(txRef, { amount: ownerAmount, date: admin.firestore.FieldValue.serverTimestamp(), type: "credit", description: "Booking Payment (retroactive): " + (b.hostelSnapshot?.name || b.hostelName || "Hostel"), bookingId, status: "completed", settlementMethod: "APP_WALLET" });
      await batch.commit();
      results.push({ party: "owner", status: "credited", ownerId, amount: ownerAmount });
    }
  }

  if (results.length === 0) results.push({ status: "nothing_to_fix", note: "All parties already settled via Paystack subaccounts" });
  console.log(`[fixMissedCredits] ${bookingId}:`, results);
  return { success: true, bookingId, results };
});

exports.reconcilePayments = onSchedule(
  { schedule: "every 30 minutes", secrets: [PAYSTACK_SECRET_KEY, RESEND_API_KEY], timeoutSeconds: 300, memory: "512MiB" },
  async () => {
    console.log("[reconcilePayments] STARTing cleanup run...");
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);

    const expiredLocks = await db.collection("paymentLocks").where("expiresAt", "<", now).limit(100).get();
    const lockBatch = db.batch();
    expiredLocks.docs.forEach(doc => lockBatch.delete(doc.ref));
    await lockBatch.commit();
    console.log(`[reconcilePayments] Cleaned up ${expiredLocks.size} expired locks.`);

    const pendingBookings = await db.collection("bookings")
      .where("status", "==", "PAYMENT_PENDING")
      .where("createdAt", "<", admin.firestore.Timestamp.fromDate(oneHourAgo))
      .limit(50)
      .get();

    for (const doc of pendingBookings.docs) {
      const bookingId = doc.id;
      // Use the stored Paystack reference (may include timestamp suffix); fall back to bookingId for legacy records.
      const paystackRef = doc.data().paymentReference || bookingId;
      try {
        const paystackResponse = await axios.get(
          `https://api.paystack.co/transaction/verify/${paystackRef}`,
          { headers: { Authorization: `Bearer ${getPaystackSecretKey()}` } }
        );
        const tx = paystackResponse.data.data;
        if (tx.status === "success") {
          await processSuccessfulPayment(paystackRef, tx);
        } else if (tx.status === "abandoned" || tx.status === "failed") {
          const expiryUpdate = { status: "EXPIRED", updatedAt: admin.firestore.FieldValue.serverTimestamp() };
          await doc.ref.update(expiryUpdate);
          const userBookingRef = db.collection("users").doc(doc.data().userId).collection("bookings").doc(bookingId);
          await userBookingRef.update(expiryUpdate);
          await createAuditLog(bookingId, "PAYMENT_EXPIRED", "SYSTEM");
        }
      } catch (e) { console.error(`Reconciliation failed for ${bookingId}:`, e.message); }
    }

    console.log("[reconcilePayments] FINISHED cleanup run.");
  }
);

exports.ping = onRequest((req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.status(200).send("StayHub Payment Engine v3: ONLINE");
});

exports.onBookingCreatedTrigger = onDocumentCreated("bookings/{bookingId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const booking = snapshot.data();
  const agentId = booking.hostelSnapshot?.agentId;
  if (!agentId) return;

  try {
    const agentDoc = await admin.firestore().collection("agents").doc(agentId).get();
    const fcmToken = agentDoc.data()?.fcmToken;
    if (fcmToken) {
      await admin.messaging().send({
        notification: { title: "New Booking Request! 🏠", body: `A student is initiating a booking for ${booking.hostelName}.` },
        token: fcmToken,
        data: { click_action: "FLUTTER_NOTIFICATION_CLICK", bookingId: event.params.bookingId, type: "booking_request" },
      });
    }
  } catch (error) { console.error("Error sending booking notification:", error); }
});

exports.onBookingStatusUpdatedTrigger = onDocumentUpdated("bookings/{bookingId}", async (event) => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (before.status === after.status) return;

  const db = admin.firestore();

  if (after.status === "CANCELLED" || after.status === "EXPIRED") {
    try {
      await db.runTransaction(async (transaction) => {
        let hostelId = null;
        let roomId = null;
        if (after.resourceId) {
          const sepIdx = after.resourceId.indexOf("_");
          if (sepIdx > 0) {
            hostelId = after.resourceId.substring(0, sepIdx);
            roomId = after.resourceId.substring(sepIdx + 1);
          }
        }
        // Fallback: read hostelId/roomId directly from the booking
        if (!hostelId && after.hostelId && after.roomId) {
          hostelId = after.hostelId;
          roomId = after.roomId;
        }
        if (hostelId && roomId && after.lockId) {
          await updateRoomStateRegistry(transaction, hostelId, roomId, after.lockId, after.status);
        }
      });
    } catch (e) { console.error("Trigger RoomState Registry Update Failure:", e.message); }
  }

  try {
    const pushStatuses = ["CONFIRMED", "CANCELLED"];
    if (!pushStatuses.includes(after.status)) return;

    const userDoc = await db.collection("users").doc(after.userId).get();
    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken) return;

    let title = "Booking Update 📅";
    let body = `Your booking for ${after.hostelName} has been updated.`;
    if (after.status === "CONFIRMED") { title = "Booking Approved! 🎉"; body = `Your booking for ${after.hostelName} is confirmed. You can now proceed to payment.`; }
    else if (after.status === "CANCELLED") { title = "Booking Cancelled"; body = `Your booking for ${after.hostelName} has been cancelled.`; }

    await admin.messaging().send({
      notification: { title, body },
      token: fcmToken,
      data: { click_action: "FLUTTER_NOTIFICATION_CLICK", status: after.status, type: "booking_update" },
    });
  } catch (error) { console.error("Error sending status update notification:", error); }
});

exports.sendOtp = onRequest({ memory: "512MiB", timeoutSeconds: 60, secrets: [RESEND_API_KEY] }, async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") { res.set("Access-Control-Allow-Methods", "POST"); res.set("Access-Control-Allow-Headers", "Content-Type"); return res.status(204).send(""); }
  if (req.method !== "POST") return res.status(405).json({ error: "Method Not Allowed" });

  const { email, otp } = req.body;
  if (!email || !otp) return res.status(400).json({ error: "Missing email or otp" });

  try {
    const response = await axios.post("https://api.resend.com/emails", {
      from: "StayHub <noreply@stayhubgh.com>",
      to: [email],
      subject: "Your StayHub Verification Code",
      html: buildOtpEmailHtml(otp),
    }, { headers: { Authorization: `Bearer ${RESEND_API_KEY.value()}`, "Content-Type": "application/json" } });
    return res.status(200).json({ success: true, data: response.data });
  } catch (error) { return res.status(500).json({ error: error.message }); }
});

exports.sendPasswordResetLink = onRequest({ memory: "512MiB", timeoutSeconds: 60, secrets: [RESEND_API_KEY] }, async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") { res.set("Access-Control-Allow-Methods", "POST"); res.set("Access-Control-Allow-Headers", "Content-Type"); return res.status(204).send(""); }

  const { email } = req.body;
  try {
    const link = await admin.auth().generatePasswordResetLink(email, { url: "https://stayhubgh.com/reset-password", handleCodeInApp: true });
    await axios.post("https://api.resend.com/emails", {
      from: "StayHub <noreply@stayhubgh.com>",
      to: [email],
      subject: "Reset your StayHub Password",
      html: buildPasswordResetEmailHtml(link),
    }, { headers: { Authorization: `Bearer ${RESEND_API_KEY.value()}`, "Content-Type": "application/json" } });
    return res.status(200).json({ success: true });
  } catch (error) { return res.status(500).json({ error: error.message }); }
});

exports.getBanks = onRequest({ secrets: [PAYSTACK_SECRET_KEY] }, async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  try {
    const country = req.query.country || "ghana";
    const type = req.query.type;
    const params = { country, currency: "GHS", perPage: 100 };
    if (type) params.type = type;
    const response = await axios.get("https://api.paystack.co/bank", { params, headers: { Authorization: `Bearer ${getPaystackSecretKey()}` } });
    return res.status(200).json(response.data);
  } catch (e) { return res.status(500).json({ status: false, message: e.message }); }
});

exports.createSubAccount = onRequest({ secrets: [PAYSTACK_SECRET_KEY] }, async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  try {
    const response = await axios.post("https://api.paystack.co/subaccount", req.body, { headers: { Authorization: `Bearer ${getPaystackSecretKey()}` } });
    return res.status(200).json(response.data);
  } catch (e) { return res.status(500).json({ status: false, message: e.message }); }
});

exports.pingAuth = onCall({ secrets: [PAYSTACK_SECRET_KEY] }, async (request) => {
  return {
    isAuthenticated: !!request.auth,
    uid: request.auth?.uid || null,
    email: request.auth?.token?.email || null,
    serverTime: new Date().toISOString(),
    authTime: request.auth?.token?.auth_time || null,
    hasSecret: !!getPaystackSecretKey(),
  };
});

exports.createPaystackSubaccount = onCall(
  { secrets: [PAYSTACK_SECRET_KEY], timeoutSeconds: 60, memory: "256MiB" },
  async (request) => {
    const data = request.data;
    if (!request.auth) throw new HttpsError("unauthenticated", "Auth required.");

    const { business_name, bank_code, account_number, role } = data;
    if (!business_name || !bank_code || !account_number || !role) {
      throw new HttpsError("invalid-argument", "Missing required fields: business_name, bank_code, account_number, role.");
    }

    const sk = getPaystackSecretKey();
    if (!sk) throw new HttpsError("internal", "Paystack configuration missing.");

    const db = admin.firestore();
    const uid = request.auth.uid;
    const collectionName = role === "agent" ? "agents" : "users";

    // 1. Read the existing subaccount code BEFORE creating a new one so we can deactivate it.
    const existingDoc = await db.collection(collectionName).doc(uid).get();
    const oldSubaccountCode = existingDoc.exists
      ? (existingDoc.data().paystack_subaccount_code || null)
      : null;

    try {
      // 2. Create new Paystack subaccount.
      const response = await axios.post(
        "https://api.paystack.co/subaccount",
        {
          business_name: `${business_name} (StayHub ${role})`,
          settlement_bank: bank_code,
          account_number,
          percentage_charge: 0,
          description: `Automated StayHub subaccount for ${role}: ${business_name}`,
          primary_contact_email: request.auth.token.email,
        },
        { headers: { Authorization: `Bearer ${sk}`, "Content-Type": "application/json" } }
      );

      if (!response.data.status) {
        throw new Error(response.data.message || "Paystack subaccount creation failed.");
      }

      const subaccountCode = response.data.data.subaccount_code;
      const isVerified = response.data.data.is_verified === true;

      // 3. Save the new code to Firestore.
      await db.collection(collectionName).doc(uid).set({
        paystack_subaccount_code: subaccountCode,
        paystack_subaccount_verified: isVerified,
        bank_details: { business_name, bank_code, account_number, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
      }, { merge: true });

      // 4. For agents listing their own hostel (owner-type), propagate the new subaccount
      //    code to the ownerSubaccountCode field on all their hostels so payments split correctly.
      if (role === "agent") {
        try {
          const hostelsSnap = await db.collection("hostels").where("agentId", "==", uid).get();
          if (!hostelsSnap.empty) {
            const batch = db.batch();
            hostelsSnap.docs.forEach((doc) => {
              const hData = doc.data();
              // Only update owner-type listings — agent-type hostels resolve the
              // agent subaccount from the agent doc directly, no hostel field needed.
              if (hData.partnerType !== "agent") {
                batch.update(doc.ref, { ownerSubaccountCode: subaccountCode });
                console.log(`[createPaystackSubaccount] Updated ownerSubaccountCode on hostel ${doc.id}`);
              }
            });
            await batch.commit();
          }
        } catch (hostelErr) {
          // Non-fatal — log and continue. The agent profile is already saved.
          console.error("[createPaystackSubaccount] Failed to update hostel subaccountCodes:", hostelErr.message);
        }
      }

      // 5. Deactivate the old subaccount on Paystack to prevent orphaned accounts.
      if (oldSubaccountCode && oldSubaccountCode !== subaccountCode) {
        try {
          await axios.put(
            `https://api.paystack.co/subaccount/${oldSubaccountCode}`,
            { active: false },
            { headers: { Authorization: `Bearer ${sk}`, "Content-Type": "application/json" } }
          );
          console.log(`[createPaystackSubaccount] Deactivated old subaccount ${oldSubaccountCode} for uid=${uid}`);
        } catch (deactivateErr) {
          // Non-fatal — old code is no longer stored so it won't be used.
          console.warn("[createPaystackSubaccount] Could not deactivate old subaccount:", deactivateErr.message);
        }
      }

      console.log(`[createPaystackSubaccount] uid=${uid} role=${role} new=${subaccountCode} old=${oldSubaccountCode || "none"} verified=${isVerified}`);
      return {
        status: "success",
        subaccount_code: subaccountCode,
        is_verified: isVerified,
        message: isVerified
          ? "Payment account linked and verified."
          : "Payment account linked. Paystack will verify your account details within 24 hours.",
      };

    } catch (e) {
      console.error("Subaccount Creation Error:", e.response?.data || e.message);
      throw new HttpsError("internal", `Paystack Error: ${e.response?.data?.message || e.message}`);
    }
  }
);

// ── createOwnerSubaccount ──────────────────────────────────────────────────────
// Creates a Paystack subaccount for a hostel OWNER on behalf of an agent.
// Unlike createPaystackSubaccount, this does NOT write anything to Firestore —
// it simply creates the Paystack subaccount and returns the code so it can be
// stored directly on the hostel document. This prevents the agent's own payment
// profile from being corrupted when they add a hostel with third-party bank details.
exports.createOwnerSubaccount = onCall(
  { secrets: [PAYSTACK_SECRET_KEY], timeoutSeconds: 60, memory: "256MiB" },
  async (request) => {
    const data = request.data;
    if (!request.auth) throw new HttpsError("unauthenticated", "Auth required.");

    const { business_name, bank_code, account_number } = data;
    if (!business_name || !bank_code || !account_number) {
      throw new HttpsError(
        "invalid-argument",
        "Missing required fields: business_name, bank_code, account_number."
      );
    }

    const sk = getPaystackSecretKey();
    if (!sk) throw new HttpsError("internal", "Paystack configuration missing.");

    try {
      const response = await axios.post(
        "https://api.paystack.co/subaccount",
        {
          business_name: `${business_name} (StayHub Owner)`,
          settlement_bank: bank_code,
          account_number,
          percentage_charge: 0,
          description: `StayHub owner payout account for ${business_name}`,
          primary_contact_email: request.auth.token.email || "owner@stayhub.app",
        },
        { headers: { Authorization: `Bearer ${sk}`, "Content-Type": "application/json" } }
      );

      if (!response.data.status) {
        throw new Error(response.data.message || "Paystack subaccount creation failed.");
      }

      const subaccountCode = response.data.data.subaccount_code;
      const isVerified = response.data.data.is_verified === true;

      console.log(`[createOwnerSubaccount] uid=${request.auth.uid} subaccount=${subaccountCode} verified=${isVerified}`);
      return {
        status: "success",
        subaccount_code: subaccountCode,
        is_verified: isVerified,
        message: isVerified
          ? "Owner payout account linked and verified."
          : "Owner payout account linked. Paystack will verify within 24 hours.",
      };
    } catch (e) {
      console.error("[createOwnerSubaccount] Error:", e.response?.data || e.message);
      throw new HttpsError("internal", `Paystack Error: ${e.response?.data?.message || e.message}`);
    }
  }
);
