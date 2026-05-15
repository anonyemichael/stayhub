/**
 * STAYHUB PRODUCTION PAYMENT ENGINE v3.2
 * Updated: 2026-05-15 (Standardized Auth & Index fix)
 * 
 * Architecture:
 * 1. prepareBooking (Callable): Creates atomic lock and validates availability.
 * 2. getPaymentPortal (Callable): Snapshots hostel data and initializes Paystack.
 * 3. handlePaystackWebhook (HTTPS): Atomic verification and state transition.
 * 4. reconcilePayments (Scheduled): Background cleanup for pending transactions.
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { defineSecret } = require("firebase-functions/params");
const { v4: uuidv4 } = require("uuid");
const axios = require("axios");
const crypto = require("crypto");

admin.initializeApp();

// --- SECRETS & CONFIG ---
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

/**
 * Creates a scalable audit log entry.
 */
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

/**
 * Centralized date parsing for Firestore Timestamps, ISO strings, and numeric values.
 */
function getMs(val) {
  if (!val) return NaN;
  if (typeof val.toMillis === "function") return val.toMillis();
  if (typeof val.toDate === "function") return val.toDate().getTime();
  if (val._seconds) return val._seconds * 1000;
  if (typeof val === "number") return val;
  const ms = new Date(val).getTime();
  return isNaN(ms) ? NaN : ms;
}

/**
 * Validates date overlap: (A.start < B.end AND A.end > B.start)
 */
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

/**
 * Updates the RoomState registry for a confirmed or cancelled booking.
 */
async function updateRoomStateRegistry(transaction, hostelId, roomId, lockId, status) {
  const db = admin.firestore();
  const roomStateRef = db.collection("hostelRoomStates").doc(`${hostelId}_${roomId}`);
  const roomStateSnap = await transaction.get(roomStateRef);
  
  if (roomStateSnap.exists) {
    const data = roomStateSnap.data();
    const now = Date.now();
    const reservations = (data.reservations || []).map(r => {
      if (r.id === lockId) {
        return { ...r, status: status, expiresAt: null }; // Clear expiry for PAID/CANCELLED
      }
      return r;
    });
    
    // Filter out old or expired entries to keep document small
    const cleanedReservations = reservations.filter(r => {
      if (r.status === "CANCELLED" || r.status === "EXPIRED") return false;
      
      // Remove PENDING locks that are expired
      if (r.status === "PENDING") {
        const expiryMs = getMs(r.expiresAt);
        if (isNaN(expiryMs) || expiryMs < now) return false;
      }

      // If PAID, check if checkOut is in the past (allow 24h grace)
      if (r.status === "PAID" || r.status === "CONFIRMED") {
        const checkOutMs = getMs(r.checkOut);
        if (!isNaN(checkOutMs) && checkOutMs < now - (24 * 60 * 60 * 1000)) return false;
      }
      
      return true;
    });

    transaction.update(roomStateRef, { 
      reservations: cleanedReservations,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });
  }
}

// --- CORE CALLABLES ---

/**
 * STEP 1: PREPARE BOOKING (Callable)
 * - Checks availability server-side.
 * - Creates an atomic payment lock (15m TTL).
 * - Implements strict date overlap logic.
 */
/**
 * STEP 1: PREPARE BOOKING (Callable)
 * - Checks availability server-side.
 * - Creates an atomic payment lock (15m TTL).
 * - Implements strict date overlap logic.
 */
exports.prepareBooking = functions.https.onCall(async (data, context) => {
  const stepLogs = [];
  const logStep = (step, info = {}) => {
    const msg = `[prepareBooking][Step: ${step}]`;
    console.log(msg, JSON.stringify(info));
    stepLogs.push({ step, timestamp: Date.now(), ...info });
  };

  try {
    const { hostelId, roomId, checkIn, checkOut, idempotencyKey } = data || {};
    const userId = context.auth?.uid;

    logStep("1_PAYLOAD_RECEIVED", { userId, hostelId, roomId, checkIn, checkOut, idempotencyKey });

    if (!userId) {
      console.error("prepareBooking: UNAUTHENTICATED access attempt", {
        hasAuth: !!context.auth,
        token: context.auth ? "EXISTS" : "MISSING",
        uid: context.auth?.uid
      });
      throw new functions.https.HttpsError("unauthenticated", "Authentication required. Server did not receive a valid user identity.");
    }

    if (!hostelId || !roomId || !checkIn || !checkOut) {
      logStep("ERROR_MISSING_FIELDS", { hostelId, roomId, checkIn, checkOut });
      return { 
        success: false, 
        status: "ERROR", 
        errorCode: "INVALID_ARGUMENTS", 
        message: "Missing required booking details (hostel, room, or dates)." 
      };
    }

    const db = admin.firestore();
    const lockId = idempotencyKey || `LOCK_${userId}_${hostelId}_${roomId.replace(/\s+/g, '_')}_${Date.now()}`;
    
    logStep("2_STARTING_TRANSACTION", { lockId });

    return await db.runTransaction(async (transaction) => {
      // 3. Fetch Hostel Document
      logStep("3_FETCHING_HOSTEL", { hostelId });
      const hostelSnap = await transaction.get(db.collection("hostels").doc(hostelId));
      if (!hostelSnap.exists) {
        logStep("ERROR_HOSTEL_NOT_FOUND", { hostelId });
        return { 
          success: false, 
          status: "ERROR", 
          errorCode: "HOSTEL_NOT_FOUND", 
          message: `Hostel not found: ${hostelId}` 
        };
      }
      const hostelData = hostelSnap.data();

      // 4. Determine Room Capacity (Legacy Aware)
      logStep("4_RESOLVING_ROOM_CONFIG", { roomId });
      let roomLimit = 1;
      let resolvedRoomName = roomId;
      
      const rooms = hostelData.rooms || [];
      // Look for room by ID or Type
      const roomConfig = rooms.find(r => (r.id === roomId || r.type === roomId));

      if (roomConfig) {
        roomLimit = parseInt(roomConfig.quantity || roomConfig.available || 1);
        resolvedRoomName = roomConfig.type || roomConfig.name || roomId;
        logStep("ROOM_CONFIG_FOUND", { roomLimit, resolvedRoomName });
      } else if (roomId === "legacy" || rooms.length === 0) {
        // Fallback to top-level capacity for legacy hostels or if room not found
        roomLimit = parseInt(hostelData.capacity || 1);
        resolvedRoomName = "Standard Room (Legacy)";
        logStep("ROOM_CONFIG_LEGACY_FALLBACK", { roomLimit, resolvedRoomName });
      } else {
        logStep("ERROR_ROOM_NOT_FOUND", { roomId, availableRooms: rooms.map(r => r.type) });
        return { 
          success: false, 
          status: "ERROR", 
          errorCode: "ROOM_NOT_FOUND", 
          message: `The selected room type "${roomId}" is no longer available in this hostel.` 
        };
      }

      // 5. Fetch Room State Registry
      const roomStateId = `${hostelId}_${roomId}`;
      const roomStateRef = db.collection("hostelRoomStates").doc(roomStateId);
      logStep("5_FETCHING_ROOM_STATE", { roomStateId });
      const roomStateSnap = await transaction.get(roomStateRef);
      
      const reservations = roomStateSnap.exists ? (roomStateSnap.data().reservations || []) : [];
      const nowMs = Date.now();
      
      // 6. Filter Active Reservations (Paid or within 15m TTL)
      logStep("6_FILTERING_RESERVATIONS", { totalInRegistry: reservations.length });
      const activeReservations = reservations.filter(r => {
        if (r.status === "PAID" || r.status === "CONFIRMED" || r.status === "CHECKED_IN") return true;
        
        const expiryMs = getMs(r.expiresAt);
        if (!isNaN(expiryMs) && expiryMs > nowMs) return true;
        return false;
      });

      // 7. Check for Overlap/Capacity
      logStep("7_CHECKING_OVERLAP", { activeCount: activeReservations.length, roomLimit });
      const overlapping = activeReservations.filter(r => 
        isOverlapping(checkIn, checkOut, r.checkIn, r.checkOut)
      );

      if (overlapping.length >= roomLimit) {
        // Check for idempotency (if the user is retrying their own PENDING lock)
        const existingMyLock = overlapping.find(r => r.userId === userId && r.status === "PENDING");
        if (existingMyLock) {
          logStep("IDEMPOTENT_RESUME", { lockId: existingMyLock.id });
          return { 
            success: true, 
            status: "IDEMPOTENT_RESUME", 
            lockId: existingMyLock.id,
            bookingId: existingMyLock.id // reference for client
          };
        }

        logStep("ERROR_CAPACITY_EXCEEDED", { overlappingCount: overlapping.length, roomLimit });
        return { 
          success: false, 
          status: "ERROR", 
          errorCode: "ROOM_FULL", 
          message: `The "${resolvedRoomName}" is fully booked for these dates.` 
        };
      }

      // 8. Create Lock Payload
      logStep("8_CREATING_LOCK", { lockId });
      const expiresAt = admin.firestore.Timestamp.fromMillis(nowMs + 15 * 60 * 1000);
      const lockData = {
        id: lockId,
        userId,
        hostelId,
        roomId,
        roomName: resolvedRoomName,
        checkIn,
        checkOut,
        status: "PENDING",
        expiresAt,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // 9. Commit Updates
      logStep("9_COMMITTING_UPDATES");
      
      // A. Update Registry
      const newReservationEntry = {
        id: lockId,
        userId,
        checkIn,
        checkOut,
        status: "PENDING",
        expiresAt: expiresAt.toDate().toISOString()
      };
      
      transaction.set(roomStateRef, { 
        reservations: [...activeReservations, newReservationEntry],
        hostelId,
        roomId,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

      // B. Create Lock Document
      const lockRef = db.collection("paymentLocks").doc(lockId);
      transaction.set(lockRef, lockData);

      logStep("TRANSACTION_SUCCESS", { lockId });
      return { 
        success: true, 
        status: "SUCCESS", 
        lockId,
        bookingId: lockId
      };
    });
  } catch (error) {
    console.error("[prepareBooking] CRITICAL EXCEPTION:", error);
    return { 
      success: false, 
      status: "ERROR", 
      errorCode: "INTERNAL_ERROR", 
      message: "Booking system failure. Please contact support.",
      debug: error.message,
      trace: stepLogs
    };
  }
});


/**
 * STEP 2: GET PAYMENT PORTAL (Callable)
 * - Snapshots hostel data to prevent price tampering.
 * - Initializes Paystack transaction.
 * - Creates booking doc in INITIATED state.
 */
exports.getPaymentPortal = functions.runWith({ secrets: [PAYSTACK_SECRET_KEY] }).https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }

  const { lockId, deviceInfo, studentSex } = data;
  const userId = context.auth?.uid;
  if (!userId) {
    console.error("getPaymentPortal: UNAUTHENTICATED access attempt", {
      hasContext: !!context,
      hasAuth: !!context.auth,
      token: context.auth ? "EXISTS" : "MISSING"
    });
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in. (Server did not receive auth context)');
  }

  console.log(`[getPaymentPortal] Request for Lock: ${lockId}, User: ${userId}`);

  if (!lockId) {
    throw new functions.https.HttpsError("invalid-argument", "Missing lockId");
  }

  const db = admin.firestore();
  
  try {
    // 1. Validate Lock
    const lockSnap = await db.collection("paymentLocks").doc(lockId).get();
    if (!lockSnap.exists) {
      console.warn(`[getPaymentPortal] Lock not found in Firestore: ${lockId}`);
      return { status: "ERROR", message: "Payment session expired or invalid. Please try booking again." };
    }
    const lockData = lockSnap.data();
    if (lockData.userId !== userId) {
      console.warn(`[getPaymentPortal] Ownership mismatch: Lock=${lockData.userId}, Current=${userId}`);
      return { status: "ERROR", message: "Security Error: Session ownership mismatch." };
    }

    // 2. Snapshot Hostel Data (Server-side price verification)
    const hostelId = lockData.hostelId;
    const roomId = lockData.roomId;
    
    if (!hostelId || !roomId) {
      console.error("[getPaymentPortal] Missing hostelId or roomId in lock:", lockData);
      return { status: "ERROR", message: "Invalid payment session data." };
    }

    const hostelSnap = await db.collection("hostels").doc(hostelId).get();
    if (!hostelSnap.exists) {
      console.error("[getPaymentPortal] Hostel not found:", hostelId);
      return { status: "ERROR", message: "Hostel details could not be retrieved." };
    }
    const hostelData = hostelSnap.data();
    
    // Find the specific room to get its price
    let room = (hostelData.rooms || []).find(r => r.id === roomId || r.type === roomId || r.name === roomId);
    
    let basePrice;
    let roomType;
    
    if (!room && (roomId === "legacy" || !hostelData.rooms)) {
      basePrice = parseFloat(hostelData.price || 0);
      roomType = "Standard Room";
    } else if (!room) {
      console.error("[getPaymentPortal] Room not found in hostel document:", roomId);
      return { status: "ERROR", message: "Selected room type is no longer available." };
    } else {
      basePrice = parseFloat(room.price);
      roomType = room.type;
    }

    // Calculation: Base Price + 10% Platform Commission
    const platformCommission = basePrice * 0.10;
    const totalPrice = basePrice + platformCommission;
    
    console.log(`[getPaymentPortal] Pricing: Base=${basePrice}, Total=${totalPrice}`);

    // 3. Initialize Paystack
    const reference = `SH_${uuidv4().split("-")[0].toUpperCase()}_${Date.now()}`;
    const payload = {
      email: context.auth.token.email || `user_${userId}@stayhub.com`,
      amount: Math.round(totalPrice * 100), // Amount in Pesewas
      reference,
      currency: "GHS",
      callback_url: "https://stayhubgh.com/app/#/payment-callback",
      metadata: {
        lockId,
        userId,
        bookingId: reference,
      },
    };

    // Use Subaccount for Split Payments if configured
    const subaccount = hostelData.ownerSubaccountCode || hostelData.owner_subaccount_code || hostelData.subaccount_code;
    if (subaccount) {
      payload.subaccount = subaccount;
      payload.transaction_charge = Math.round(platformCommission * 100);
      payload.bearer = "account";
    }

    const secretKey = getPaystackSecretKey();
    if (!secretKey) {
      throw new Error("Paystack configuration is missing on server.");
    }

    const paystackResponse = await axios.post(
      "https://api.paystack.co/transaction/initialize",
      payload,
      {
        headers: {
          Authorization: `Bearer ${secretKey}`,
          "Content-Type": "application/json",
        },
      }
    );

    if (!paystackResponse.data.status) {
      console.error("[getPaymentPortal] Paystack Error:", paystackResponse.data.message);
      return { status: "ERROR", message: paystackResponse.data.message || "Paystack initialization failed" };
    }

    // 4. Create Initialized Booking
    const bookingData = {
      bookingId: reference,
      userId,
      hostelId,
      roomId,
      hostelName: hostelData.name,
      roomType: roomType,
      checkIn: lockData.checkIn,
      checkOut: lockData.checkOut,
      studentSex: studentSex || "not_specified",
      status: "PAYMENT_PENDING",
      resourceId: `${hostelId}_${roomId}`,
      price: totalPrice,
      amounts: {
        base: basePrice,
        commission: platformCommission,
        total: totalPrice,
        currency: "GHS",
      },
      hostelSnapshot: {
        name: hostelData.name,
        address: hostelData.location,
        ownerId: hostelData.ownerId,
        agentId: hostelData.agentId,
      },
      sessionData: {
        device: deviceInfo || "unknown",
        ip: context.rawRequest?.ip || "unknown",
        userAgent: context.rawRequest?.headers ? context.rawRequest.headers["user-agent"] : "unknown",
      },
      paymentReference: reference,
      accessCode: paystackResponse.data.data.access_code,
      authorizationUrl: paystackResponse.data.data.authorization_url,
      subaccountUsed: subaccount || null,
      lockId,
      agentId: hostelData.agentId || null,
      ownerId: hostelData.ownerId || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const globalBookingRef = db.collection("bookings").doc(reference);
    const userBookingRef = db.collection("users").doc(userId).collection("bookings").doc(reference);

    await Promise.all([
      globalBookingRef.set(bookingData),
      userBookingRef.set(bookingData)
    ]);

    await createAuditLog(reference, "PAYMENT_INITIATED", userId, { reference });

    console.log("[getPaymentPortal] SUCCESS: Booking Initiated:", reference);
    return {
      status: "SUCCESS",
      authorization_url: paystackResponse.data.data.authorization_url,
      access_code: paystackResponse.data.data.access_code,
      total_amount: totalPrice,
      reference,
    };

  } catch (error) {
    console.error("[getPaymentPortal] CRITICAL FAILURE:", error);
    return { 
      status: "ERROR", 
      message: error.response?.data?.message || error.message || "Internal system error",
      details: error.response?.data
    };
  }
});

/**
 * STEP 2.5: VERIFY BOOKING (Callable)
 * - Checks status in Firestore.
 * - If PENDING, verifies with Paystack directly.
 * - This handles cases where the webhook is delayed.
 */
exports.verifyBooking = functions.runWith({ secrets: [PAYSTACK_SECRET_KEY] }).https.onCall(async (data, context) => {
  if (!context.auth) {
    return { status: "ERROR", message: "Authentication required" };
  }

  const { reference } = data;
  if (!reference) {
    return { status: "ERROR", message: "Missing reference" };
  }

  const db = admin.firestore();
  
  try {
    const bookingRef = db.collection("bookings").doc(reference);
    const bookingSnap = await bookingRef.get();

    if (!bookingSnap.exists) {
      return { status: "ERROR", message: "Booking not found" };
    }

    const bData = bookingSnap.data();
    if (bData.status === "PAID") return { status: "PAID" };

    // If still pending, check Paystack
    const paystackResponse = await axios.get(
      `https://api.paystack.co/transaction/verify/${reference}`,
      {
        headers: {
          Authorization: `Bearer ${getPaystackSecretKey()}`,
        },
      }
    );

    if (paystackResponse.data.status && paystackResponse.data.data.status === "success") {
      await processSuccessfulPayment(reference, paystackResponse.data.data);
      return { status: "PAID" };
    }

    return { status: bData.status };
  } catch (error) {
    console.error("[verifyBooking] FAILURE:", error.stack);
    return { status: "ERROR", message: error.message };
  }
});

/**
 * Atomic processing for successful payments.
 * Shared between Webhook and Manual Verification.
 */
async function processSuccessfulPayment(reference, paystackData) {
  const db = admin.firestore();
  const bookingId = paystackData.metadata?.bookingId || reference;

  await db.runTransaction(async (transaction) => {
    // 1. Idempotency Check
    const webhookRef = db.collection("processedWebhooks").doc(reference);
    const webhookSnap = await transaction.get(webhookRef);
    if (webhookSnap.exists) return;

    // 2. Fetch Booking
    const bookingRef = db.collection("bookings").doc(bookingId);
    const bookingSnap = await transaction.get(bookingRef);
    if (!bookingSnap.exists) throw new Error("Booking not found");
    const bData = bookingSnap.data();

    if (bData.status === "PAID") return;

    // 3. Atomic Updates (Dual-Write)
    const updatePayload = {
      status: "PAID",
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    transaction.update(bookingRef, updatePayload);
    
    const userBookingRef = db.collection("users").doc(bData.userId).collection("bookings").doc(bookingId);
    transaction.update(userBookingRef, updatePayload);

    // 4. Update RoomState Registry
    if (bData.lockId) {
      const [hostelId, roomId] = bData.resourceId.split("_");
      await updateRoomStateRegistry(transaction, hostelId, roomId, bData.lockId, "PAID");
    }

    // 5. Wallet Settlements (Pending Balance)
    const ownerId = bData.hostelSnapshot.ownerId;
    if (ownerId && !bData.subaccountUsed) {
      // Only increment internal wallet if Paystack didn't automatically split it!
      // Sync to Agent/Owner UI (Single source of truth: agents collection)
      const ownerRef = db.collection("agents").doc(ownerId);
      transaction.set(ownerRef, {
        wallet_balance: admin.firestore.FieldValue.increment(bData.amounts.base),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      transaction.set(ownerRef.collection("transactions").doc(bookingId), {
        amount: bData.amounts.base,
        date: admin.firestore.FieldValue.serverTimestamp(),
        type: "credit",
        description: "Booking Payment: " + (bData.hostelSnapshot.name || "Hostel"),
        bookingId: bookingId,
        status: "completed"
      });
    }

    // 5b. Agent Commission (if applicable)
    const agentId = bData.hostelSnapshot.agentId;
    if (agentId && agentId !== ownerId) {
      // Agent gets 50% of the 10% platform commission (which is 5% of base price)
      const agentCommission = bData.amounts.commission ? bData.amounts.commission * 0.5 : 0;
      if (agentCommission > 0) {
        // Sync to Agent UI (Single source of truth: agents collection)
        const agentRef = db.collection("agents").doc(agentId);
        transaction.set(agentRef, {
          wallet_balance: admin.firestore.FieldValue.increment(agentCommission),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        transaction.set(agentRef.collection("transactions").doc(bookingId), {
          amount: agentCommission,
          date: admin.firestore.FieldValue.serverTimestamp(),
          type: "credit",
          description: "Commission: " + (bData.hostelSnapshot.name || "Hostel"),
          bookingId: bookingId,
          status: "completed"
        });

        // Notify Agent
        transaction.set(db.collection("users").doc(agentId).collection("notifications").doc(), {
          title: "Commission Earned! 💰",
          body: `You earned GHS ${agentCommission.toFixed(2)} from ${bData.hostelSnapshot.name}.`,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
          type: "EARNINGS",
          bookingId: bookingId,
        });
      }
    }

    // 5c. Notifications for both parties
    if (agentId) {
      transaction.set(db.collection("users").doc(agentId).collection("notifications").doc(), {
        title: "New Booking Confirmed! ✅",
        body: `A student has paid for a room at ${bData.hostelSnapshot.name}.`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
        type: "BOOKING_CONFIRMED",
        bookingId: bookingId,
      });
    }

    if (ownerId && ownerId !== agentId) {
      transaction.set(db.collection("users").doc(ownerId).collection("notifications").doc(), {
        title: "Payment Received! 🏠",
        body: `Booking confirmed for ${bData.hostelSnapshot.name}. Funds settled ${bData.subaccountUsed ? "directly to your bank" : "to your app wallet"}.`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
        type: "EARNINGS",
        bookingId: bookingId,
      });
    }

    // 6. Mark webhook as processed
    transaction.set(webhookRef, {
      bookingId,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      source: "payment_system",
    });

    // 7. Cleanup Lock
    if (bData.lockId) {
      transaction.delete(db.collection("paymentLocks").doc(bData.lockId));
    }
  });

  await createAuditLog(bookingId, "PAYMENT_SUCCESS_SYNC", "SYSTEM", { reference });
}

/**
 * STEP 3: PAYSTACK WEBHOOK (HTTPS)
 * - Validates signature.
 * - Atomic state transition to PAID.
 * - Settle to pending_balance.
 */
exports.handlePaystackWebhook = functions.runWith({ secrets: [PAYSTACK_SECRET_KEY] }).https.onRequest(async (req, res) => {
  const secret = getPaystackSecretKey();
  const signature = req.headers["x-paystack-signature"];
  
  const rawBody = req.rawBody.toString();
  const hash = crypto.createHmac("sha512", secret).update(rawBody).digest("hex");
  
  if (hash !== signature) {
    console.error("Webhook: Invalid Signature");
    return res.status(401).send("Invalid Signature");
  }

  const event = req.body;
  if (event.event !== "charge.success") {
    return res.status(200).send("Event Ignored");
  }

  const { reference, metadata, amount: paidAmountInPesewas } = event.data;
  const bookingId = metadata?.bookingId || reference;
  const db = admin.firestore();

  try {
    await processSuccessfulPayment(reference, event.data);
    return res.status(200).send("OK");
  } catch (error) {
    console.error("Webhook Error:", error.message);
    // Dead Letter Storage
    await db.collection("failedWebhooks").add({
      payload: event,
      error: error.message,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    return res.status(500).send("Webhook Processing Failed");
  }
});

/**
 * STEP 4: RECONCILIATION (Scheduled)
 * - Runs every 30 mins.
 * - Cleans up expired locks.
 * - Verifies PENDING bookings > 1 hour old.
 */
exports.reconcilePayments = functions.runWith({ 
  secrets: [PAYSTACK_SECRET_KEY],
  timeoutSeconds: 300,
  memory: "512MB"
}).pubsub.schedule("every 30 minutes").onRun(async (context) => {
  console.log("[reconcilePayments] STARTing cleanup run...");
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);

  // 1. Cleanup Expired Locks
  const expiredLocks = await db.collection("paymentLocks")
    .where("expiresAt", "<", now)
    .limit(100)
    .get();

  const lockBatch = db.batch();
  expiredLocks.docs.forEach(doc => lockBatch.delete(doc.ref));
  await lockBatch.commit();
  console.log(`[reconcilePayments] Cleaned up ${expiredLocks.size} expired locks.`);

  // 2. Reconcile Pending Bookings
  const pendingBookings = await db.collection("bookings")
    .where("status", "==", "PAYMENT_PENDING")
    .where("createdAt", "<", admin.firestore.Timestamp.fromDate(oneHourAgo))
    .limit(50)
    .get();

  for (const doc of pendingBookings.docs) {
    const reference = doc.id;
    try {
      const paystackResponse = await axios.get(
        `https://api.paystack.co/transaction/verify/${reference}`,
        {
          headers: { Authorization: `Bearer ${getPaystackSecretKey()}` },
        }
      );

      const tx = paystackResponse.data.data;
      if (tx.status === "success") {
        await processSuccessfulPayment(reference, tx);
      } else if (tx.status === "abandoned" || tx.status === "failed") {
        // Mark as expired/failed after 1 hour if not paid
        const expiryUpdate = {
          status: "EXPIRED",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        await doc.ref.update(expiryUpdate);
        
        const userBookingRef = db.collection("users").doc(doc.data().userId).collection("bookings").doc(reference);
        await userBookingRef.update(expiryUpdate);

        await createAuditLog(reference, "PAYMENT_EXPIRED", "SYSTEM");
      }
    } catch (e) {
      console.error(`Reconciliation failed for ${reference}:`, e.message);
    }
  }

  console.log("[reconcilePayments] FINISHED cleanup run.");
  return null;
});

// --- LEGACY / UTILITY WRAPPERS ---

exports.ping = functions.https.onRequest((req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.status(200).send("StayHub Payment Engine v3: ONLINE");
});

// --- PUSH NOTIFICATIONS & TRIGGERS ---

exports.onBookingCreatedTrigger = functions.firestore
  .document('bookings/{bookingId}')
  .onCreate(async (snapshot, context) => {
    const booking = snapshot.data();
    const agentId = booking.hostelSnapshot?.agentId;
    if (!agentId) return;

    try {
      const agentDoc = await admin.firestore().collection('agents').doc(agentId).get();
      const fcmToken = agentDoc.data()?.fcmToken;

      if (fcmToken) {
        const message = {
          notification: {
            title: 'New Booking Request! 🏠',
            body: `A student is initiating a booking for ${booking.hostelName}.`,
          },
          token: fcmToken,
          data: {
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            bookingId: context.params.bookingId,
            type: 'booking_request'
          }
        };
        await admin.messaging().send(message);
      }
    } catch (error) {
      console.error("Error sending booking notification:", error);
    }
  });

exports.onBookingStatusUpdatedTrigger = functions.firestore
  .document('bookings/{bookingId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status === after.status) return;

    const db = admin.firestore();

    // 1. Cleanup RoomState if status changes to CANCELLED or EXPIRED
    if (after.status === "CANCELLED" || after.status === "EXPIRED") {
      try {
        await db.runTransaction(async (transaction) => {
          const [hostelId, roomId] = (after.resourceId || "").split("_");
          if (hostelId && roomId) {
            await updateRoomStateRegistry(transaction, hostelId, roomId, after.lockId, after.status);
          }
        });
      } catch (e) {
        console.error("Trigger RoomState Registry Update Failure:", e.message);
      }
    }

    try {
      const userDoc = await db.collection('users').doc(after.userId).get();
      const fcmToken = userDoc.data()?.fcmToken;

      if (fcmToken) {
        let title = 'Booking Update 📅';
        let body = `Your booking for ${after.hostelName} is now ${after.status}.`;

        if (after.status === 'PAID') {
          body = `Payment confirmed for ${after.hostelName}! Your stay is secured.`;
        }

        const message = {
          notification: { title, body },
          token: fcmToken,
          data: {
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            status: after.status,
            type: 'booking_update'
          }
        };
        await admin.messaging().send(message);
      }
    } catch (error) {
      console.error("Error sending status update notification:", error);
    }
  });

// --- AUTH & EMAIL UTILITIES (RESEND) ---

exports.sendOtp = functions.runWith({ 
  memory: '512MB', 
  timeoutSeconds: 60,
  secrets: [RESEND_API_KEY] 
}).https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    return res.status(204).send('');
  }
  if (req.method !== "POST") return res.status(405).json({ error: "Method Not Allowed" });

  const { email, otp } = req.body;
  if (!email || !otp) return res.status(400).json({ error: "Missing email or otp" });

  try {
    const response = await axios.post('https://api.resend.com/emails', {
      from: 'StayHub Support <support@stayhubgh.com>',
      to: [email],
      subject: 'Your StayHub Verification Code',
      html: `<div style="font-family: sans-serif; padding: 20px;"><h2 style="color: #2E2AB7;">StayHub Verification</h2><p>Your code is: <strong>${otp}</strong></p></div>`
    }, {
      headers: { 'Authorization': `Bearer ${RESEND_API_KEY.value()}`, 'Content-Type': 'application/json' }
    });
    return res.status(200).json({ success: true, data: response.data });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

exports.sendPasswordResetLink = functions.runWith({ 
  memory: '512MB', 
  timeoutSeconds: 60,
  secrets: [RESEND_API_KEY] 
}).https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    return res.status(204).send('');
  }
  const { email } = req.body;
  try {
    const link = await admin.auth().generatePasswordResetLink(email, {
      url: 'https://stayhubgh.com/reset-password',
      handleCodeInApp: true
    });
    await axios.post('https://api.resend.com/emails', {
      from: 'StayHub Security <security@stayhubgh.com>',
      to: [email],
      subject: 'Reset your StayHub Password',
      html: `<div style="padding: 20px;"><a href="${link}" style="background: #2E2AB7; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">Reset Password</a></div>`
    }, {
      headers: { 'Authorization': `Bearer ${RESEND_API_KEY.value()}`, 'Content-Type': 'application/json' }
    });
    return res.status(200).json({ success: true });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

/**
 * UTILITY: GET BANKS (HTTPS)
 */
exports.getBanks = functions.runWith({ secrets: [PAYSTACK_SECRET_KEY] }).https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  try {
    const response = await axios.get("https://api.paystack.co/bank", {
      headers: { Authorization: `Bearer ${getPaystackSecretKey()}` }
    });
    return res.status(200).json(response.data);
  } catch (e) {
    return res.status(500).json({ status: false, message: e.message });
  }
});

/**
 * UTILITY: CREATE SUBACCOUNT (HTTPS)
 */
exports.createSubAccount = functions.runWith({ secrets: [PAYSTACK_SECRET_KEY] }).https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  try {
    const response = await axios.post("https://api.paystack.co/subaccount", req.body, {
      headers: { Authorization: `Bearer ${getPaystackSecretKey()}` }
    });
    return res.status(200).json(response.data);
  } catch (e) {
    return res.status(500).json({ status: false, message: e.message });
  }
});

/**
 * DIAGNOSTIC: PING AUTH
 */
exports.pingAuth = functions.runWith({ secrets: [PAYSTACK_SECRET_KEY] }).https.onCall(async (data, context) => {
  return {
    isAuthenticated: !!context.auth,
    uid: context.auth?.uid || null,
    email: context.auth?.token?.email || null,
    serverTime: new Date().toISOString(),
    authTime: context.auth?.token?.auth_time || null,
    hasSecret: !!getPaystackSecretKey(),
  };
});
