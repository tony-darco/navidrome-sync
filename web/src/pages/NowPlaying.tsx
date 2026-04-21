import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useSyncStore } from '../store/syncStore';
import type { NowPlayingSong } from '../store/syncStore';
import { getCoverArtUrl } from '../api/navidrome';
import { useCrateColor } from '../hooks/useCrateColor';
import { TRANSITIONS, TEXT } from '../styles/design-system';
import PlayHereButton from '../components/PlayHereButton';
import AddToPlaylistModal from '../components/AddToPlaylistModal';

function formatTime(secs: number) {
  const m = Math.floor(secs / 60);
  const s = Math.floor(secs % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}

export default function NowPlaying() {
  const nowPlaying = useSyncStore((s) => s.nowPlaying);
  const myRole = useSyncStore((s) => s.myRole);
  const showQueue = useSyncStore((s) => s.showQueue);
  const crate = useCrateColor();

  if (!nowPlaying) {
    return (
      <div
        className="flex items-center justify-center h-full"
        style={{ background: '#0A0A0A', color: 'rgba(255,255,255,0.3)', fontSize: 16 }}
      >
        Nothing playing
      </div>
    );
  }

  if (showQueue) {
    return (
      <div className="h-full overflow-y-auto" style={{ background: '#0A0A0A', color: '#fff' }}>
        <QueueView isActive={myRole === 'active'} crate={crate} />
      </div>
    );
  }

  return (
    <PlayerView
      song={nowPlaying}
      isActive={myRole === 'active'}
      crate={crate}
    />
  );
}

/* ─── Queue button ─── */
function QueueButton({ accent }: { accent: string }) {
  const showQueue = useSyncStore((s) => s.showQueue);
  const setShowQueue = useSyncStore((s) => s.setShowQueue);
  return (
    <button
      onClick={() => setShowQueue(!showQueue)}
      style={{ color: showQueue ? accent : 'rgba(255,255,255,0.4)', transition: TRANSITIONS.crateColor }}
      aria-label="Queue"
    >
      <svg style={{ width: 20, height: 20 }} viewBox="0 0 24 24" fill="currentColor">
        <path d="M15 6H3v2h12V6zm0 4H3v2h12v-2zM3 16h8v-2H3v2zM17 6v8.18c-.31-.11-.65-.18-1-.18-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3V8h3V6h-5z" />
      </svg>
    </button>
  );
}

/* ─── Star button ─── */
function StarButton({ song }: { song: NowPlayingSong }) {
  const toggleStar = useSyncStore((s) => s.toggleStar);
  const starred = song.starred ?? false;
  return (
    <button
      onClick={toggleStar}
      style={{ color: starred ? '#e05' : 'rgba(255,255,255,0.4)', transition: 'color 0.15s' }}
      aria-label={starred ? 'Unfavorite' : 'Favorite'}
      title={starred ? 'Unfavorite' : 'Favorite'}
    >
      <svg style={{ width: 20, height: 20 }} viewBox="0 0 24 24" fill={starred ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth={starred ? 0 : 2}>
        <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" />
      </svg>
    </button>
  );
}

/* ─── Add to playlist button ─── */
function AddToPlaylistButton({ song }: { song: NowPlayingSong }) {
  const [showModal, setShowModal] = useState(false);
  return (
    <>
      <button
        onClick={() => setShowModal(true)}
        style={{ color: 'rgba(255,255,255,0.4)' }}
        aria-label="Add to playlist"
      >
        <svg style={{ width: 20, height: 20 }} viewBox="0 0 24 24" fill="currentColor">
          <path d="M13 7h-2v4H7v2h4v4h2v-4h4v-2h-4V7zm-1-5C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z" />
        </svg>
      </button>
      {showModal && <AddToPlaylistModal songId={song.songId} onClose={() => setShowModal(false)} />}
    </>
  );
}

/* ─── Shared Player View (active + observer) ─── */
function PlayerView({
  song,
  isActive,
  crate,
}: {
  song: NowPlayingSong;
  isActive: boolean;
  crate: ReturnType<typeof useCrateColor>;
}) {
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
  const navigate = useNavigate();

  const accent = crate.accent;
  const iconColor = 'rgba(255,255,255,0.75)';
  const mutedColor = 'rgba(255,255,255,0.35)';

  return (
    <div
      className="flex flex-col items-center justify-center gap-6 p-8 h-full overflow-hidden"
      style={{ background: '#0A0A0A', color: '#fff', transition: TRANSITIONS.crateColor }}
    >
      {/* Album art */}
      <div
        style={{
          width: 260,
          height: 260,
          flexShrink: 0,
          borderRadius: 16,
          overflow: 'hidden',
          boxShadow: `0 24px 64px rgba(0,0,0,0.65), 0 0 0 1px rgba(255,255,255,0.07)`,
        }}
      >
        <img
          src={getCoverArtUrl(song.coverArtId, 600)}
          alt={`${song.album} cover`}
          style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
        />
      </div>

      {/* Track info */}
      <div style={{ textAlign: 'center', width: '100%', maxWidth: 400, flexShrink: 0, padding: '0 16px' }}>
        <h2
          style={{
            fontSize: 24,
            fontWeight: 700,
            letterSpacing: '-0.02em',
            color: '#fff',
            marginBottom: 4,
            cursor: song.albumId ? 'pointer' : 'default',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}
          onClick={() => song.albumId && navigate(`/albums/${song.albumId}`)}
        >
          {song.title}
        </h2>
        <p
          style={{
            fontSize: 15,
            color: 'rgba(255,255,255,0.65)',
            marginBottom: 2,
            cursor: song.artistId ? 'pointer' : 'default',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}
          onClick={() => song.artistId && navigate(`/artists/${song.artistId}`)}
        >
          {song.artist}
        </p>
        <p
          style={{
            fontSize: 13,
            color: 'rgba(255,255,255,0.4)',
            cursor: song.albumId ? 'pointer' : 'default',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}
          onClick={() => song.albumId && navigate(`/albums/${song.albumId}`)}
        >
          {song.album}
        </p>
      </div>

      {/* Scrubber */}
      <div
        className="flex items-center gap-2"
        style={{ width: '100%', maxWidth: 400, flexShrink: 0, padding: '0 16px' }}
      >
        <span style={{ fontSize: 11, color: mutedColor, fontVariantNumeric: 'tabular-nums', width: 36, textAlign: 'right' }}>
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
          style={{ flex: 1, accentColor: accent }}
        />
        <span style={{ fontSize: 11, color: mutedColor, fontVariantNumeric: 'tabular-nums', width: 36 }}>
          {formatTime(song.durationSecs)}
        </span>
      </div>

      {/* Transport controls */}
      <div
        className="flex items-center"
        style={{ gap: 24, flexShrink: 0 }}
      >
        {/* Shuffle */}
        <button
          onClick={toggleShuffle}
          style={{ color: shuffle ? accent : mutedColor, transition: TRANSITIONS.crateColor, background: 'none', border: 'none', cursor: 'pointer' }}
          aria-label="Shuffle"
        >
          <svg style={{ width: 20, height: 20 }} viewBox="0 0 24 24" fill="currentColor">
            <path d="M10.59 9.17L5.41 4 4 5.41l5.17 5.17 1.42-1.41zM14.5 4l2.04 2.04L4 18.59 5.41 20 17.96 7.46 20 9.5V4h-5.5zm.33 9.41l-1.41 1.41 3.13 3.13L14.5 20H20v-5.5l-2.04 2.04-3.13-3.13z" />
          </svg>
        </button>

        {/* Prev */}
        <button
          onClick={() => prev()}
          style={{ color: iconColor, background: 'none', border: 'none', cursor: 'pointer' }}
          aria-label="Previous"
        >
          <svg style={{ width: 32, height: 32 }} viewBox="0 0 24 24" fill="currentColor"><path d="M6 6h2v12H6zm3.5 6l8.5 6V6z" /></svg>
        </button>

        {/* Play/Pause */}
        <button
          onClick={isPlaying ? pause : play}
          style={{
            width: 56,
            height: 56,
            borderRadius: '50%',
            background: accent,
            color: '#fff',
            border: 'none',
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            transition: TRANSITIONS.crateColor,
          }}
          aria-label={isPlaying ? 'Pause' : 'Play'}
        >
          {isPlaying ? (
            <svg style={{ width: 26, height: 26 }} viewBox="0 0 24 24" fill="currentColor"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z" /></svg>
          ) : (
            <svg style={{ width: 26, height: 26, marginLeft: 3 }} viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z" /></svg>
          )}
        </button>

        {/* Next */}
        <button
          onClick={() => next()}
          style={{ color: iconColor, background: 'none', border: 'none', cursor: 'pointer' }}
          aria-label="Next"
        >
          <svg style={{ width: 32, height: 32 }} viewBox="0 0 24 24" fill="currentColor"><path d="M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z" /></svg>
        </button>

        {/* Repeat */}
        <button
          onClick={cycleRepeatMode}
          style={{
            position: 'relative',
            color: repeatMode !== 'off' ? accent : mutedColor,
            transition: TRANSITIONS.crateColor,
            background: 'none',
            border: 'none',
            cursor: 'pointer',
          }}
          aria-label={`Repeat: ${repeatMode}`}
        >
          <svg style={{ width: 20, height: 20 }} viewBox="0 0 24 24" fill="currentColor">
            <path d="M7 7h10v3l4-4-4-4v3H5v6h2V7zm10 10H7v-3l-4 4 4 4v-3h12v-6h-2v4z" />
          </svg>
          {repeatMode === 'one' && (
            <span
              style={{
                position: 'absolute',
                top: -4,
                right: -4,
                fontSize: 8,
                fontWeight: 700,
                color: accent,
              }}
            >
              1
            </span>
          )}
        </button>
      </div>

      {/* Secondary controls */}
      <div
        className="flex items-center"
        style={{ gap: 20, flexShrink: 0 }}
      >
        <StarButton song={song} />
        <AddToPlaylistButton song={song} />
        {!isActive && <PlayHereButton />}
        <span
          style={{
            fontSize: 10,
            fontWeight: 600,
            letterSpacing: '0.07em',
            textTransform: 'uppercase',
            color: isActive ? accent : mutedColor,
            transition: TRANSITIONS.crateColor,
          }}
        >
          {isActive ? 'Active' : 'Observing'}
        </span>
        <QueueButton accent={accent} />
      </div>
    </div>
  );
}

/* ─── Queue View ─── */
function QueueView({
  isActive,
  crate,
}: {
  isActive: boolean;
  crate: ReturnType<typeof useCrateColor>;
}) {
  const queue = useSyncStore((s) => s.queue);
  const queueIndex = useSyncStore((s) => s.queueIndex);
  const nowPlaying = useSyncStore((s) => s.nowPlaying);
  const setShowQueue = useSyncStore((s) => s.setShowQueue);
  const playQueueIndex = useSyncStore((s) => s.playQueueIndex);
  const removeFromQueue = useSyncStore((s) => s.removeFromQueue);
  const clearQueue = useSyncStore((s) => s.clearQueue);

  const upNext = queue.filter((_, i) => i > queueIndex);
  const accent = crate.accent;

  return (
    <div style={{ padding: '24px 24px', maxWidth: 640, margin: '0 auto' }}>
      {/* Header */}
      <div className="flex items-center justify-between" style={{ marginBottom: 28 }}>
        <button
          onClick={() => setShowQueue(false)}
          style={{ fontSize: 13, color: 'rgba(255,255,255,0.5)', background: 'none', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 4 }}
        >
          <svg style={{ width: 16, height: 16 }} viewBox="0 0 24 24" fill="currentColor">
            <path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z" />
          </svg>
          Back
        </button>
        <h2 style={{ fontSize: 18, fontWeight: 700, color: '#fff' }}>Queue</h2>
        <div style={{ width: 48 }} />
      </div>

      {/* Now Playing */}
      {nowPlaying && (
        <div style={{ marginBottom: 28 }}>
          <p style={{ fontSize: 10, fontWeight: 600, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'rgba(255,255,255,0.35)', marginBottom: 10 }}>
            Now Playing
          </p>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 12px', background: 'rgba(255,255,255,0.06)', borderRadius: 10 }}>
            <img src={getCoverArtUrl(nowPlaying.coverArtId, 80)} alt="" style={{ width: 44, height: 44, borderRadius: 6, objectFit: 'cover', flexShrink: 0 }} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <p style={{ fontSize: 13, fontWeight: 600, color: accent, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', transition: TRANSITIONS.crateColor }}>{nowPlaying.title}</p>
              <p style={{ fontSize: 11, color: 'rgba(255,255,255,0.45)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{nowPlaying.artist}</p>
            </div>
            <span style={{ fontSize: 11, color: 'rgba(255,255,255,0.3)', fontVariantNumeric: 'tabular-nums' }}>
              {formatTime(nowPlaying.durationSecs)}
            </span>
          </div>
        </div>
      )}

      {/* Next in queue */}
      <div>
        <div className="flex items-center justify-between" style={{ marginBottom: 12 }}>
          <p style={{ fontSize: 10, fontWeight: 600, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'rgba(255,255,255,0.35)' }}>
            Next in queue
          </p>
          {isActive && upNext.length > 0 && (
            <button
              onClick={clearQueue}
              style={{ fontSize: 10, fontWeight: 600, letterSpacing: '0.05em', textTransform: 'uppercase', color: 'rgba(255,255,255,0.4)', background: 'none', border: '1px solid rgba(255,255,255,0.15)', borderRadius: 6, padding: '3px 10px', cursor: 'pointer' }}
            >
              Clear
            </button>
          )}
        </div>

        {upNext.length === 0 ? (
          <p style={{ fontSize: 13, color: 'rgba(255,255,255,0.3)', textAlign: 'center', padding: '24px 0' }}>Queue is empty</p>
        ) : (
          <div>
            {upNext.map((item, i) => {
              const realIndex = queueIndex + 1 + i;
              return (
                <div
                  key={`${item.songId}-${realIndex}`}
                  className="group"
                  style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '8px 10px', borderRadius: 8 }}
                >
                  <span style={{ width: 20, textAlign: 'right', fontSize: 11, color: 'rgba(255,255,255,0.25)', fontVariantNumeric: 'tabular-nums', flexShrink: 0 }}>
                    {i + 1}
                  </span>
                  {isActive ? (
                    <button
                      onClick={() => playQueueIndex(realIndex)}
                      style={{ display: 'flex', alignItems: 'center', gap: 10, flex: 1, minWidth: 0, background: 'none', border: 'none', cursor: 'pointer', textAlign: 'left', color: 'inherit' }}
                    >
                      <img src={getCoverArtUrl(item.coverArtId, 80)} alt="" style={{ width: 38, height: 38, borderRadius: 5, objectFit: 'cover', flexShrink: 0 }} />
                      <div style={{ minWidth: 0, flex: 1 }}>
                        <p style={{ fontSize: 13, fontWeight: 500, color: TEXT.onDark, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{item.title}</p>
                        <p style={{ fontSize: 11, color: 'rgba(255,255,255,0.4)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{item.artist}</p>
                      </div>
                    </button>
                  ) : (
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10, flex: 1, minWidth: 0 }}>
                      <img src={getCoverArtUrl(item.coverArtId, 80)} alt="" style={{ width: 38, height: 38, borderRadius: 5, objectFit: 'cover', flexShrink: 0 }} />
                      <div style={{ minWidth: 0, flex: 1 }}>
                        <p style={{ fontSize: 13, fontWeight: 500, color: TEXT.onDark, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{item.title}</p>
                        <p style={{ fontSize: 11, color: 'rgba(255,255,255,0.4)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{item.artist}</p>
                      </div>
                    </div>
                  )}
                  <span style={{ fontSize: 11, color: 'rgba(255,255,255,0.3)', fontVariantNumeric: 'tabular-nums', flexShrink: 0 }}>
                    {formatTime(item.durationSecs)}
                  </span>
                  {isActive && (
                    <button
                      onClick={() => removeFromQueue(realIndex)}
                      style={{ color: 'rgba(255,255,255,0.25)', background: 'none', border: 'none', cursor: 'pointer', flexShrink: 0 }}
                      aria-label="Remove"
                    >
                      <svg style={{ width: 14, height: 14 }} viewBox="0 0 24 24" fill="currentColor">
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

