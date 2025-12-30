const express = require("express");
const cors = require("cors");
const axios = require("axios");
require("dotenv").config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors({
    origin: '*', // Allow all origins for debugging
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(require('compression')()); // Gzip compression
app.use(express.json());

// Request Logger
app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
    next();
});

// Load Secret Key from Environment Variable
const PAYSTACK_SECRET_KEY = process.env.PAYSTACK_SECRET_KEY;

if (!PAYSTACK_SECRET_KEY) {
    console.warn("⚠️ WARNING: PAYSTACK_SECRET_KEY is not set in environment variables.");
}

// -----------------------------------------------------------------------------
// 1. Initialize Payment
// -----------------------------------------------------------------------------
app.post("/initializePayment", async (req, res) => {
    const { email, amount, reference, subaccount, transaction_charge } = req.body;

    if (!email || !amount || !reference) {
        return res.status(400).json({ status: false, message: "Missing required fields" });
    }

    try {
        const payload = {
            email,
            amount, // Amount in Kobo
            reference,
            currency: "GHS",
            callback_url: "https://stayhub.app/payment-callback", // Keep this dummy or use valid URL
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

        return res.status(200).json({ status: true, data: response.data.data });
    } catch (error) {
        console.error("Paystack Init Error:", error.response?.data || error.message);
        const errorMessage = error.response?.data?.message || "Payment initialization failed";
        return res.status(500).json({ status: false, message: errorMessage });
    }
});

// -----------------------------------------------------------------------------
// 2. Verify Payment
// -----------------------------------------------------------------------------
app.get("/verifyPayment", async (req, res) => {
    const { reference } = req.query;

    if (!reference) {
        return res.status(400).json({ status: false, message: "Missing reference" });
    }

    try {
        const response = await axios.get(
            `https://api.paystack.co/transaction/verify/${reference}`,
            {
                headers: { Authorization: `Bearer ${PAYSTACK_SECRET_KEY}` },
            }
        );

        return res.status(200).json({ status: true, data: response.data.data });
    } catch (error) {
        console.error("Paystack Verify Error:", error.response?.data || error.message);
        return res.status(500).json({ status: false, message: "Verification failed" });
    }
});

// -----------------------------------------------------------------------------
// 3. Get Banks
// -----------------------------------------------------------------------------
app.get("/getBanks", async (req, res) => {
    try {
        // 1. Fetch Commercial Banks
        const banksResponse = await axios.get("https://api.paystack.co/bank?currency=GHS", {
            headers: { Authorization: `Bearer ${PAYSTACK_SECRET_KEY}` },
        });

        // 2. Fetch Mobile Money
        const momoResponse = await axios.get(
            "https://api.paystack.co/bank?currency=GHS&type=mobile_money",
            {
                headers: { Authorization: `Bearer ${PAYSTACK_SECRET_KEY}` },
            }
        );

        let allBanks = [];
        if (banksResponse.data.status) {
            allBanks = [...banksResponse.data.data];
        }

        if (momoResponse.data.status) {
            const existingCodes = new Set(allBanks.map((b) => b.code));
            momoResponse.data.data.forEach((bank) => {
                if (!existingCodes.has(bank.code)) {
                    allBanks.push(bank);
                }
            });
        }

        // Sort Alphabetically
        allBanks.sort((a, b) => a.name.localeCompare(b.name));

        return res.status(200).json({ status: true, data: allBanks });
    } catch (error) {
        console.error("Get Banks Error:", error.response?.data || error.message);
        return res.status(500).json({ status: false, message: "Failed to fetch banks" });
    }
});

// -----------------------------------------------------------------------------
// 4. Create Subaccount
// -----------------------------------------------------------------------------
app.post("/createSubAccount", async (req, res) => {
    const { business_name, settlement_bank, account_number, percentage_charge } = req.body;

    try {
        const payload = {
            business_name,
            settlement_bank,
            account_number,
            percentage_charge: percentage_charge || 0,
        };

        const response = await axios.post("https://api.paystack.co/subaccount", payload, {
            headers: {
                Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
                "Content-Type": "application/json",
            },
        });

        return res.status(200).json({ status: true, data: response.data.data });
    } catch (error) {
        console.error("Create Subaccount Error:", error.response?.data || error.message);
        return res
            .status(500)
            .json({ status: false, message: "Failed to create subaccount", details: error.response?.data });
    }
});

// -----------------------------------------------------------------------------
// 5. Send Password Reset Link (Via Resend)
// -----------------------------------------------------------------------------
const admin = require("firebase-admin");

// Initialize Firebase Admin (Expects FIREBASE_SERVICE_ACCOUNT env var)
// On Render, add a 'Secret File' named 'service-account.json' and set 
// GOOGLE_APPLICATION_CREDENTIALS to /etc/secrets/service-account.json
// OR set FIREBASE_SERVICE_ACCOUNT as a JSON string environment variable.

let firebaseInitialized = false;

try {
    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
        const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });
        firebaseInitialized = true;
        console.log("✅ Firebase Admin Initialized.");
    } else {
        console.warn("⚠️ WARNING: FIREBASE_SERVICE_ACCOUNT not set. Password reset will fail.");
    }
} catch (error) {
    console.error("❌ Firebase Admin Init Error:", error);
}

app.post("/sendPasswordResetLink", async (req, res) => {
    const { email } = req.body;

    if (!email) {
        return res.status(400).json({ status: false, message: "Missing email" });
    }

    if (!firebaseInitialized) {
        return res.status(500).json({ status: false, message: "Server configuration error: Firebase not initialized." });
    }

    const RESEND_API_KEY = process.env.RESEND_API_KEY || "re_dFTH3yX8_3conedEf9TF6aLkLsob3oP2W";

    try {
        // 1. Generate Auth Token / Link
        const link = await admin.auth().generatePasswordResetLink(email, {
            url: 'https://stayhubgh.com/reset-password',
            handleCodeInApp: true
        });

        // 2. Send via Resend
        const response = await axios.post(
            'https://api.resend.com/emails',
            {
                from: 'StayHub Security <security@stayhubgh.com>',
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

        return res.status(200).json({ status: true, message: "Password reset email sent" });

    } catch (error) {
        console.error("Password Reset Error:", error);
        const msg = error.errorInfo ? error.errorInfo.message : error.message;
        return res.status(500).json({ status: false, message: "Failed to process request", details: msg });
    }
});

// Root Route
app.get("/", (req, res) => {
    res.send("StayHub Server (Node.js) is Running! 🚀");
});

// Start Server
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
