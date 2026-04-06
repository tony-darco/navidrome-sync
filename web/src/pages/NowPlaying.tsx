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
  const showQueue = useSyncStore((s) => s.showQueue);

  if (!nowPlaying) {
    return (
      <div className="flex items-center justify-center h-full text-zinc-500 text-lg">
        Nothing playing
      </div>
    );
  }

  if (showQueue) {
    return <QueueView isActive={myRole === 'active'} />;
  }

  return myRole === 'active' ? (
    <ActiveView song={nowPlaying} />
  ) : (
    <ObserverView song={nowPlaying} lastSyncTime={lastSyncTime} />
  );
}

/* ─── Queue icon button (used in both views) ─── */
function QueueButton() {
  const showQueue = useSyncStore((s) => s.showQueue);
  const setShowQueue = useSyncStore((s) => s.setShowQueue);
  return (
    <button
      onClick={() => setShowQueue(!showQueue)}
      className={`transition-colors ${showQueue ? 'text-blue-500' : 'text-zinc-500 hover:text-white'}`}
      aria-label="Queue"
      title="Queue"
    >
      <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
        <path d="M15 6H3v2h12V6zm0 4H3v2h12v-2zM3 16h8v-2H3v2zM17 6v8.18c-.31-.11-.65-.18-1-.18-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3V8h3V6h-5z" />
      </svg>
    </button>
  );
}

/* ─── Full-page Queue View ─── */
function QueueView({ isActive }: { isActive: boolean }) {
  const queue = useSyncStore((s) => s.queue);
  const queueIndex = useSyncStore((s) => s.queueIndex);
  const nowPlaying = useSyncStore((s) => s.nowPlaying);
  const setShowQueue = useSyncStore((s) => s.setShowQueue);
  const playQueueIndex = useSyncStore((s) => s.playQueueIndex);
  const removeFromQueue = useSyncStore((s) => s.removeFromQueue);
  const clearQueue = useSyncStore((s) => s.clearQueue);

  const upNext = queue.filter((_, i) => i > queueIndex);

  return (
    <div className="p-4 max-w-2xl mx-auto">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <button
          onClick={() => setShowQueue(false)}
          className="text-sm text-zinc-400 hover:text-white flex items-center gap-1"
        >
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
            <path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z" />
          </svg>
          Back
        </button>
        <h2 className="text-lg font-semibold">Queue</h2>
        <div className="w-12" />
      </div>

      {/* Now Playing */}
      {nowPlaying && (
        <div className="mb-6">
          <h3 className="text-xs font-medium text-zinc-500 uppercase tracking-wider mb-3">Now Playing</h3>
          <div className="flex items-center gap-3 py-2 px-2 bg-zinc-800/60 rounded-lg">
            <img
              src={getCoverArtUrl(nowPlaying.coverArtId, 80)}
              alt=""
              className="w-12 h-12 rounded object-cover bg-zinc-800 flex-shrink-0"
            />
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-blue-500 truncate">{nowPlaying.title}</p>
              <p className="text-xs text-zinc-400 truncate">{nowPlaying.artist}</p>
            </div>
            <span className="text-xs text-zinc-500 truncate hidden sm:block max-w-[120px]">{nowPlaying.album}</span>
            <span className="text-xs text-zinc-600 tabular-nums flex-shrink-0">
              {formatTime(nowPlaying.durationSecs)}
            </span>
          </div>
        </div>
      )}

      {/* Next in queue */}
      <div>
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-xs font-medium text-zinc-500 uppercase tracking-wider">Next in queue</h3>
          {isActive && upNext.length > 0 && (
            <button
              onClick={clearQueue}
              className="text-xs font-medium text-zinc-400 hover:text-white border border-zinc-700 hover:border-zinc-500 rounded px-3 py-1 uppercase tracking-wider transition-colors"
            >
              Clear queue
            </button>
          )}
        </div>

        {upNext.length === 0 ? (
          <p className="text-zinc-600 text-sm py-4 text-center">Queue is empty</p>
        ) : (
          <div className="space-y-0.5">
            {upNext.map((item, i) => {
              const realIndex = queueIndex + 1 + i;
              return (
                <div
                  key={`${item.songId}-${realIndex}`}
                  className="flex items-center gap-3 py-2.5 px-2 rounded-lg hover:bg-zinc-800/40 transition-colors group"
                >
                  <span className="w-6 text-right text-xs text-zinc-600 tabular-nums flex-shrink-0">
                    {i + 1}
                  </span>
                  {isActive ? (
                    <button
                      onClick={() => playQueueIndex(realIndex)}
                      className="flex items-center gap-3 flex-1 min-w-0 text-left"
                    >
                      <img
                        src={getCoverArtUrl(item.coverArtId, 80)}
                        alt=""
                        className="w-10 h-10 rounded object-cover bg-zinc-800 flex-shrink-0"
                      />
                      <div className="flex-1 min-w-0">
                        <p className="text-sm truncate">{item.title}</p>
                        <p className="text-xs text-zinc-500 truncate">{item.artist}</p>
                      </div>
                    </button>
                  ) : (
                    <div className="flex items-center gap-3 flex-1 min-w-0">
                      <img
                        src={getCoverArtUrl(item.coverArtId, 80)}
                        alt=""
                        className="w-10 h-10 rounded object-cover bg-zinc-800 flex-shrink-0"
                      />
                      <div className="flex-1 min-w-0">
                        <p className="text-sm truncate">{item.title}</p>
                        <p className="text-xs text-zinc-500 truncate">{item.artist}</p>
                      </div>
                    </div>
                  )}
                  <span className="text-xs text-zinc-500 truncate hidden sm:block max-w-[120px] flex-shrink-0">
                    {item.album}
                  </span>
                  <span className="text-xs text-zinc-600 tabular-nums flex-shrink-0">
                    {formatTime(item.durationSecs)}
                  </span>
                  {isActive && (
                    <button
                      onClick={() => removeFromQueue(realIndex)}
                      className="text-zinc-700 hover:text-red-400 transition-colors flex-shrink-0 opacity-0 group-hover:opacity-100"
                      aria-label="Remove from queue"
                    >
                      <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
                        <path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z" />
                      </svg>
                    </button>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}

/* ─── Active Client View ─── */
function ActiveView({ song }: { song: NowPlayingSong }) {
  const isPlaying = useSyncStore((s) => s.isPlaying);
  const position = useSyncStore((s) => s.position);
  const play = useSyncStore((s) => s.play);
  const pause = useSyncStore((s) => s.pause);
  const seek = useSyncStore((s) => s.seek);
  const next = useSyncStore((s) => s.next);
  const prev = useSyncStore((s) => s.prev);
  const shuffle = useSyncStore((s) => s.shuffle);
  const repeatMode = useSyncStore((s) => s.repeatMode);
  const toggleShuffle = useSyncStore((s) => s.toggleShuffle);
  const cycleRepeatMode = useSyncStore((s) => s.cycleRepeatMode);
  const [seekPos, setSeekPos] = useState<number | null>(null);

  return (
    <div className="flex flex-col items-center justify-center gap-4 p-6 w-full max-w-xl mx-auto h-full overflow-hidden">

      <img
        src={getCoverArtUrl(song.coverArtId, 600)}
        alt={`${song.album} cover`}
        className="w-48 h-48 sm:w-64 sm:h-64 md:w-72 md:h-72 rounded-lg shadow-lg object-cover bg-zinc-800 flex-shrink-0"
      />

      <div className="text-center w-full px-4 flex-shrink-0">
        <h2 className="text-xl sm:text-2xl font-bold truncate">{song.title}</h2>
        <p className="text-base sm:text-lg text-zinc-400 truncate mt-0.5">{song.artist}</p>
        <p className="text-sm text-zinc-500 truncate">{song.album}</p>
      </div>

      {/* Seek bar */}
      <div className="w-full flex items-center gap-2 flex-shrink-0">
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
          className="flex-1 accent-blue-500"
        />
        <span className="text-xs text-zinc-500 tabular-nums w-10">
          {formatTime(song.durationSecs)}
        </span>
      </div>

      {/* Transport controls */}
      <div className="flex items-center gap-6 sm:gap-8 flex-shrink-0">
        {/* Shuffle */}
        <button
          onClick={toggleShuffle}
          className={`transition-colors ${shuffle ? 'text-blue-500' : 'text-zinc-500 hover:text-white'}`}
          aria-label="Shuffle"
          title="Shuffle"
        >
          <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
            <path d="M10.59 9.17L5.41 4 4 5.41l5.17 5.17 1.42-1.41zM14.5 4l2.04 2.04L4 18.59 5.41 20 17.96 7.46 20 9.5V4h-5.5zm.33 9.41l-1.41 1.41 3.13 3.13L14.5 20H20v-5.5l-2.04 2.04-3.13-3.13z" />
          </svg>
        </button>

        <button
          onClick={() => prev()}
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
          onClick={() => next()}
          className="text-zinc-400 hover:text-white transition-colors"
          aria-label="Next"
        >
          <svg className="w-8 h-8" viewBox="0 0 24 24" fill="currentColor"><path d="M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z" /></svg>
        </button>

        {/* Repeat */}
        <button
          onClick={cycleRepeatMode}
          className={`relative transition-colors ${repeatMode !== 'off' ? 'text-blue-500' : 'text-zinc-500 hover:text-white'}`}
          aria-label={`Repeat: ${repeatMode}`}
          title={`Repeat: ${repeatMode}`}
        >
          <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
            <path d="M7 7h10v3l4-4-4-4v3H5v6h2V7zm10 10H7v-3l-4 4 4 4v-3h12v-6h-2v4z" />
          </svg>
          {repeatMode === 'one' && (
            <span className="absolute -top-1 -right-1 text-[9px] font-bold text-blue-500">1</span>
          )}
        </button>
      </div>

      <div className="flex items-center gap-4 flex-shrink-0">
        <span className="text-xs text-blue-500 font-medium">Active Client</span>
        <QueueButton />
      </div>
    </div>
  );
}

/* ─── Observer View ─── */
function ObserverView({
  song,
  lastSyncTime,
}: {
  song: NowPlayingSong;
  lastSyncTime: number;
}) {
  const isPlaying = useSyncStore((s) => s.isPlaying);
  const play = useSyncStore((s) => s.play);
  const pause = useSyncStore((s) => s.pause);
  const prev = useSyncStore((s) => s.prev);
  const next = useSyncStore((s) => s.next);
  const shuffle = useSyncStore((s) => s.shuffle);
  const repeatMode = useSyncStore((s) => s.repeatMode);
  const toggleShuffle = useSyncStore((s) => s.toggleShuffle);
  const cycleRepeatMode = useSyncStore((s) => s.cycleRepeatMode);
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
    <div className="flex flex-col items-center justify-center gap-4 p-6 w-full max-w-xl mx-auto h-full overflow-hidden">
      <img
        src={getCoverArtUrl(song.coverArtId, 600)}
        alt={`${song.album} cover`}
        className="w-48 h-48 sm:w-64 sm:h-64 md:w-72 md:h-72 rounded-lg shadow-lg object-cover bg-zinc-800 flex-shrink-0"
      />

      <div className="text-center w-full px-4 flex-shrink-0">
        <h2 className="text-xl sm:text-2xl font-bold truncate">{song.title}</h2>
        <p className="text-base sm:text-lg text-zinc-400 truncate mt-0.5">{song.artist}</p>
        <p className="text-sm text-zinc-500 truncate">{song.album}</p>
      </div>

      {/* Read-only progress bar */}
      <div className="w-full flex items-center gap-2 flex-shrink-0">
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

      {/* Transport controls */}
      <div className="flex items-center gap-6 sm:gap-8 flex-shrink-0">
        {/* Shuffle */}
        <button
          onClick={toggleShuffle}
          className={`transition-colors ${shuffle ? 'text-blue-500' : 'text-zinc-500 hover:text-white'}`}
          aria-label="Shuffle"
          title="Shuffle"
        >
          <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
            <path d="M10.59 9.17L5.41 4 4 5.41l5.17 5.17 1.42-1.41zM14.5 4l2.04 2.04L4 18.59 5.41 20 17.96 7.46 20 9.5V4h-5.5zm.33 9.41l-1.41 1.41 3.13 3.13L14.5 20H20v-5.5l-2.04 2.04-3.13-3.13z" />
          </svg>
        </button>

        <button
          onClick={() => prev()}
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
          onClick={() => next()}
          className="text-zinc-400 hover:text-white transition-colors"
          aria-label="Next"
        >
          <svg className="w-8 h-8" viewBox="0 0 24 24" fill="currentColor"><path d="M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z" /></svg>
        </button>

        {/* Repeat */}
        <button
          onClick={cycleRepeatMode}
          className={`relative transition-colors ${repeatMode !== 'off' ? 'text-blue-500' : 'text-zinc-500 hover:text-white'}`}
          aria-label={`Repeat: ${repeatMode}`}
          title={`Repeat: ${repeatMode}`}
        >
          <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
            <path d="M7 7h10v3l4-4-4-4v3H5v6h2V7zm10 10H7v-3l-4 4 4 4v-3h12v-6h-2v4z" />
          </svg>
          {repeatMode === 'one' && (
            <span className="absolute -top-1 -right-1 text-[9px] font-bold text-blue-500">1</span>
          )}
        </button>
      </div>

      <div className="flex items-center gap-4 flex-shrink-0">
        <span className="text-xs text-zinc-500">Observing</span>
        <QueueButton />
        <PlayHereButton />
      </div>
    </div>
  );
}
