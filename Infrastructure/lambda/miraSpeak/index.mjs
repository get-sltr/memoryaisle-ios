import {
  PollyClient,
  SynthesizeSpeechCommand,
} from "@aws-sdk/client-polly";

const client = new PollyClient({ region: "us-east-1" });

// Ruth = en-US generative female voice, warm and conversational
const VOICE_ID = "Ruth";
const ENGINE = "generative";
const MAX_CHARACTERS = 3000;

export const handler = async (event) => {
  const body = JSON.parse(event.body || "{}");
  const { text } = body;

  if (!text || typeof text !== "string") {
    return errorResponse(400, "Text is required");
  }

  if (text.length > MAX_CHARACTERS) {
    return errorResponse(
      400,
      `Text exceeds maximum of ${MAX_CHARACTERS} characters`
    );
  }

  try {
    const command = new SynthesizeSpeechCommand({
      Text: text,
      VoiceId: VOICE_ID,
      Engine: ENGINE,
      OutputFormat: "mp3",
      SampleRate: "24000",
      TextType: "text",
    });

    const response = await client.send(command);

    if (!response.AudioStream) {
      return errorResponse(500, "Polly returned no audio stream");
    }

    // Convert the readable stream to a Buffer, then to base64
    const chunks = [];
    for await (const chunk of response.AudioStream) {
      chunks.push(chunk);
    }
    const audioBuffer = Buffer.concat(chunks);
    const audioBase64 = audioBuffer.toString("base64");

    return {
      statusCode: 200,
      headers: corsHeaders(),
      body: JSON.stringify({
        audio: audioBase64,
        format: "mp3",
        voice: VOICE_ID,
      }),
    };
  } catch (error) {
    console.error("Polly error:", error);
    return errorResponse(
      500,
      "Voice generation is temporarily unavailable. Please try again."
    );
  }
};

function errorResponse(statusCode, message) {
  return {
    statusCode,
    headers: corsHeaders(),
    body: JSON.stringify({ error: message }),
  };
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "https://memoryaisle.app",
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "POST,OPTIONS",
    "Content-Type": "application/json",
  };
}
