const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Access secret key from Firebase config
// Run: firebase functions:config:set paystack.secret_key="sk_test_..."
// Then deploy with: firebase deploy --only functions
// Access secret key from Firebase config inside handlers to avoid initialization timeouts.
function getPaystackSecretKey() {
  return functions.config().paystack?.secret_key || process.env.PAYSTACK_SECRET_KEY;
}

function getResendApiKey() {
  return functions.config().resend?.key || process.env.RESEND_API_KEY || "re_dFTH3yX8_3conedEf9TF6aLkLsob3oP2W";
}

exports.initializePayment = functions.runWith({ memory: '512MB', timeoutSeconds: 60 }).https.onRequest(async (req, res) => {
  const axios = require("axios");
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    return res.status(204).send('');
  }
  if (req.method !== "POST") {
    return res.status(405).send("Method Not Allowed");
  }

  const { email, amount, reference, subaccount, transaction_charge } = req.body;

  if (!email || !amount || !reference) {
    return res.status(400).send("Missing required fields");
  }

  try {
    const payload = {
      email,
      amount, // Amount in Kobo
      reference,
      currency: "GHS",
      callback_url: "https://stayhub.app/payment-callback",
      channels: ["card", "mobile_money", "ussd"],
    };

    if (subaccount) {
      payload.subaccount = subaccount;
      payload.bearer = "subaccount";
      if (transaction_charge) {
        payload.transaction_charge = transaction_charge;
      }
    }

    const response = await axios.post(
      "https://api.paystack.co/transaction/initialize",
      payload,
      {
        headers: {
          Authorization: `Bearer ${getPaystackSecretKey()}`,
          "Content-Type": "application/json",
        },
      }
    );

    return res.status(200).json(response.data);
  } catch (error) {
    console.error("Paystack Init Error:", error.response?.data || error.message);
    return res.status(500).json({ error: "Payment initialization failed" });
  }
});

exports.verifyPayment = functions.runWith({ memory: '512MB', timeoutSeconds: 60 }).https.onRequest(async (req, res) => {
  const axios = require("axios");
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'GET');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    return res.status(204).send('');
  }
  const { reference } = req.query; // Or req.body

  if (!reference) {
    return res.status(400).send("Missing reference");
  }

  try {
    const response = await axios.get(
      `https://api.paystack.co/transaction/verify/${reference}`,
      {
        headers: {
          Authorization: `Bearer ${getPaystackSecretKey()}`,
        },
      }
    );

    return res.status(200).json(response.data);
  } catch (error) {
    console.error("Paystack Verify Error:", error.response?.data || error.message);
    return res.status(500).json({ error: "Verification failed" });
  }
});

exports.getBanks = functions.https.onRequest(async (req, res) => {
  const axios = require("axios");
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'GET');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    return res.status(204).send('');
  }
  try {
    // 1. Fetch Commercial Banks
    const banksResponse = await axios.get("https://api.paystack.co/bank?currency=GHS", {
      headers: { Authorization: `Bearer ${getPaystackSecretKey()}` }
    });

    // 2. Fetch Mobile Money
    const momoResponse = await axios.get("https://api.paystack.co/bank?currency=GHS&type=mobile_money", {
      headers: { Authorization: `Bearer ${getPaystackSecretKey()}` }
    });

    let allBanks = [];
    if (banksResponse.data.status) {
      allBanks = [...banksResponse.data.data];
    }

    if (momoResponse.data.status) {
      // Avoid duplicates
      const existingCodes = new Set(allBanks.map(b => b.code));
      momoResponse.data.data.forEach(bank => {
        if (!existingCodes.has(bank.code)) {
          allBanks.push(bank);
        }
      });
    }

    // Sort Alphabetically
    allBanks.sort((a, b) => a.name.localeCompare(b.name));

    // Return simplified list
    const result = allBanks.map(b => ({ name: b.name, code: b.code, id: b.id }));
    return res.status(200).json({ status: true, data: result });

  } catch (error) {
    console.error("Get Banks Error:", error.response?.data || error.message);
    return res.status(500).json({ error: "Failed to fetch banks" });
  }
});

exports.createSubAccount = functions.https.onRequest(async (req, res) => {
  const axios = require("axios");
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    return res.status(204).send('');
  }
  if (req.method !== "POST") return res.status(405).send("Method Not Allowed");

  const { business_name, settlement_bank, account_number, percentage_charge } = req.body;

  try {
    const payload = {
      business_name,
      settlement_bank,
      account_number,
      percentage_charge: percentage_charge || 0 // Default to 0
    };

    const response = await axios.post("https://api.paystack.co/subaccount", payload, {
      headers: {
        Authorization: `Bearer ${getPaystackSecretKey()}`,
        "Content-Type": "application/json"
      }
    });

    return res.status(200).json(response.data);
  } catch (error) {
    console.error("Create Subaccount Error:", error.response?.data || error.message);
    return res.status(500).json({ error: "Failed to create subaccount", details: error.response?.data });
  }
});

exports.sendOtp = functions.https.onRequest(async (req, res) => {
  const axios = require("axios");
  // CORS Headers
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method Not Allowed" });
  }

  const { email, otp } = req.body;

  if (!email || !otp) {
    return res.status(400).json({ error: "Missing email or otp" });
  }

  const RESEND_API_KEY = getResendApiKey();

  try {
    const response = await axios.post(
      'https://api.resend.com/emails',
      {
        from: 'StayHub Support <support@stayhubgh.com>',
        to: [email],
        subject: 'Your StayHub Verification Code',
        html: `
              <div style="font-family: Arial, sans-serif; padding: 20px; color: #333;">
                <h2 style="color: #007bff;">StayHub Verification</h2>
                <p>Hello,</p>
                <p>Your verification code is:</p>
                <h1 style="background: #f4f4f4; padding: 10px; border-radius: 5px; text-align: center; letter-spacing: 5px;">${otp}</h1>
                <p>This code will expire in 10 minutes.</p>
                <p>If you did not request this, please ignore this email.</p>
                <br/>
                <p>Best regards,<br/>The StayHub Team</p>
              </div>
            `
      },
      {
        headers: {
          'Authorization': `Bearer ${RESEND_API_KEY}`,
          'Content-Type': 'application/json'
        }
      }
    );

    return res.status(200).json({ success: true, data: response.data });
  } catch (error) {
    console.error("Resend API Error:", error.response?.data || error.message);
    return res.status(500).json({ error: "Failed to send email", details: error.response?.data || error.message });
  }
});

exports.sendPasswordResetLink = functions.https.onRequest(async (req, res) => {
  const axios = require("axios");
  // CORS Headers
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method Not Allowed" });
  }

  const { email } = req.body;

  if (!email) {
    return res.status(400).json({ error: "Missing email" });
  }

  const RESEND_API_KEY = getResendApiKey();

  try {
    // 1. Generate Auth Token / Link
    const link = await admin.auth().generatePasswordResetLink(email, {
      url: 'https://stayhubgh.com/reset-password', // Redirect back to app
      handleCodeInApp: true
    });

    // 2. Send via Resend
    const response = await axios.post(
      'https://api.resend.com/emails',
      {
        from: 'StayHub Security <security@stayhubgh.com>', // Premium sender identity
        to: [email],
        subject: 'Reset your StayHub Password',
        html: `
          <div style="font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 40px 20px; background-color: #f9f9f9;">
            <div style="background-color: white; padding: 40px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.05);">
              <div style="text-align: center; margin-bottom: 30px;">
                <h2 style="color: #1a1a1a; margin: 0; font-size: 24px;">Reset Password Request</h2>
              </div>
              
              <p style="color: #4a4a4a; font-size: 16px; line-height: 1.6; margin-bottom: 25px;">
                Hello,
              </p>
              <p style="color: #4a4a4a; font-size: 16px; line-height: 1.6; margin-bottom: 25px;">
                We received a request to reset your password for your StayHub account. 
                If you didn't make this request, you can safely ignore this email.
              </p>
              
              <div style="text-align: center; margin: 35px 0;">
                <a href="${link}" style="background-color: #2E2AB7; color: white; text-decoration: none; padding: 14px 28px; border-radius: 8px; font-weight: bold; font-size: 16px; display: inline-block; box-shadow: 0 4px 6px rgba(46, 42, 183, 0.2);">
                  Reset Password
                </a>
              </div>

              <p style="color: #888; font-size: 14px; margin-top: 40px; text-align: center; border-top: 1px solid #eee; padding-top: 20px;">
                StayHub Inc. <br/>
                Accra, Ghana
              </p>
            </div>
          </div>
        `
      },
      {
        headers: {
          'Authorization': `Bearer ${RESEND_API_KEY}`,
          'Content-Type': 'application/json'
        }
      }
    );

    return res.status(200).json({ success: true, message: "Password reset email sent" });

  } catch (error) {
    console.error("Password Reset Error:", error);
    return res.status(500).json({ error: "Failed to process request", details: error.message });
  }
});

exports.ping = functions.https.onRequest((req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.status(200).send("pong");
});

// --- PUSH NOTIFICATIONS ---

exports.onBookingCreated = functions.firestore
  .document('users/{userId}/bookings/{bookingId}')
  .onCreate(async (snapshot, context) => {
    const booking = snapshot.data();
    const agentId = booking.agentId;
    if (!agentId) return;

    try {
      // Get Agent FCM Token
      const agentDoc = await admin.firestore().collection('agents').doc(agentId).get();
      const fcmToken = agentDoc.data()?.fcmToken;

      if (fcmToken) {
        const message = {
          notification: {
            title: 'New Booking Request! 🏠',
            body: `A student has requested to book ${booking.hostelName}. Tap to approve.`,
          },
          token: fcmToken,
          data: {
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            bookingId: context.params.bookingId,
            userId: context.params.userId,
            type: 'booking_request'
          }
        };
        await admin.messaging().send(message);
        console.log(`Notification sent to agent ${agentId}`);

        // Save for in-app history
        await admin.firestore().collection('users').doc(agentId).collection('notifications').add({
          title: message.notification.title,
          body: message.notification.body,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
          type: 'booking_request',
          bookingId: context.params.bookingId
        });
      }
    } catch (error) {
      console.error("Error sending booking notification:", error);
    }
  });

exports.onBookingStatusUpdated = functions.firestore
  .document('users/{userId}/bookings/{bookingId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status === after.status) return;

    try {
      // Get Student FCM Token
      const userDoc = await admin.firestore().collection('users').doc(context.params.userId).get();
      const fcmToken = userDoc.data()?.fcmToken;

      if (fcmToken) {
        let title = 'Booking Update 📅';
        let body = `Your booking for ${after.hostelName} is now ${after.status}.`;

        if (after.status === 'CONFIRMED') {
          body = `Your booking for ${after.hostelName} has been APPROVED! Tap to pay.`;
        } else if (after.status === 'PAID') {
          body = `Payment received for ${after.hostelName}. Your stay is confirmed!`;
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
        console.log(`Status update notification sent to student ${context.params.userId}`);

        // Save for in-app history
        await admin.firestore().collection('users').doc(context.params.userId).collection('notifications').add({
          title: message.notification.title,
          body: message.notification.body,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
          type: 'booking_update',
          status: after.status
        });
      }
    } catch (error) {
      console.error("Error sending status update notification:", error);
    }
  });

exports.onMessageCreated = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    const senderId = message.senderId;
    const chatId = context.params.chatId;

    try {
      // 1. Get Chat Room to find the OTHER user
      const chatDoc = await admin.firestore().collection('chats').doc(chatId).get();
      const users = chatDoc.data()?.users || [];
      const recipientId = users.find(uid => uid !== senderId);

      if (!recipientId) return;

      // 2. Find recipient token in 'users' or 'agents'
      let recipientDoc = await admin.firestore().collection('users').doc(recipientId).get();
      if (!recipientDoc.exists) {
        recipientDoc = await admin.firestore().collection('agents').doc(recipientId).get();
      }

      const fcmToken = recipientDoc.data()?.fcmToken;

      if (fcmToken) {
        const payload = {
          notification: {
            title: message.senderName || 'New Message',
            body: message.type === 'image' ? '📷 Sent an image' : message.text,
          },
          token: fcmToken,
          data: {
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            chatId: chatId,
            type: 'chat'
          }
        };
        await admin.messaging().send(payload);
        console.log(`Chat notification sent to recipient ${recipientId}`);

        // Save for in-app history
        await admin.firestore().collection('users').doc(recipientId).collection('notifications').add({
          title: payload.notification.title,
          body: payload.notification.body,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
          type: 'chat',
          chatId: context.params.chatId
        });
      }
    } catch (error) {
      console.error("Error sending chat notification:", error);
    }
  });

exports.onHostelUpdated = functions.firestore
  .document('hostels/{hostelId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Notify when status changes from something else to 'approved'
    if ((before.status !== 'approved') && (after.status === 'approved')) {
      const agentId = after.agentId;
      if (!agentId) return;

      try {
        const agentDoc = await admin.firestore().collection('agents').doc(agentId).get();
        const fcmToken = agentDoc.data()?.fcmToken;

        if (fcmToken) {
          const message = {
            notification: {
              title: 'Property Approved! 🎉',
              body: `Your hostel "${after.name}" has been approved and is now live.`,
            },
            token: fcmToken,
            data: {
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
              type: 'hostel_approved',
              hostelId: context.params.hostelId
            }
          };
          await admin.messaging().send(message);
          console.log(`Approval notification sent to agent ${agentId}`);

          // Save for in-app history
          await admin.firestore().collection('users').doc(agentId).collection('notifications').add({
            title: message.notification.title,
            body: message.notification.body,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            isRead: false,
            type: 'hostel_approved',
            hostelId: context.params.hostelId
          });
        }
      } catch (error) {
        console.error("Error sending hostel approval notification:", error);
      }
    }
  });
