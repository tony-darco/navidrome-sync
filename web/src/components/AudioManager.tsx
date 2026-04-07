import { useEffect } from 'react';
import { useSyncStore } from '../store/syncStore';
import { scrobble as apiScrobble } from '../api/navidrome';

/**
 * Invisible component that lives in App — keeps the persistent audio element
 * reporting position to the hub while the active client is playing.
 */
export default function AudioManager() {
  const myRole = useSyncStore((s) => s.myRole);
  const sendPositionUpdate = useSyncStore((s) => s.sendPositionUpdate);
  const getAudio = useSyncStore((s) => s.getAudio);
  const nowPlaying = useSyncStore((s) => s.nowPlaying);
  const playSong = useSyncStore((s) => s.playSong);

  // When song changes from hub (e.g. poll), load new stream if we're active
  const songId = nowPlaying?.songId;
  useEffect(() => {
    if (myRole !== 'active' || !songId) return;
    const audio = getAudio();
    // Only reload if the audio src doesn't already match this song
    if (audio.src && audio.src.includes(songId)) return;
    if (nowPlaying) {
      playSong(nowPlaying);
    }
  }, [songId, myRole, getAudio, nowPlaying, playSong]);

  // Report position to hub every ~1s while active and playing
  useEffect(() => {
    if (myRole !== 'active') return;
    const interval = setInterval(() => {
      const audio = getAudio();
      if (!audio.paused) {
        sendPositionUpdate(audio.currentTime);
        // Scrobble at 50% of song duration
        const { nowPlaying: np, scrobbledSongId } = useSyncStore.getState();
        if (np && scrobbledSongId !== np.songId && np.durationSecs > 0 && audio.currentTime >= np.durationSecs / 2) {
          useSyncStore.setState({ scrobbledSongId: np.songId });
          apiScrobble(np.songId).catch(() => {});
        }
      }
    }, 1000);
    return () => clearInterval(interval);
  }, [myRole, getAudio, sendPositionUpdate]);

  return null;
}
