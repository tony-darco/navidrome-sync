import { useState, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { useArtists } from '../hooks/useNavidrome';
import { getCoverArtUrl } from '../api/navidrome';
import type { ArtistID3 } from '../api/navidrome';
import { useCrateColor, getCrateColor } from '../hooks/useCrateColor';
import { TRANSITIONS, TEXT, BACKGROUNDS, RADIUS, SPACING } from '../styles/design-system';

type SortOption = 'az' | 'za' | 'albums';

export default function Artists() {
  const { artists: indexes, loading, error } = useArtists();
  const [filter, setFilter] = useState('');
  const [sort, setSort] = useState<SortOption>('az');
  const crate = useCrateColor();
  const navigate = useNavigate();

  const allArtists = useMemo(() => {
    const flat: ArtistID3[] = [];
    for (const idx of indexes) flat.push(...idx.artist);
    return flat;
  }, [indexes]);

  const displayed = useMemo(() => {
    let list = allArtists;
    if (filter.trim()) {
      const q = filter.toLowerCase();
      list = list.filter((a) => a.name.toLowerCase().includes(q));
    }
    const sorted = [...list];
    switch (sort) {
      case 'az':     sorted.sort((a, b) => a.name.localeCompare(b.name)); break;
      case 'za':     sorted.sort((a, b) => b.name.localeCompare(a.name)); break;
      case 'albums': sorted.sort((a, b) => b.albumCount - a.albumCount); break;
    }
    return sorted;
  }, [allArtists, filter, sort]);

  const SORT_LABELS: Record<SortOption, string> = { az: 'A–Z', za: 'Z–A', albums: 'Albums' };

  return (
    <div style={{ padding: '32px 28px', background: BACKGROUNDS.cream, minHeight: '100%' }}>
      {/* Header */}
      <div className="flex items-center justify-between" style={{ marginBottom: 20 }}>
        <h1 style={{ fontSize: 32, fontWeight: 700, letterSpacing: '-0.02em', color: TEXT.primary }}>
          Artists
        </h1>
        <div className="flex items-center" style={{ gap: 6 }}>
          {(['az', 'za', 'albums'] as SortOption[]).map((opt) => (
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
              {SORT_LABELS[opt]}
            </button>
          ))}
        </div>
      </div>

      {/* Filter */}
      <div style={{ marginBottom: 24 }}>
        <input
          type="text"
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
          placeholder="Filter artists…"
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

      {loading && allArtists.length === 0 ? (
        <p style={{ color: TEXT.tertiary, textAlign: 'center', padding: '48px 0' }}>Loading artists…</p>
      ) : displayed.length === 0 ? (
        <p style={{ color: TEXT.tertiary, textAlign: 'center', padding: '48px 0' }}>No artists found</p>
      ) : (
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(130px, 1fr))',
            gap: SPACING.lg,
          }}
        >
          {displayed.map((artist) => (
            <ArtistCard key={artist.id} artist={artist} onSelect={() => navigate(`/artists/${artist.id}`)} />
          ))}
        </div>
      )}
    </div>
  );
}

function ArtistCard({ artist, onSelect }: { artist: ArtistID3; onSelect: () => void }) {
  const artistCrate = getCrateColor(artist.id);
  const [hovered, setHovered] = useState(false);

  // Initials for avatar fallback
  const initials = artist.name
    .split(' ')
    .slice(0, 2)
    .map((w) => w[0] ?? '')
    .join('')
    .toUpperCase();

  return (
    <button
      onClick={onSelect}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        textAlign: 'center',
        background: 'none',
        border: 'none',
        cursor: 'pointer',
        padding: SPACING.sm,
        borderRadius: RADIUS.lg,
        transform: hovered ? 'translateY(-2px)' : 'none',
        transition: 'transform 0.15s ease',
      }}
    >
      {/* Circle avatar */}
      <div
        style={{
          width: '100%',
          aspectRatio: '1',
          borderRadius: '50%',
          overflow: 'hidden',
          background: artistCrate.device,
          boxShadow: hovered ? '0 6px 18px rgba(0,0,0,0.15)' : '0 2px 8px rgba(0,0,0,0.08)',
          transition: 'box-shadow 0.15s ease',
          position: 'relative',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          marginBottom: SPACING.sm,
        }}
      >
        {/* Initials fallback */}
        <span style={{ fontSize: 22, fontWeight: 700, color: artistCrate.accent, letterSpacing: '-0.02em', zIndex: 1 }}>
          {initials}
        </span>
        {/* Real art overlay */}
        <img
          src={getCoverArtUrl(artist.id, 200)}
          alt=""
          style={{
            position: 'absolute',
            inset: 0,
            width: '100%',
            height: '100%',
            objectFit: 'cover',
            zIndex: 2,
          }}
          onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
        />
      </div>

      <p style={{ fontSize: 12, fontWeight: 600, color: TEXT.primary, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
        {artist.name}
      </p>
      <p style={{ fontSize: 10, color: TEXT.secondary }}>
        {artist.albumCount} album{artist.albumCount !== 1 ? 's' : ''}
      </p>
    </button>
  );
}

