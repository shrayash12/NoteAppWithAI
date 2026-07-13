"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.runAIAction = void 0;
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const generative_ai_1 = require("@google/generative-ai");
const geminiApiKey = (0, params_1.defineSecret)("GEMINI_API_KEY");
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
    const genAI = new generative_ai_1.GoogleGenerativeAI(geminiApiKey.value());
    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });
    const prompt = buildPrompt(action, text, targetLanguage);
    let output;
    try {
        const result = await model.generateContent(prompt);
        output = result.response.text().trim();
    }
    catch (e) {
        throw new https_1.HttpsError("internal", `AI request failed: ${e}`);
    }
    if (!output) {
        throw new https_1.HttpsError("internal", "The AI returned an empty response.");
    }
    return { result: output };
});
//# sourceMappingURL=index.js.map