import os
import json
import time
import copy
import httpx

PREFERRED = [
    "gemini-3.5-flash-lite",
    "gemini-3.8-flash",
    "gemini-3.5-flash",
    "gemini-3.1-flash-lite",
    "gemini-2.5-flash-lite",
    "gemini-2.5-flash",
    "gemini-2.5-pro",
]

FAST = [
    "gemini-3.5-flash-lite",
    "gemini-2.5-flash-lite",
    "gemini-3.8-flash",
    "gemini-3.5-flash",
    "gemini-2.5-flash",
]

EXCLUDE = ("tts", "live", "image", "embedding", "imagen", "veo", "native-audio", "aqa")

_models_cache = None
_cache_at = 0.0
TTL = 3600.0

def _api_key():
    key = (os.getenv("GEMINI_API_KEY") or "").strip()
    if not key:
        raise RuntimeError("GEMINI_API_KEY missing in server-python/.env")
    return key

def discover_models():
    global _models_cache, _cache_at
    if _models_cache and time.time() - _cache_at < TTL:
        return _models_cache
    key = _api_key()
    try:
        with httpx.Client(timeout=10) as c:
            r = c.get("https://generativelanguage.googleapis.com/v1beta/models", params={"key": key})
        if r.status_code == 200:
            valid = []
            for m in r.json().get("models", []):
                if "generateContent" not in (m.get("supportedGenerationMethods") or []):
                    continue
                name = m.get("name", "").replace("models/", "")
                if any(x in name.lower() for x in EXCLUDE):
                    continue
                valid.append(name)
            ordered = [p for p in PREFERRED if p in valid] + [v for v in sorted(valid) if v not in PREFERRED]
            if ordered:
                _models_cache = ordered
                _cache_at = time.time()
                print(f"[gemini] discovered {len(ordered)}: {', '.join(ordered[:4])}")
                return ordered
    except Exception as e:
        print(f"[gemini] ListModels: {e}")
    return PREFERRED

def _supports_thinking(model: str) -> bool:
    return "2.5" in model or model.startswith("gemini-3")

def _call_gemini(payload: dict, timeout=30, prefer=None, no_think=False):
    global _models_cache
    key = _api_key()
    discovered = discover_models()

    if prefer:
        ordered = [m for m in prefer if m in discovered] + [m for m in discovered if m not in prefer]
    else:
        ordered = discovered

    last_err = ""
    for model in ordered:
        variations = [True, False] if (no_think and _supports_thinking(model)) else [False]

        for use_thinking in variations:
            p = copy.deepcopy(payload)
            if use_thinking:
                gc = p.setdefault("generationConfig", {})
                gc["thinkingConfig"] = {"thinkingBudget": 0}

            url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
            try:
                with httpx.Client(timeout=timeout) as client:
                    r = client.post(url, params={"key": key}, json=p)
            except httpx.TimeoutException:
                last_err = f"{model}: timeout {timeout}s"
                continue
            except Exception as e:
                last_err = f"{model}: {e}"
                continue

            if r.status_code == 200:
                _models_cache = [model] + [m for m in ordered if m != model]
                return r.json()

            body = r.text[:300]
            last_err = f"{model}{'+think' if use_thinking else ''}: HTTP {r.status_code} — {body}"

            if r.status_code in (401, 403):
                raise RuntimeError(f"Gemini auth error ({r.status_code}). Key rejected. Details: {body[:200]}")

            if r.status_code == 400:
                if use_thinking:
                    continue  # retry without thinkingConfig
                break  # next model

            if r.status_code in (404, 429):
                break  # next model
            if r.status_code == 503:
                time.sleep(1)
                continue
            break

    raise RuntimeError(f"All models failed. Last: {last_err}")

def chat(messages, context=None, language="en"):
    system_prompt = (
        "You are a friendly, concise tutor. Answer in 2-4 short paragraphs max. "
        "Use examples. Never say you are an AI."
    )
    if language and language != "en":
        system_prompt += f" Respond entirely in language '{language}'."
    if context:
        system_prompt += f"\n\nChapter context:\n{context[:6000]}"

    contents = [
        {"role": "user" if m.role == "user" else "model", "parts": [{"text": m.content}]}
        for m in messages
    ]
    payload = {
        "systemInstruction": {"parts": [{"text": system_prompt}]},
        "contents": contents,
        "generationConfig": {"temperature": 0.7, "maxOutputTokens": 500},
    }
    data = _call_gemini(payload, timeout=20, prefer=FAST, no_think=True)
    try:
        return data["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError):
        raise RuntimeError(f"Unexpected shape: {json.dumps(data)[:250]}")

def grade(question, user_answer, model_answer):
    prompt = f"""Grade this student's answer.

Question: {question}
Reference: {model_answer}
Student: {user_answer}

Return ONLY JSON: {{"correct": true|false, "feedback": "one short sentence"}}"""
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.1,
            "maxOutputTokens": 200,
            "responseMimeType": "application/json",
        },
    }
    try:
        data = _call_gemini(payload, timeout=15, prefer=FAST, no_think=True)
        return json.loads(data["candidates"][0]["content"]["parts"][0]["text"])
    except Exception:
        ok = user_answer.strip().lower() == str(model_answer).strip().lower()
        return {"correct": ok, "feedback": ""}
