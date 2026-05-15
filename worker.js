addEventListener("fetch", event => {
    event.respondWith(handleRequest(event.request));
});

async function handleRequest(request) {
    // Handle CORS preflight
    if (request.method === "OPTIONS") {
        return new Response(null, {
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type",
            },
        });
    }

    if (request.method !== "POST") {
        return new Response("Method Not Allowed", { status: 405 });
    }

    try {
        const { email, otp } = await request.json();

        if (!email || !otp) {
            return new Response("Missing email or otp", { status: 400 });
        }

        // Hardcode key here since secrets require extra setup step
        // This is safe because the worker code runs on server
        // Use global variable defined in Cloudflare dashboard
        const API_KEY = typeof RESEND_API_KEY !== 'undefined' ? RESEND_API_KEY : "";

        const resendResponse = await fetch("https://api.resend.com/emails", {
            method: "POST",
            headers: {
                "Authorization": `Bearer ${API_KEY}`,
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                from: "StayHub Support <support@stayhubgh.com>",
                to: [email],
                subject: "Your StayHub Verification Code",
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
            }),
        });

        const data = await resendResponse.json();

        return new Response(JSON.stringify(data), {
            headers: {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*", // Allow web app access
            },
            status: resendResponse.status,
        });

    } catch (e) {
        return new Response(JSON.stringify({ error: e.message }), {
            status: 500,
            headers: { "Access-Control-Allow-Origin": "*" },
        });
    }
}
