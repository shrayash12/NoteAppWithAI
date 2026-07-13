import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {GoogleGenerativeAI} from "@google/generative-ai";

const geminiApiKey = defineSecret("GEMINI_API_KEY");

type AIAction = "enhance" | "summarize" | "translate";

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

    const genAI = new GoogleGenerativeAI(geminiApiKey.value());
    const model = genAI.getGenerativeModel({model: "gemini-2.0-flash"});

    const prompt = buildPrompt(action, text, targetLanguage);

    let output: string;
    try {
      const result = await model.generateContent(prompt);
      output = result.response.text().trim();
    } catch (e) {
      throw new HttpsError("internal", `AI request failed: ${e}`);
    }

    if (!output) {
      throw new HttpsError("internal", "The AI returned an empty response.");
    }

    return {result: output};
  }
);
