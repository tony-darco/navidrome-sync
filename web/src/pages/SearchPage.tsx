import { useState, useCallback, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { search, getCoverArtUrl } from '../api/navidrome';
import type { Album, Song } from '../api/navidrome';
import { useCrateColor, getCrateColor } from '../hooks/useCrateColor';
import { useSyncStore } from '../store/syncStore';
import { TRANSITIONS, TEXT, BACKGROUNDS, RADIUS, SPACING } from '../styles/design-system';

export default function SearchPage() {
  const [query, setQuery] = useState('');
  const [albums, setAlbums] = useState<Album[]>([]);
  const [songs, setSongs] = useState<Song[]>([]);
  const [loading, setLoading] = useState(false);
  const [hasSearched, setHasSearched] = useState(false);
  const crate = useCrateColor();
  const navigate = useNavigate();
  const playQueue = useSyncStore((s) => s.playQueue);
  const debounceRef = useRef<ReturnType<typeof setTimeout>>(undefined);

  const doSearch = useCallback(async (q: string) => {
    if (!q.trim()) { setAlbums([]); setSongs([]); setHasSearched(false); return; }
    setLoading(true);
    setHasSearched(true);
    try {
      const result = await search(q);
      setAlbums(result.albums);
      setSongs(result.songs);
    } catch {
      // ignore
    } finally {
      setLoading(false);
    }
  }, []);

  const handleInput = (value: string) => {
    setQuery(value);
    clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => doSearch(value), 300);
  };

  const handlePlaySong = (song: Song, allSongs: Song[]) => {
    const queue = allSongs.map((s) => ({
      songId: s.id,
      title: s.title,
      artist: s.artist,
      album: s.album,
      albumId: s.albumId,
      artistId: s.artistId,
      coverArtId: s.coverArt,
      durationSecs: s.duration,
      positionSecs: 0,
    }));
    const idx = allSongs.findIndex((s) => s.id === song.id);
    playQueue(queue, idx >= 0 ? idx : 0);
    navigate('/');
  };

  return (
    <div style={{ padding: '32px 28px', background: BACKGROUNDS.cream, minHeight: '100%' }}>
      {/* Header + search bar */}
      <h1 style={{ fontSize: 32, fontWeight: 700, letterSpacing: '-0.02em', color: TEXT.primary, marginBottom: 16 }}>
        Search
      </h1>

      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: SPACING.sm,
          background: 'rgba(0,0,0,0.07)',
          borderRadius: RADIUS.pill,
          padding: '9px 16px',
          maxWidth: 480,
          marginBottom: 32,
        }}
      >
        <span style={{ fontSize: 14, color: TEXT.secondary }}>⌕</span>
        <input
          type="text"
          value={query}
          onChange={(e) => handleInput(e.target.value)}
          placeholder="Albums, songs…"
          style={{
            flex: 1,
            background: 'none',
            border: 'none',
            outline: 'none',
            fontSize: 15,
            color: TEXT.primary,
            caretColor: crate.accent,
          }}
        />
        {loading && (
          <span style={{ fontSize: 11, color: TEXT.tertiary }}>searching…</span>
        )}
        {query && !loading && (
          <button
            onClick={() => { setQuery(''); setAlbums([]); setSongs([]); setHasSearched(false); }}
            style={{ background: 'none', border: 'none', cursor: 'pointer', color: TEXT.tertiary, fontSize: 16, lineHeight: 1 }}
          >
            ×
          </button>
        )}
      </div>

      {/* Empty state */}
      {!hasSearched && (
        <div style={{ textAlign: 'center', padding: '60px 0', color: TEXT.tertiary }}>
          <div style={{ fontSize: 40, marginBottom: 12 }}>⌕</div>
          <p style={{ fontSize: 15 }}>Search albums and songs</p>
        </div>
      )}

      {/* No results */}
      {hasSearched && !loading && albums.length === 0 && songs.length === 0 && (
        <div style={{ textAlign: 'center', padding: '60px 0', color: TEXT.tertiary }}>
          <p style={{ fontSize: 15 }}>No results for "{query}"</p>
        </div>
      )}

      {/* Albums section */}
      {albums.length > 0 && (
        <div style={{ marginBottom: 32 }}>
          <div className="flex items-center justify-between" style={{ marginBottom: 12 }}>
            <p style={{ fontSize: 11, fontWeight: 600, letterSpacing: '0.1em', textTransform: 'uppercase', color: TEXT.secondary }}>
              Albums
            </p>
            <span style={{ fontSize: 11, color: TEXT.tertiary, fontVariantNumeric: 'tabular-nums' }}>{albums.length}</span>
          </div>
          <div style={{ display: 'flex', gap: SPACING.md, overflowX: 'auto', paddingBottom: 8 }}>
            {albums.map((album) => {
              const albumCrate = getCrateColor(album.id);
              return (
                <button
                  key={album.id}
                  onClick={() => navigate(`/albums/${album.id}`)}
                  style={{
                    background: 'none',
                    border: 'none',
                    cursor: 'pointer',
                    textAlign: 'left',
                    flexShrink: 0,
                    width: 100,
                    padding: 0,
                  }}
                >
                  <div
                    style={{
                      width: 100,
                      height: 100,
                      borderRadius: RADIUS.md,
                      overflow: 'hidden',
                      background: albumCrate.device,
                      marginBottom: 6,
                    }}
                  >
                    <img
                      src={getCoverArtUrl(album.coverArt, 200)}
                      alt={album.name}
                      style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
                      onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
                    />
                  </div>
                  <p style={{ fontSize: 11, fontWeight: 600, color: TEXT.primary, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {album.name}
                  </p>
                  <p style={{ fontSize: 10, color: TEXT.secondary, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {album.artist}
                  </p>
                </button>
              );
            })}
          </div>
        </div>
      )}

      {/* Songs section */}
      {songs.length > 0 && (
        <div>
          <div className="flex items-center justify-between" style={{ marginBottom: 12 }}>
            <p style={{ fontSize: 11, fontWeight: 600, letterSpacing: '0.1em', textTransform: 'uppercase', color: TEXT.secondary }}>
              Songs
            </p>
            <span style={{ fontSize: 11, color: TEXT.tertiary, fontVariantNumeric: 'tabular-nums' }}>{songs.length}</span>
          </div>
          <div style={{ borderTop: '1px solid rgba(0,0,0,0.06)' }}>
            {songs.map((song) => (
              <SearchSongRow
                key={song.id}
                song={song}
                crate={crate}
                onPlay={() => handlePlaySong(song, songs)}
              />
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

function SearchSongRow({
  song,
  crate,
  onPlay,
}: {
  song: Song;
  crate: ReturnType<typeof useCrateColor>;
  onPlay: () => void;
}) {
  const [hovered, setHovered] = useState(false);
  return (
    <div
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onClick={onPlay}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: SPACING.md,
        height: 58,
        borderBottom: '1px solid rgba(0,0,0,0.05)',
        background: hovered ? BACKGROUNDS.creamHover : 'transparent',
        cursor: 'pointer',
        transition: 'background 0.12s ease',
        padding: '0 4px',
      }}
    >
      <div
        style={{
          width: 36,
          height: 36,
          borderRadius: RADIUS.sm,
          overflow: 'hidden',
          flexShrink: 0,
          background: crate.device,
          transition: TRANSITIONS.crateColor,
        }}
      >
        <img
          src={getCoverArtUrl(song.coverArt, 80)}
          alt=""
          style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
        />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <p style={{ fontSize: 13, fontWeight: 600, color: TEXT.primary, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {song.title}
        </p>
        <p style={{ fontSize: 10, color: TEXT.secondary, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {song.artist} · {song.album}
        </p>
      </div>
      <span style={{ fontSize: 11, color: TEXT.muted, fontVariantNumeric: 'tabular-nums', flexShrink: 0 }}>
        ▶
      </span>
    </div>
  );
}
