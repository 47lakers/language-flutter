from __future__ import annotations
import asyncio
import edge_tts

def synthesize_mp3(text: str, voice: str) -> bytes:
    """
    Generate MP3 bytes using Edge TTS.
    """
    async def _run() -> bytes:
        communicate = edge_tts.Communicate(text=text, voice=voice)
        chunks = []
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                chunks.append(chunk["data"])
        return b"".join(chunks)

    return asyncio.run(_run())
