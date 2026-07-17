"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.revenueCatWebhook = exports.getUsageStatus = exports.runAIAction = void 0;
const admin = require("firebase-admin");
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const generative_ai_1 = require("@google/generative-ai");
const subscription_1 = require("./subscription");
admin.initializeApp();
const geminiApiKey = (0, params_1.defineSecret)("GEMINI_API_KEY");
const revenueCatWebhookSecret = (0, params_1.defineSecret)("REVENUECAT_WEBHOOK_SECRET");
function buildPrompt(action, text, targetLanguage) {
    switch (action) {
        case "enhance":
            return ("Improve the grammar, clarity, and style of the following note. " +
                "Keep the original meaning, tone, and language. Return ONLY the " +
                `improved text with no preamble or explanation:\n\n${text}`);
        case "summarize":
            return ("Summarize the following note in 2-4 concise sentences. Return " +
                `ONLY the summary with no preamble or explanation:\n\n${text}`);
        case "translate":
            return (`Translate the following note into ${targetLanguage}. Return ONLY ` +
                `the translated text with no preamble or explanation:\n\n${text}`);
    }
}
exports.runAIAction = (0, https_1.onCall)({ secrets: [geminiApiKey], region: "us-central1" }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "You must be signed in to use AI features.");
    }
    const uid = request.auth.uid;
    const { action, text, targetLanguage } = request.data;
    if (!text || !text.trim()) {
        throw new https_1.HttpsError("invalid-argument", "Add some text first.");
    }
    if (action === "translate" && !targetLanguage) {
        throw new https_1.HttpsError("invalid-argument", "A target language is required for translation.");
    }
    if (!["enhance", "summarize", "translate"].includes(action)) {
        throw new https_1.HttpsError("invalid-argument", "Unknown action.");
    }
    // Server-side quota check — must happen before the paid Gemini call so
    // a client can never bypass limits by skipping its own local check.
    await (0, subscription_1.consumeQuota)(uid, action);
    const genAI = new generative_ai_1.GoogleGenerativeAI(geminiApiKey.value());
    const model = genAI.getGenerativeModel({ model: "gemini-flash-latest" });
    const prompt = buildPrompt(action, text, targetLanguage);
    let output;
    try {
        const result = await model.generateContent(prompt);
        output = result.response.text().trim();
    }
    catch (e) {
        console.error("Gemini call failed", e);
        await (0, subscription_1.refundQuota)(uid, action);
        throw new https_1.HttpsError("internal", `AI request failed: ${e}`);
    }
    if (!output) {
        await (0, subscription_1.refundQuota)(uid, action);
        throw new https_1.HttpsError("internal", "The AI returned an empty response.");
    }
    return { result: output };
});
exports.getUsageStatus = (0, https_1.onCall)({ region: "us-central1" }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "You must be signed in.");
    }
    return (0, subscription_1.getUsageSummary)(request.auth.uid);
});
// Maps RevenueCat product identifiers to internal plan names. These must
// match exactly the product IDs configured in App Store Connect / Google
// Play Console / RevenueCat.
const PRODUCT_TO_PLAN = {
    "smartnotes_pro_monthly": "pro_monthly",
    "smartnotes_pro_yearly": "pro_yearly",
};
exports.revenueCatWebhook = (0, https_1.onRequest)({ secrets: [revenueCatWebhookSecret], region: "us-central1" }, async (req, res) => {
    if (req.headers.authorization !== revenueCatWebhookSecret.value()) {
        res.status(401).send("Unauthorized");
        return;
    }
    const event = req.body?.event;
    if (!event) {
        res.status(400).send("Missing event");
        return;
    }
    const uid = event.app_user_id;
    const plan = PRODUCT_TO_PLAN[event.product_id];
    if (!uid || !plan) {
        console.warn("Unrecognized RevenueCat webhook event", {
            uid,
            productId: event.product_id,
            type: event.type,
        });
        res.status(200).send("Ignored");
        return;
    }
    try {
        switch (event.type) {
            case "INITIAL_PURCHASE":
            case "RENEWAL":
            case "PRODUCT_CHANGE":
            case "UNCANCELLATION":
                await (0, subscription_1.setSubscriptionState)(uid, {
                    plan,
                    planStatus: "active",
                    periodEndMs: event.expiration_at_ms ?? null,
                    resetUsage: event.type === "INITIAL_PURCHASE" || event.type === "RENEWAL",
                    revenueCatAppUserId: uid,
                });
                break;
            case "EXPIRATION":
                await (0, subscription_1.setSubscriptionState)(uid, {
                    plan,
                    planStatus: "inactive",
                    periodEndMs: null,
                    resetUsage: false,
                    revenueCatAppUserId: uid,
                });
                break;
            default:
                // CANCELLATION (still active until period end), BILLING_ISSUE, etc.
                // require no state change here.
                break;
        }
        res.status(200).send("OK");
    }
    catch (e) {
        console.error("Failed to process RevenueCat webhook", e);
        res.status(500).send("Internal error");
    }
});
//# sourceMappingURL=index.js.map