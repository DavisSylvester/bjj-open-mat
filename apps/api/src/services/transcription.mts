export interface TranscriptionService {
  translateToEnglish(audio: Uint8Array, filename: string): Promise<{ text: string; durationMs: number }>;
}

export class WhisperTranscriptionService implements TranscriptionService {
  public constructor(
    private readonly apiKey: string,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  public async translateToEnglish(audio: Uint8Array, filename: string): Promise<{ text: string; durationMs: number }> {
    const started = performance.now();
    const form = new FormData();
    form.append("file", new Blob([audio], { type: "audio/mp4" }), filename);
    form.append("model", "whisper-1");
    const res = await this.fetchFn("https://api.openai.com/v1/audio/translations", {
      method: "POST",
      headers: { Authorization: `Bearer ${this.apiKey}` },
      body: form,
    });
    if (!res.ok) {
      throw new Error(`Whisper translation failed: ${res.status}`);
    }
    const json = (await res.json()) as { text: string };
    return { text: json.text ?? "", durationMs: Math.round(performance.now() - started) };
  }
}
