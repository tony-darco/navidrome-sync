import { useEffect, useRef, useState } from 'react';
import { getCrateColor as _getCrateColor, type CrateColor, CRATE_COLORS } from '../styles/design-system';
import { useSyncStore } from '../store/syncStore';

// Re-export for convenience so callers can import from one place
export { getCrateColor } from '../styles/design-system';

// Global crate color override (-1 = auto, 0-5 = fixed index)
let _overrideIndex: number = -1;
const _listeners = new Set<() => void>();

export function setCrateOverride(index: number) {
  _overrideIndex = index;
  _listeners.forEach((l) => l());
}

export function clearCrateOverride() {
  _overrideIndex = -1;
  _listeners.forEach((l) => l());
}

export function getCrateOverride(): number {
  return _overrideIndex;
}

/**
 * Returns the current crate color, transitioning with animation when the
 * playing track changes. Respects a global manual override.
 */
export function useCrateColor(): CrateColor {
  const albumId = useSyncStore((s) => s.nowPlaying?.albumId ?? '');
  const [crate, setCrate] = useState<CrateColor>(() =>
    _overrideIndex >= 0 ? CRATE_COLORS[_overrideIndex] : _getCrateColor(albumId || 'a')
  );
  const frameRef = useRef<number | null>(null);

  const update = () => {
    const next =
      _overrideIndex >= 0
        ? CRATE_COLORS[_overrideIndex]
        : _getCrateColor(albumId || 'a');
    // Schedule update in next frame so the CSS transition can fire
    if (frameRef.current !== null) cancelAnimationFrame(frameRef.current);
    frameRef.current = requestAnimationFrame(() => setCrate(next));
  };

  useEffect(() => {
    update();
    _listeners.add(update);
    return () => {
      _listeners.delete(update);
      if (frameRef.current !== null) cancelAnimationFrame(frameRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [albumId]);

  return crate;
}
