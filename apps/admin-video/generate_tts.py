import asyncio
import os
import edge_tts

VOICE = "en-GB-RyanNeural"
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "public", "audio")

SCRIPTS = {
    "scene_1_intro.mp3": "Introducing QuickComm — your all-in-one supermarket management platform. Built for speed, built for scale.",
    "scene_2_dashboard.mp3": "The supermarket dashboard gives you a real-time pulse of your operations — tracking daily GMV, order volume, sales activity trends, and catalog health at a glance.",
    "scene_3_orders.mp3": "The live orders pipeline streamlines fulfillment — monitor incoming orders, track preparation, and assign delivery riders with a single click.",
    "scene_4_products.mp3": "Full catalog control at your fingertips — search items, monitor stock alerts, toggle instant availability, and manage pricing in real time.",
    "scene_5_fleet.mp3": "Fleet tracking maps active riders across your five-kilometer delivery zone in real time, keeping dispatches and customer drop-offs on schedule.",
    "scene_6_settings.mp3": "Store settings empower managers to set GPS coordinates, enforce radial delivery boundaries, and customize free delivery rules without code.",
    "scene_7_outro.mp3": "QuickComm. Manage everything from one place. Deliver faster. Grow smarter.",
}

async def generate_all():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"Generating {len(SCRIPTS)} voiceover files using voice: {VOICE}")
    
    for filename, text in SCRIPTS.items():
        filepath = os.path.join(OUTPUT_DIR, filename)
        print(f"Generating {filename}...")
        communicate = edge_tts.Communicate(text, VOICE, rate="+0%", pitch="+0Hz")
        await communicate.save(filepath)
        size = os.path.getsize(filepath)
        print(f"  [OK] Saved {filename} ({size} bytes)")

    print("\nAll audio clips generated successfully!")

if __name__ == "__main__":
    asyncio.run(generate_all())
