import { useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAlbums } from '../hooks/useNavidrome';
import { getCoverArtUrl } from '../api/navidrome';
import type { Album } from '../api/navidrome';
import { useCrateColor, getCrateColor } from '../hooks/useCrateColor';
import { TRANSITIONS, TEXT, BACKGROUNDS, RADIUS, SPACING } from '../styles/design-system';

type SortOption = 'newest' | 'alphabetical' | 'artist';

const SORT_LABELS: Record<SortOption, string> = {
  newest: 'Newest',
  alphabetical: 'A–Z',
  artist: 'Artist',
};

export default function Albums() {
  const { albums, loading, error, reload } = useAlbums();
  const [sort, setSort] = useState<SortOption>('newest');
  const crate = useCrateColor();
  const navigate = useNavigate();

  const handleSortChange = useCallback(
    (newSort: SortOption) => {
      setSort(newSort);
      const typeMap: Record<SortOption, string> = {
        newest: 'newest',
        alphabetical: 'alphabeticalByName',
        artist: 'alphabeticalByArtist',
      };
      reload(typeMap[newSort]);
    },
    [reload],
  );

  return (
    <div style={{ padding: '32px 28px', background: BACKGROUNDS.cream, minHeight: '100%' }}>
      {/* Header */}
      <div className="flex items-center justify-between" style={{ marginBottom: 24 }}>
        <h1
          style={{
            fontSize: 32,
            fontWeight: 700,
            letterSpacing: '-0.02em',
            color: TEXT.primary,
          }}
        >
          Albums
        </h1>

        {/* Sort pills */}
        <div className="flex items-center" style={{ gap: 6 }}>
          {(Object.keys(SORT_LABELS) as SortOption[]).map((opt) => (
            <button
              key={opt}
              onClick={() => handleSortChange(opt)}
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

      {error && (
        <p style={{ color: '#D63030', fontSize: 13, marginBottom: 16 }}>{error}</p>
      )}

      {loading && albums.length === 0 ? (
        <p style={{ color: TEXT.tertiary, textAlign: 'center', padding: '48px 0', fontSize: 15 }}>
          Loading albums…
        </p>
      ) : (
        <AlbumsGrid albums={albums} onSelect={(a) => navigate(`/albums/${a.id}`)} />
      )}
    </div>
  );
}

function AlbumsGrid({
  albums,
  onSelect,
}: {
  albums: Album[];
  onSelect: (a: Album) => void;
}) {
  return (
    <div
      style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))',
        gap: SPACING.lg,
      }}
    >
      {albums.map((album) => (
        <AlbumCard key={album.id} album={album} onSelect={onSelect} />
      ))}
    </div>
  );
}

function AlbumCard({
  album,
  onSelect,
}: {
  album: Album;
  onSelect: (a: Album) => void;
}) {
  const albumCrate = getCrateColor(album.id);
  const [hovered, setHovered] = useState(false);

  return (
    <button
      onClick={() => onSelect(album)}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        textAlign: 'left',
        background: 'none',
        border: 'none',
        cursor: 'pointer',
        padding: 0,
        transform: hovered ? 'translateY(-2px)' : 'none',
        transition: 'transform 0.15s ease',
      }}
    >
      {/* Art */}
      <div
        style={{
          width: '100%',
          aspectRatio: '1',
          borderRadius: RADIUS.lg,
          overflow: 'hidden',
          background: albumCrate.device,
          boxShadow: hovered
            ? `0 8px 24px rgba(0,0,0,0.18)`
            : `0 2px 8px rgba(0,0,0,0.10)`,
          transition: 'box-shadow 0.15s ease',
        }}
      >
        <img
          src={getCoverArtUrl(album.coverArt, 300)}
          alt={album.name}
          style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
          onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
        />
      </div>

      {/* Title + artist */}
      <div style={{ padding: '8px 2px 0' }}>
        <p
          style={{
            fontSize: 12,
            fontWeight: 600,
            color: TEXT.primary,
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}
        >
          {album.name}
        </p>
        <p
          style={{
            fontSize: 11,
            color: TEXT.secondary,
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
            marginTop: 1,
          }}
        >
          {album.artist}
        </p>
      </div>
    </button>
  );
}

