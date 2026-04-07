import { useMemo } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useArtistDetail } from '../hooks/useNavidrome';
import AlbumGrid from '../components/AlbumGrid';
import ArtistImage from '../components/ArtistImage';
import type { Album } from '../api/navidrome';

export default function ArtistDetail() {
  const { id } = useParams<{ id: string }>();
  const { artist, loading, error } = useArtistDetail(id ?? null);
  const navigate = useNavigate();

  // Sort albums by release year (ascending)
  const sortedAlbums = useMemo(() => {
    if (!artist) return [];
    return [...artist.album].sort((a, b) => (a.year ?? 9999) - (b.year ?? 9999));
  }, [artist]);

  const handleSelectAlbum = (album: Album) => {
    navigate(`/albums/${album.id}`);
  };

  if (loading) {
    return <div className="p-6 text-center text-zinc-500">Loading artist…</div>;
  }

  if (error) {
    return <div className="p-6 text-center text-red-400">{error}</div>;
  }

  if (!artist) {
    return <div className="p-6 text-center text-zinc-500">Artist not found</div>;
  }

  return (
    <div className="p-6 max-w-6xl mx-auto">
      {/* Back + title */}
      <button
        onClick={() => navigate('/artists')}
        className="mb-6 flex items-center gap-1 text-sm text-zinc-400 hover:text-white transition-colors"
      >
        <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
          <path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z" />
        </svg>
        Artists
      </button>

      <div className="flex items-center gap-6 mb-8">
        <ArtistImage artistId={artist.id} className="w-32 h-32 flex-shrink-0" />
        <div>
          <h1 className="text-3xl font-bold">{artist.name}</h1>
          <p className="text-sm text-zinc-400 mt-1">
            {artist.album.length} album{artist.album.length !== 1 ? 's' : ''}
          </p>
        </div>
      </div>

      <AlbumGrid albums={sortedAlbums} onSelect={handleSelectAlbum} />
    </div>
  );
}
