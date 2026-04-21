import { useState, useMemo, useCallback } from 'react';
import { useSongs } from '../hooks/useNavidrome';
import { useSyncStore } from '../store/syncStore';
import { getCoverArtUrl } from '../api/navidrome';
import type { Song } from '../api/navidrome';
import { useCrateColor } from '../hooks/useCrateColor';
import { TRANSITIONS, TEXT, BACKGROUNDS, RADIUS, SPACING } from '../styles/design-system';

type SortOption = 'title' | 'artist' | 'album';

function songToNowPlaying(song: Song) {
  return {
    songId: song.id,
    title: song.title,
    artist: song.artist,
    album: song.album,
    albumId: song.albumId,
    artistId: song.artistId,
    coverArtId: song.coverArt,
    durationSecs: song.duration,
    positionSecs: 0,
  };
}

function formatTime(secs: number) {
  const m = Math.floor(secs / 60);
  const s = Math.floor(secs % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}

export default function Songs() {
  const { songs, loading, error, loadMore } = useSongs();
  const [filter, setFilter] = useState('');
  const [sort, setSort] = useState<SortOption>('title');
  const crate = useCrateColor();
  const playQueue = useSyncStore((s) => s.playQueue);
  const appendToQueue = useSyncStore((s) => s.appendToQueue);

  const displayed = useMemo(() => {
    let list = songs;
    if (filter.trim()) {
      const q = filter.toLowerCase();
      list = list.filter(
        (s) =>
          s.title.toLowerCase().includes(q) ||
          s.artist.toLowerCase().includes(q) ||
          s.album.toLowerCase().includes(q),
      );
    }
    const sorted = [...list];
    switch (sort) {
      case 'title':  sorted.sort((a, b) => a.title.localeCompare(b.title)); break;
      case 'artist': sorted.sort((a, b) => a.artist.localeCompare(b.artist)); break;
      case 'album':  sorted.sort((a, b) => a.album.localeCompare(b.album)); break;
    }
    return sorted;
  }, [songs, filter, sort]);

  const handlePlay = useCallback(
    (song: Song) => {
      const queue = displayed.map(songToNowPlaying);
      const idx = displayed.findIndex((s) => s.id === song.id);
      playQueue(queue, idx >= 0 ? idx : 0);
    },
    [displayed, playQueue],
  );

  return (
    <div style={{ padding: '32px 28px', background: BACKGROUNDS.cream, minHeight: '100%' }}>
      {/* Header */}
      <div className="flex items-center justify-between" style={{ marginBottom: 20 }}>
        <div>
          <h1 style={{ fontSize: 32, fontWeight: 700, letterSpacing: '-0.02em', color: TEXT.primary }}>
            Songs
          </h1>
          <p style={{ fontSize: 11, color: TEXT.tertiary, fontVariantNumeric: 'tabular-nums', marginTop: 2 }}>
            {songs.length} tracks
          </p>
        </div>

        {/* Sort pills */}
        <div className="flex items-center" style={{ gap: 6 }}>
          {(['title', 'artist', 'album'] as SortOption[]).map((opt) => (
            <button
              key={opt}
              onClick={() => setSort(opt)}
              style={{
                fontSize: 11,
                fontWeight: 600,
                letterSpacing: '0.04em',
                padding: '4px 12px',
                borderRadius: 20,
                border: `1.5px solid ${sort === opt ? crate.accent : 'rgba(0,0,0,0.12)'}`,
                background: sort === opt ? crate.device : 'transparent',
                color: sort === opt ? crate.text : TEXT.secondary,
                cursor: 'pointer',
                transition: TRANSITIONS.crateColor,
              }}
            >
              {opt.charAt(0).toUpperCase() + opt.slice(1)}
            </button>
          ))}
        </div>
      </div>

      {/* Filter */}
      <div style={{ marginBottom: 20 }}>
        <input
          type="text"
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
          placeholder="Filter songs…"
          style={{
            width: '100%',
            maxWidth: 320,
            background: 'rgba(0,0,0,0.06)',
            border: 'none',
            borderRadius: RADIUS.pill,
            padding: '7px 14px',
            fontSize: 13,
            color: TEXT.primary,
            outline: 'none',
          }}
        />
      </div>

      {error && <p style={{ color: '#D63030', fontSize: 13, marginBottom: 12 }}>{error}</p>}

      {loading && songs.length === 0 ? (
        <p style={{ color: TEXT.tertiary, textAlign: 'center', padding: '48px 0' }}>Loading songs…</p>
      ) : displayed.length === 0 ? (
        <p style={{ color: TEXT.tertiary, textAlign: 'center', padding: '48px 0' }}>No songs found</p>
      ) : (
        <div style={{ borderTop: '1px solid rgba(0,0,0,0.06)' }}>
          {displayed.map((song, i) => (
            <SongItem
              key={song.id}
              song={song}
              index={i + 1}
              crate={crate}
              onPlay={() => handlePlay(song)}
              onAddToQueue={() => appendToQueue(songToNowPlaying(song))}
            />
          ))}
          {songs.length >= 50 && (
            <button
              onClick={() => loadMore(songs.length)}
              style={{
                marginTop: SPACING.md,
                width: '100%',
                padding: '10px',
                fontSize: 13,
                color: TEXT.secondary,
                background: 'transparent',
                border: '1px solid rgba(0,0,0,0.1)',
                borderRadius: RADIUS.md,
                cursor: 'pointer',
              }}
            >
              Load more
            </button>
          )}
        </div>
      )}
    </div>
  );
}

function SongItem({
  song,
  index,
  crate,
  onPlay,
  onAddToQueue,
}: {
  song: Song;
  index: number;
  crate: ReturnType<typeof useCrateColor>;
  onPlay: () => void;
  onAddToQueue: () => void;
}) {
  const [hovered, setHovered] = useState(false);

  return (
    <div
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: SPACING.md,
        height: 58,
        padding: '0 4px',
        borderBottom: '1px solid rgba(0,0,0,0.05)',
        background: hovered ? BACKGROUNDS.creamHover : 'transparent',
        cursor: 'pointer',
        transition: 'background 0.12s ease',
      }}
      onClick={onPlay}
      title={`Play ${song.title}`}
    >
      {/* Track number */}
      <span
        style={{
          width: 28,
          textAlign: 'right',
          fontSize: 11,
          color: TEXT.muted,
          fontVariantNumeric: 'tabular-nums',
          flexShrink: 0,
        }}
      >
        {index}
      </span>

      {/* Art */}
      <div
        style={{
          width: 36,
          height: 36,
          borderRadius: RADIUS.sm,
          overflow: 'hidden',
          flexShrink: 0,
          background: crate.device,
        }}
      >
        <img
          src={getCoverArtUrl(song.coverArt, 80)}
          alt=""
          style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
        />
      </div>

      {/* Info */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <p style={{ fontSize: 13, fontWeight: 600, color: TEXT.primary, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {song.title}
        </p>
        <p style={{ fontSize: 10, color: TEXT.secondary, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {song.artist} · {song.album}
        </p>
      </div>

      {/* Duration */}
      <span style={{ fontSize: 11, color: TEXT.muted, fontVariantNumeric: 'tabular-nums', flexShrink: 0 }}>
        {formatTime(song.duration)}
      </span>

      {/* Add to queue (hovered) */}
      {hovered && (
        <button
          onClick={(e) => { e.stopPropagation(); onAddToQueue(); }}
          style={{
            fontSize: 11,
            color: crate.accent,
            background: crate.pillBg,
            border: 'none',
            borderRadius: RADIUS.pill,
            padding: '3px 10px',
            cursor: 'pointer',
            flexShrink: 0,
            transition: TRANSITIONS.crateColor,
          }}
        >
          + Queue
        </button>
      )}
    </div>
  );
}


