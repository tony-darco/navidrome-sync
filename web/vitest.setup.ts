import { vi } from 'vitest';

// Stub HTMLAudioElement before any store module is imported.
// The store creates `const audio = new Audio()` at module load time; this
// mock ensures play/pause/src are controllable in tests and don't throw.
export const mockAudio = {
  play: vi.fn().mockResolvedValue(undefined),
  pause: vi.fn(),
  src: '',
  currentTime: 0,
  addEventListener: vi.fn(),
  removeEventListener: vi.fn(),
  dispatchEvent: vi.fn(),
};

// Must be a class so `new Audio()` works as a constructor.
class MockAudio {
  play = mockAudio.play;
  pause = mockAudio.pause;
  addEventListener = mockAudio.addEventListener;
  removeEventListener = mockAudio.removeEventListener;
  dispatchEvent = mockAudio.dispatchEvent;
  get src() { return mockAudio.src; }
  set src(v: string) { mockAudio.src = v; }
  get currentTime() { return mockAudio.currentTime; }
  set currentTime(v: number) { mockAudio.currentTime = v; }
}

vi.stubGlobal('Audio', MockAudio);
