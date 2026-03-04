"""Generate simple notification sound WAV files."""
import wave, struct, math, os

SAMPLE_RATE = 44100

def write_tone(filename, freqs_durations, volume=0.5, fade_ms=20):
    """Write a WAV file with a sequence of tones."""
    samples = []
    for freq, duration_ms in freqs_durations:
        n_samples = int(SAMPLE_RATE * duration_ms / 1000)
        fade_samples = int(SAMPLE_RATE * fade_ms / 1000)
        for i in range(n_samples):
            t = i / SAMPLE_RATE
            val = volume * math.sin(2 * math.pi * freq * t)
            if i < fade_samples:
                val *= i / fade_samples
            elif i > n_samples - fade_samples:
                val *= (n_samples - i) / fade_samples
            samples.append(val)
        silence = int(SAMPLE_RATE * 0.03)
        samples.extend([0] * silence)

    with wave.open(filename, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        for s in samples:
            w.writeframes(struct.pack('<h', int(s * 32767)))

RAW_DIR = os.path.join(
    r"d:\06_All_Coding_Related_Stuff\04_Antigravity_Projects\02_personal_flutter_apps\01_Habit_tracker",
    "android", "app", "src", "main", "res", "raw"
)
os.makedirs(RAW_DIR, exist_ok=True)

write_tone(os.path.join(RAW_DIR, "gentle_chime.wav"), [(880, 150), (1047, 200)], volume=0.4)
write_tone(os.path.join(RAW_DIR, "soft_ping.wav"), [(1200, 180)], volume=0.35)
write_tone(os.path.join(RAW_DIR, "double_tap.wav"), [(800, 80), (800, 80)], volume=0.4)
write_tone(os.path.join(RAW_DIR, "rising_bell.wav"), [(660, 120), (880, 120), (1047, 180)], volume=0.35)
write_tone(os.path.join(RAW_DIR, "bright_alert.wav"), [(1047, 100), (1319, 200)], volume=0.4)

print("Generated 5 notification sounds!")
