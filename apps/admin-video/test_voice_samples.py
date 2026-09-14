import asyncio
import os
import edge_tts

TEXT = "Introducing QuickComm — your all-in-one supermarket management platform. Built for speed, built for scale."

SAMPLES = {
    "sample_neerja_expressive.mp3": "en-IN-NeerjaExpressiveNeural",
    "sample_neerja.mp3": "en-IN-NeerjaNeural",
    "sample_christopher_us.mp3": "en-US-ChristopherNeural",
    "sample_guy_us.mp3": "en-US-GuyNeural",
    "sample_jenny_us.mp3": "en-US-JennyNeural",
    "sample_ryan_gb.mp3": "en-GB-RyanNeural",
}

async def generate_samples():
    out_dir = os.path.join(os.path.dirname(__file__), "public", "audio", "samples")
    os.makedirs(out_dir, exist_ok=True)
    
    for filename, voice in SAMPLES.items():
        filepath = os.path.join(out_dir, filename)
        communicate = edge_tts.Communicate(TEXT, voice)
        await communicate.save(filepath)
        print(f"Generated {filename} ({voice})")

if __name__ == "__main__":
    asyncio.run(generate_samples())
