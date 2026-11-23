import os

def synthesize(text: str, language: str = "en"):
    """
    Return audio bytes if a provider is configured, else None.
    None tells the frontend to use Web Speech API.
    """
    if not os.getenv("TTS_API_KEY"):
        return None
    # Wire a real provider here (Deepgram, ElevenLabs, Google TTS).
    return None
