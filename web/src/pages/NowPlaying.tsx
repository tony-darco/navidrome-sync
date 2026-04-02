import { useState, useEffect } from 'react';
import { useSyncStore } from '../store/syncStore';
import type { NowPlayingSong } from '../store/syncStore';
import { getCoverArtUrl } from '../api/navidrome';
import PlayHereButton from '../components/PlayHereButton';

function formatTime(secs: number) {
  const m = Math.floor(secs / 60);
  const s = Math.floor(secs % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}

export default function NowPlaying() {
  const nowPlaying = useSyncStore((s) => s.nowPlaying);
  const myRole = useSyncStore((s) => s.myRole);
  const lastSyncTime = useSyncStore((s) => s.lastSyncTime);

  if (!nowPlaying) {
    return (
      <div className="flex items-center justify-center h-full text-zinc-500 text-lg">
        Nothing playing
      </div>
    );
  }

  return myRole === 'active' ? (
    <ActiveView song={nowPlaying} />
  ) : (
    <ObserverView song={nowPlaying} lastSyncTime={lastSyncTime} />
  );
}

function ActiveView({ song }: { song: NowPlayingSong }) {
  const isPlaying = useSyncStore((s) => s.isPlaying);
  const position = useSyncStore((s) => s.position);
  const play = useSyncStore((s) => s.play);
  const pause = useSyncStore((s) => s.pause);
  const seek = useSyncStore((s) => s.seek);
  const next = useSyncStore((s) => s.next);
  const prev = useSyncStore((s) => s.prev);
  const [seekPos, setSeekPos] = useState<number | null>(null);

  return (
    <div className="flex flex-col items-center gap-6 p-6 max-w-md mx-auto">

      <img
        src={getCoverArtUrl(song.coverArtId, 600)}
        alt={`${song.album} cover`}
        className="w-72 h-72 rounded-lg shadow-lg object-cover bg-zinc-800"
      />

      <div className="text-center">
        <h2 className="text-xl font-semibold">{song.title}</h2>
        <p className="text-zinc-400">{song.artist}</p>
        <p className="text-zinc-500 text-sm">{song.album}</p>
      </div>

      {/* Seek bar */}
      <div className="w-full flex items-center gap-2">
        <span className="text-xs text-zinc-500 tabular-nums w-10 text-right">
          {formatTime(seekPos ?? position)}
        </span>
        <input
          type="range"
          min={0}
          max={song.durationSecs}
          value={seekPos ?? position}
          onChange={(e) => setSeekPos(Number(e.target.value))}
          onMouseDown={() => setSeekPos(position)}
          onMouseUp={(e) => { seek(Number((e.target as HTMLInputElement).value)); setSeekPos(null); }}
          onTouchStart={() => setSeekPos(position)}
          onTouchEnd={(e) => { seek(Number((e.target as HTMLInputElement).value)); setSeekPos(null); }}
          className="flex-1 accent-green-500"
        />
        <span className="text-xs text-zinc-500 tabular-nums w-10">
          {formatTime(song.durationSecs)}
        </span>
      </div>

      {/* Transport controls */}
      <div className="flex items-center gap-6">
        <button
          onClick={prev}
          className="text-zinc-400 hover:text-white transition-colors"
          aria-label="Previous"
        >
          <svg className="w-8 h-8" viewBox="0 0 24 24" fill="currentColor"><path d="M6 6h2v12H6zm3.5 6l8.5 6V6z" /></svg>
        </button>
        <button
          onClick={isPlaying ? pause : play}
          className="w-14 h-14 rounded-full bg-white text-black flex items-center justify-center hover:scale-105 transition-transform"
          aria-label={isPlaying ? 'Pause' : 'Play'}
        >
          {isPlaying ? (
            <svg className="w-7 h-7" viewBox="0 0 24 24" fill="currentColor"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z" /></svg>
          ) : (
            <svg className="w-7 h-7 ml-1" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z" /></svg>
          )}
        </button>
        <button
          onClick={next}
          className="text-zinc-400 hover:text-white transition-colors"
          aria-label="Next"
        >
          <svg className="w-8 h-8" viewBox="0 0 24 24" fill="currentColor"><path d="M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z" /></svg>
        </button>
      </div>

      <span className="text-xs text-green-500 font-medium">Active Client</span>
    </div>
  );
}

function ObserverView({
  song,
  lastSyncTime,
}: {
  song: NowPlayingSong;
  lastSyncTime: number;
}) {
  const [interpolatedPos, setInterpolatedPos] = useState(song.positionSecs);

  // Interpolate position locally
  useEffect(() => {
    setInterpolatedPos(song.positionSecs);
    const interval = setInterval(() => {
      setInterpolatedPos((prev) => {
        const next = prev + 1;
        return next > song.durationSecs ? song.durationSecs : next;
      });
    }, 1000);
    return () => clearInterval(interval);
  }, [song.positionSecs, song.durationSecs, lastSyncTime]);

  return (
    <div className="flex flex-col items-center gap-6 p-6 max-w-md mx-auto">
      <img
        src={getCoverArtUrl(song.coverArtId, 600)}
        alt={`${song.album} cover`}
        className="w-72 h-72 rounded-lg shadow-lg object-cover bg-zinc-800"
      />

      <div className="text-center">
        <h2 className="text-xl font-semibold">{song.title}</h2>
        <p className="text-zinc-400">{song.artist}</p>
        <p className="text-zinc-500 text-sm">{song.album}</p>
      </div>

      {/* Read-only progress bar */}
      <div className="w-full flex items-center gap-2">
        <span className="text-xs text-zinc-500 tabular-nums w-10 text-right">
          {formatTime(interpolatedPos)}
        </span>
        <div className="flex-1 h-1 bg-zinc-800 rounded-full overflow-hidden">
          <div
            className="h-full bg-zinc-500 rounded-full transition-all duration-1000"
            style={{ width: `${(interpolatedPos / song.durationSecs) * 100}%` }}
          />
        </div>
        <span className="text-xs text-zinc-500 tabular-nums w-10">
          {formatTime(song.durationSecs)}
        </span>
      </div>

      <PlayHereButton />

      <span className="text-xs text-zinc-500">Observing</span>
    </div>
  );
}
