import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { usePlaylists } from '../hooks/usePlaylists';
import { getCoverArtUrl } from '../api/navidrome';
import PlaylistCreateModal from '../components/PlaylistCreateModal';
import type { Playlist } from '../api/navidrome';
import { useCrateColor, getCrateColor } from '../hooks/useCrateColor';
import { TRANSITIONS, TEXT, BACKGROUNDS, RADIUS, SPACING } from '../styles/design-system';

export default function Playlists() {
  const { playlists, loading, error, refetch } = usePlaylists();
  const [showCreate, setShowCreate] = useState(false);
  const crate = useCrateColor();
  const navigate = useNavigate();

  return (
    <div style={{ padding: '32px 28px', background: BACKGROUNDS.cream, minHeight: '100%' }}>
      {/* Header */}
      <div className="flex items-center justify-between" style={{ marginBottom: 24 }}>
        <div>
          <h1 style={{ fontSize: 32, fontWeight: 700, letterSpacing: '-0.02em', color: TEXT.primary }}>
            Playlists
          </h1>
          <p style={{ fontSize: 11, color: TEXT.tertiary, fontVariantNumeric: 'tabular-nums', marginTop: 2 }}>
            {playlists.length} playlists
          </p>
        </div>
        <button
          onClick={() => setShowCreate(true)}
          style={{
            fontSize: 13,
            fontWeight: 600,
            padding: '7px 16px',
            borderRadius: RADIUS.pill,
            background: crate.accent,
            color: '#fff',
            border: 'none',
            cursor: 'pointer',
            transition: TRANSITIONS.crateColor,
          }}
        >
          + New Playlist
        </button>
      </div>

      {loading && playlists.length === 0 && (
        <p style={{ color: TEXT.tertiary, textAlign: 'center', padding: '48px 0' }}>Loading…</p>
      )}
      {error && (
        <div style={{ textAlign: 'center', padding: '48px 0' }}>
          <p style={{ color: '#D63030', fontSize: 14 }}>{error}</p>
          <button onClick={refetch} style={{ fontSize: 12, color: TEXT.secondary, marginTop: 8, background: 'none', border: 'none', cursor: 'pointer' }}>
            Retry
          </button>
        </div>
      )}

      {!loading && !error && (
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))',
            gap: SPACING.lg,
          }}
        >
          {playlists.map((pl) => (
            <PlaylistCard key={pl.id} playlist={pl} onSelect={() => navigate(`/playlists/${pl.id}`)} />
          ))}
        </div>
      )}

      <PlaylistCreateModal open={showCreate} onClose={() => setShowCreate(false)} />
    </div>
  );
}

function PlaylistCard({ playlist, onSelect }: { playlist: Playlist; onSelect: () => void }) {
  const plCrate = getCrateColor(playlist.id);
  const [hovered, setHovered] = useState(false);

  return (
    <button
      onClick={onSelect}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        textAlign: 'left',
        background: plCrate.device,
        border: 'none',
        borderRadius: RADIUS.lg,
        overflow: 'hidden',
        cursor: 'pointer',
        transform: hovered ? 'translateY(-2px)' : 'none',
        boxShadow: hovered ? '0 8px 24px rgba(0,0,0,0.15)' : '0 2px 8px rgba(0,0,0,0.07)',
        transition: 'transform 0.15s ease, box-shadow 0.15s ease',
        padding: 0,
      }}
    >
      {/* 2×2 quad art */}
      <div
        style={{
          width: '100%',
          aspectRatio: '1',
          display: 'grid',
          gridTemplateColumns: '1fr 1fr',
          gridTemplateRows: '1fr 1fr',
          overflow: 'hidden',
        }}
      >
        {[0, 1, 2, 3].map((i) => (
          <div key={i} style={{ background: plCrate.ring, overflow: 'hidden' }}>
            {playlist.coverArt && (
              <img
                src={getCoverArtUrl(playlist.coverArt, 160)}
                alt=""
                style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
                onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
              />
            )}
          </div>
        ))}
      </div>

      {/* Name + count */}
      <div style={{ padding: '10px 12px 12px' }}>
        <p style={{ fontSize: 13, fontWeight: 600, color: plCrate.text, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {playlist.name}
        </p>
        <p style={{ fontSize: 11, color: plCrate.text, opacity: 0.6, marginTop: 2 }}>
          {playlist.songCount} track{playlist.songCount !== 1 ? 's' : ''}
        </p>
      </div>
    </button>
  );
}


