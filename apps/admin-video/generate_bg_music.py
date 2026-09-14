import math
import struct
import wave
import os

SAMPLE_RATE = 44100
BPM = 120
BEAT_DUR = 60.0 / BPM  # 0.5s per beat
BAR_DUR = BEAT_DUR * 4  # 2.0s per bar

# 8-bar progression repeated twice = 16 bars = 32.0 seconds
TOTAL_BARS = 16
DURATION = TOTAL_BARS * BAR_DUR  # 32.0s
NUM_SAMPLES = int(SAMPLE_RATE * DURATION)

# Chord progression in D Major (bright & uplifting):
# Dmaj -> A -> Bm -> G
# D3: 146.83, A2: 110.00, B2: 123.47, G2: 98.00
PROGRESSION = [
    # Bar 1 & 2: D Major (D, F#, A, D)
    {"root": 146.83, "chord": [293.66, 369.99, 440.00, 587.33], "arp": [587.33, 440.00, 739.99, 440.00, 880.00, 739.99, 587.33, 440.00]},
    # Bar 3 & 4: A Major (A, C#, E, A)
    {"root": 110.00, "chord": [220.00, 277.18, 329.63, 440.00], "arp": [440.00, 329.63, 554.37, 329.63, 659.25, 554.37, 440.00, 329.63]},
    # Bar 5 & 6: B Minor (B, D, F#, B)
    {"root": 123.47, "chord": [246.94, 293.66, 369.99, 493.88], "arp": [493.88, 369.99, 587.33, 369.99, 739.99, 587.33, 493.88, 369.99]},
    # Bar 7 & 8: G Major (G, B, D, G)
    {"root": 98.00, "chord": [196.00, 246.94, 293.66, 392.00], "arp": [392.00, 293.66, 493.88, 293.66, 587.33, 493.88, 392.00, 293.66]},
]

def synthesize_uplifting():
    out_dir = os.path.join(os.path.dirname(__file__), "public", "audio")
    os.makedirs(out_dir, exist_ok=True)
    wav_path = os.path.join(out_dir, "bg_music.wav")
    
    print("Synthesizing uplifting corporate tech background track (120 BPM)...")
    
    left = [0.0] * NUM_SAMPLES
    right = [0.0] * NUM_SAMPLES
    
    # 1. Bouncy Bassline (8th notes on root with octave jumps)
    for bar in range(TOTAL_BARS):
        chord_info = PROGRESSION[(bar // 2) % len(PROGRESSION)]
        root = chord_info["root"]
        bar_start_s = bar * BAR_DUR
        
        for step in range(8):  # 8 eighth-notes per bar
            t_start = bar_start_s + (step * (BEAT_DUR / 2))
            freq = root if step % 2 == 0 else root * 2.0
            
            # Note duration: 0.18s
            note_len = int(0.18 * SAMPLE_RATE)
            start_idx = int(t_start * SAMPLE_RATE)
            
            for i in range(note_len):
                idx = start_idx + i
                if idx >= NUM_SAMPLES:
                    break
                t = i / SAMPLE_RATE
                env = math.exp(-14.0 * t)  # punchy decay
                # Bass tone: fundamental + warm sub
                sig = 0.7 * math.sin(2 * math.pi * freq * t) + 0.3 * math.sin(4 * math.pi * freq * t)
                val = sig * env * 0.35
                left[idx] += val
                right[idx] += val

    # 2. Bright Kalimba / Pluck Arpeggio (16th notes dancing on top)
    for bar in range(TOTAL_BARS):
        chord_info = PROGRESSION[(bar // 2) % len(PROGRESSION)]
        arp_pattern = chord_info["arp"]
        bar_start_s = bar * BAR_DUR
        
        for step in range(16):  # 16 sixteenth-notes per bar
            freq = arp_pattern[step % len(arp_pattern)]
            t_start = bar_start_s + (step * (BEAT_DUR / 4))
            
            note_len = int(0.22 * SAMPLE_RATE)
            start_idx = int(t_start * SAMPLE_RATE)
            
            pan = 0.35 * math.sin(step * 1.2)  # subtle stereo movement
            
            for i in range(note_len):
                idx = start_idx + i
                if idx >= NUM_SAMPLES:
                    break
                t = i / SAMPLE_RATE
                env = math.exp(-18.0 * t)
                # Bell/Kalimba timbre: fundamental + pure 3rd and 5th harmonics
                sig = (
                    0.60 * math.sin(2 * math.pi * freq * t) +
                    0.28 * math.sin(6 * math.pi * freq * t) +
                    0.12 * math.sin(10 * math.pi * freq * t)
                )
                val = sig * env * 0.22
                left[idx] += val * (0.5 - pan)
                right[idx] += val * (0.5 + pan)

    # 3. Warm Acoustic/Rhodes Chords on Upbeats (Joyful bounce on beats 2 & 4)
    for bar in range(TOTAL_BARS):
        chord_info = PROGRESSION[(bar // 2) % len(PROGRESSION)]
        chord = chord_info["chord"]
        bar_start_s = bar * BAR_DUR
        
        # Upbeats on 2 and 4
        for beat in [1, 3]:
            t_start = bar_start_s + beat * BEAT_DUR
            note_len = int(0.35 * SAMPLE_RATE)
            start_idx = int(t_start * SAMPLE_RATE)
            
            for i in range(note_len):
                idx = start_idx + i
                if idx >= NUM_SAMPLES:
                    break
                t = i / SAMPLE_RATE
                env = math.exp(-7.0 * t)
                
                sig_l = 0.0
                sig_r = 0.0
                for n_idx, freq in enumerate(chord):
                    tone = math.sin(2 * math.pi * freq * t) + 0.2 * math.sin(4 * math.pi * freq * t)
                    sig_l += tone * (0.8 if n_idx % 2 == 0 else 0.4)
                    sig_r += tone * (0.4 if n_idx % 2 == 0 else 0.8)
                    
                gain = (0.16 / len(chord)) * env
                left[idx] += sig_l * gain
                right[idx] += sig_r * gain

    # 4. Subtle, Crisp Rhythm (Soft Kick on 1 & 3, Soft Snare/Clap on 2 & 4, Shaker on 16ths)
    import random
    rng = random.Random(42)
    
    for bar in range(TOTAL_BARS):
        bar_start_s = bar * BAR_DUR
        
        for beat in range(4):
            t_beat = bar_start_s + beat * BEAT_DUR
            start_idx = int(t_beat * SAMPLE_RATE)
            
            # Kick on beats 0 and 2
            if beat in [0, 2]:
                kick_len = int(0.12 * SAMPLE_RATE)
                for i in range(kick_len):
                    idx = start_idx + i
                    if idx >= NUM_SAMPLES:
                        break
                    t = i / SAMPLE_RATE
                    # Pitch-drop sine (110Hz -> 45Hz)
                    k_freq = 110.0 * math.exp(-35.0 * t) + 45.0
                    k_env = math.exp(-18.0 * t)
                    val = math.sin(2 * math.pi * k_freq * t) * k_env * 0.30
                    left[idx] += val
                    right[idx] += val
                    
            # Soft rim/snare on beats 1 and 3
            if beat in [1, 3]:
                snare_len = int(0.10 * SAMPLE_RATE)
                for i in range(snare_len):
                    idx = start_idx + i
                    if idx >= NUM_SAMPLES:
                        break
                    t = i / SAMPLE_RATE
                    s_env = math.exp(-22.0 * t)
                    noise = (rng.random() * 2.0 - 1.0) * s_env * 0.12
                    tone = math.sin(2 * math.pi * 200.0 * t) * s_env * 0.10
                    val = noise + tone
                    left[idx] += val
                    right[idx] += val
                    
            # 16th-note Shaker / Hi-Hat
            for step in range(4):
                t_shaker = t_beat + step * (BEAT_DUR / 4)
                shk_idx = int(t_shaker * SAMPLE_RATE)
                shk_len = int(0.04 * SAMPLE_RATE)
                accent = 1.3 if step == 2 else 0.7
                for i in range(shk_len):
                    idx = shk_idx + i
                    if idx >= NUM_SAMPLES:
                        break
                    t = i / SAMPLE_RATE
                    h_env = math.exp(-60.0 * t)
                    noise = (rng.random() * 2.0 - 1.0) * h_env * 0.05 * accent
                    left[idx] += noise * 0.7
                    right[idx] += noise * 0.9

    # Normalize to -1 dB and write 16-bit stereo WAV
    max_val = max(max(abs(x) for x in left), max(abs(x) for x in right), 0.001)
    scale = 27000.0 / max_val
    
    with wave.open(wav_path, "wb") as wav_file:
        wav_file.setnchannels(2)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        
        frames = bytearray()
        for i in range(NUM_SAMPLES):
            sl = int(max(-32767, min(32767, left[i] * scale)))
            sr = int(max(-32767, min(32767, right[i] * scale)))
            frames.extend(struct.pack("<hh", sl, sr))
            
        wav_file.writeframes(frames)
        
    print(f"Successfully generated uplifting background track: {wav_path} ({len(frames)} bytes)")

if __name__ == "__main__":
    synthesize_uplifting()
