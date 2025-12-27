const express = require("express");
const cors = require("cors");
const axios = require("axios");
require("dotenv").config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

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

// Root Route
app.get("/", (req, res) => {
    res.send("StayHub Payment Server is Running! 🚀");
});

// Start Server
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
