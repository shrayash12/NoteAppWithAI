import * as admin from "firebase-admin";
import {onCall, onRequest, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {GoogleGenerativeAI} from "@google/generative-ai";
import {
  AIAction,
  Plan,
  consumeQuota,
  refundQuota,
  getUsageSummary,
  setSubscriptionState,
} from "./subscription";

admin.initializeApp();

const geminiApiKey = defineSecret("GEMINI_API_KEY");
const revenueCatWebhookSecret = defineSecret("REVENUECAT_WEBHOOK_SECRET");

interface RunAIActionRequest {
  action: AIAction;
  text: string;
  targetLanguage?: string;
}

function buildPrompt(
  action: AIAction,
  text: string,
  targetLanguage?: string
): string {
  switch (action) {
  case "enhance":
    return (
      "Improve the grammar, clarity, and style of the following note. " +
        "Keep the original meaning, tone, and language. Return ONLY the " +
        `improved text with no preamble or explanation:\n\n${text}`
    );
  case "summarize":
    return (
      "Summarize the following note in 2-4 concise sentences. Return " +
        `ONLY the summary with no preamble or explanation:\n\n${text}`
    );
  case "translate":
    return (
      `Translate the following note into ${targetLanguage}. Return ONLY ` +
        `the translated text with no preamble or explanation:\n\n${text}`
    );
  }
}

export const runAIAction = onCall(
  {secrets: [geminiApiKey], region: "us-central1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to use AI features."
      );
    }
    const uid = request.auth.uid;

    const {action, text, targetLanguage} = request.data as RunAIActionRequest;

    if (!text || !text.trim()) {
      throw new HttpsError("invalid-argument", "Add some text first.");
    }
    if (action === "translate" && !targetLanguage) {
      throw new HttpsError(
        "invalid-argument",
        "A target language is required for translation."
      );
    }
    if (!["enhance", "summarize", "translate"].includes(action)) {
      throw new HttpsError("invalid-argument", "Unknown action.");
    }

    // Server-side quota check — must happen before the paid Gemini call so
    // a client can never bypass limits by skipping its own local check.
    await consumeQuota(uid, action);

    const genAI = new GoogleGenerativeAI(geminiApiKey.value());
    const model = genAI.getGenerativeModel({model: "gemini-flash-latest"});

    const prompt = buildPrompt(action, text, targetLanguage);

    let output: string;
    try {
      const result = await model.generateContent(prompt);
      output = result.response.text().trim();
    } catch (e) {
      console.error("Gemini call failed", e);
      await refundQuota(uid, action);
      throw new HttpsError("internal", `AI request failed: ${e}`);
    }

    if (!output) {
      await refundQuota(uid, action);
      throw new HttpsError("internal", "The AI returned an empty response.");
    }

    return {result: output};
  }
);

export const getUsageStatus = onCall(
  {region: "us-central1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }
    return getUsageSummary(request.auth.uid);
  }
);

// Maps RevenueCat product identifiers to internal plan names. These must
// match exactly the product IDs configured in App Store Connect / Google
// Play Console / RevenueCat.
const PRODUCT_TO_PLAN: Record<string, Plan> = {
  "smartnotes_pro_monthly": "pro_monthly",
  "smartnotes_pro_yearly": "pro_yearly",
};

interface RevenueCatEvent {
  type: string;
  app_user_id: string;
  product_id: string;
  expiration_at_ms?: number;
}

export const revenueCatWebhook = onRequest(
  {secrets: [revenueCatWebhookSecret], region: "us-central1"},
  async (req, res) => {
    if (req.headers.authorization !== revenueCatWebhookSecret.value()) {
      res.status(401).send("Unauthorized");
      return;
    }

    const event = (req.body as {event?: RevenueCatEvent})?.event;
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
        await setSubscriptionState(uid, {
          plan,
          planStatus: "active",
          periodEndMs: event.expiration_at_ms ?? null,
          resetUsage:
              event.type === "INITIAL_PURCHASE" || event.type === "RENEWAL",
          revenueCatAppUserId: uid,
        });
        break;
      case "EXPIRATION":
        await setSubscriptionState(uid, {
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
    } catch (e) {
      console.error("Failed to process RevenueCat webhook", e);
      res.status(500).send("Internal error");
    }
  }
);
