const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

// Access secret key from Firebase config
// Run: firebase functions:config:set paystack.secret_key="sk_test_..."
// Then deploy with: firebase deploy --only functions
const PAYSTACK_SECRET_KEY = functions.config().paystack.secret_key;

exports.initializePayment = functions.https.onRequest(async (req, res) => {
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
          Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
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

exports.verifyPayment = functions.https.onRequest(async (req, res) => {
  const { reference } = req.query; // Or req.body

  if (!reference) {
    return res.status(400).send("Missing reference");
  }

  try {
    const response = await axios.get(
      `https://api.paystack.co/transaction/verify/${reference}`,
      {
        headers: {
          Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
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
  try {
    // 1. Fetch Commercial Banks
    const banksResponse = await axios.get("https://api.paystack.co/bank?currency=GHS", {
      headers: { Authorization: `Bearer ${PAYSTACK_SECRET_KEY}` }
    });

    // 2. Fetch Mobile Money
    const momoResponse = await axios.get("https://api.paystack.co/bank?currency=GHS&type=mobile_money", {
      headers: { Authorization: `Bearer ${PAYSTACK_SECRET_KEY}` }
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
        Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
        "Content-Type": "application/json"
      }
    });

    return res.status(200).json(response.data);
  } catch (error) {
    console.error("Create Subaccount Error:", error.response?.data || error.message);
    return res.status(500).json({ error: "Failed to create subaccount", details: error.response?.data });
  }
});
