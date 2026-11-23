import os
import httpx
from app.services.llm import _call_gemini, FAST

def translate_text(text: str, target_language: str, source_language: str = "en") -> dict:
    if target_language == source_language or not text.strip():
        return {"translated_text": text, "target_language": target_language,
                "source_language": source_language, "provider": "passthrough"}

    if (os.getenv("DEEPL_API_KEY") or "").strip():
        try:
            r = httpx.post(
                "https://api-free.deepl.com/v2/translate",
                headers={"Authorization": f"DeepL-Auth-Key {os.getenv('DEEPL_API_KEY')}"},
                data={"text": text, "source_lang": source_language.upper(),
                      "target_lang": target_language.upper()},
                timeout=15,
            )
            if r.status_code == 200:
                return {"translated_text": r.json()["translations"][0]["text"],
                        "target_language": target_language,
                        "source_language": source_language, "provider": "deepl"}
        except Exception as e:
            print(f"[translate] DeepL: {e}")

    if (os.getenv("GEMINI_API_KEY") or "").strip():
        try:
            payload = {
                "contents": [{"parts": [{"text":
                    f"Translate to language code '{target_language}'. Return ONLY the translation:\n\n{text}"
                }]}],
                "generationConfig": {"temperature": 0.1, "maxOutputTokens": 3000},
            }
            data = _call_gemini(payload, timeout=20, prefer=FAST, no_think=True)
            out = data["candidates"][0]["content"]["parts"][0]["text"].strip()
            return {"translated_text": out, "target_language": target_language,
                    "source_language": source_language, "provider": "gemini"}
        except Exception as e:
            print(f"[translate] Gemini: {e}")

    return {"translated_text": f"[{target_language.upper()} MOCK] {text}",
            "target_language": target_language,
            "source_language": source_language, "provider": "mock"}
