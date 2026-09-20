// Audio alert utility for new incoming orders in Admin Panel

const SOUND_PREF_KEY = 'qc-order-alert-sound-enabled';

// Shared AudioContext for synthesizer fallback
let sharedAudioCtx: AudioContext | null = null;

function getAudioContext(): AudioContext | null {
  if (typeof window === 'undefined') return null;
  if (!sharedAudioCtx) {
    const AudioCtx = window.AudioContext || (window as any).webkitAudioContext;
    if (AudioCtx) {
      sharedAudioCtx = new AudioCtx();
    }
  }
  return sharedAudioCtx;
}

// Automatically unlock audio context on user's first click or keypress
if (typeof window !== 'undefined') {
  const unlockAudio = () => {
    const ctx = getAudioContext();
    if (ctx && ctx.state === 'suspended') {
      ctx.resume();
    }
    // Also unlock HTML5 Audio element
    try {
      const silentAudio = new Audio();
      silentAudio.src = 'data:audio/wav;base64,UklGRigAAABXQVZFZm10IBIAAAABAAEARKwAAIhYAQACABAAAABkYXRhAgAAAAEA';
      silentAudio.volume = 0.01;
      silentAudio.play().catch(() => {});
    } catch {}

    window.removeEventListener('click', unlockAudio);
    window.removeEventListener('keydown', unlockAudio);
    window.removeEventListener('touchstart', unlockAudio);
  };

  window.addEventListener('click', unlockAudio, { passive: true });
  window.addEventListener('keydown', unlockAudio, { passive: true });
  window.addEventListener('touchstart', unlockAudio, { passive: true });
}

export function isOrderSoundEnabled(): boolean {
  if (typeof window === 'undefined') return true;
  const val = localStorage.getItem(SOUND_PREF_KEY);
  return val === null ? true : val === 'true';
}

export function setOrderSoundEnabled(enabled: boolean): void {
  if (typeof window === 'undefined') return;
  localStorage.setItem(SOUND_PREF_KEY, String(enabled));
  window.dispatchEvent(new CustomEvent('qc-order-sound-pref-changed', { detail: enabled }));
}

// Fallback high-fidelity synthesizer using Web Audio API (3-tone alert chime)
function playSynthesizedAlertChime(): void {
  try {
    const ctx = getAudioContext();
    if (!ctx) return;
    if (ctx.state === 'suspended') {
      ctx.resume();
    }

    const now = ctx.currentTime;

    const playTone = (freq: number, start: number, duration: number, gainVal: number) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = 'triangle'; // Crisp and pleasant chime timbre
      osc.frequency.setValueAtTime(freq, start);

      gain.gain.setValueAtTime(0, start);
      gain.gain.linearRampToValueAtTime(gainVal, start + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(start);
      osc.stop(start + duration);
    };

    // Upbeat 3-note notification chime: E5 (659Hz) -> B5 (987Hz) -> E6 (1318Hz)
    playTone(659.25, now, 0.28, 0.4);
    playTone(987.77, now + 0.16, 0.32, 0.5);
    playTone(1318.51, now + 0.34, 0.6, 0.6);
  } catch (err) {
    console.warn('Web Audio synthesis error:', err);
  }
}

/**
 * Plays the new order alert sound (WAV audio with Web Audio API fallback).
 * Respects user mute/unmute preference.
 */
export async function playOrderAlertSound(force = false): Promise<boolean> {
  if (!force && !isOrderSoundEnabled()) {
    return false;
  }

  // Attempt playing the dedicated WAV sound file first
  try {
    const audio = new Audio('/order_alert.wav');
    audio.volume = 1.0;
    const playPromise = audio.play();
    if (playPromise !== undefined) {
      await playPromise;
      return true;
    }
  } catch (err) {
    // If blocked by browser autoplay policy or file error, try Web Audio API
    playSynthesizedAlertChime();
    return true;
  }

  return true;
}
