import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAlbums } from '../hooks/useNavidrome';
import { init as initNavidrome } from '../api/navidrome';
import type { Album } from '../api/navidrome';
import AlbumGrid from '../components/AlbumGrid';

type SortOption = 'newest' | 'alphabetical' | 'artist';

export default function Albums() {
  const { albums, loading, error, reload } = useAlbums();
  const [sort, setSort] = useState<SortOption>('newest');
  const navigate = useNavigate();

  useEffect(() => {
    initNavidrome();
  }, []);

  const handleSortChange = useCallback((newSort: SortOption) => {
    setSort(newSort);
    const typeMap: Record<SortOption, string> = {
      newest: 'newest',
      alphabetical: 'alphabeticalByName',
      artist: 'alphabeticalByArtist',
    };
    reload(typeMap[newSort]);
  }, [reload]);

  const handleSelectAlbum = useCallback((album: Album) => {
    navigate(`/albums/${album.id}`);
  }, [navigate]);

  return (
    <div className="p-6 max-w-6xl mx-auto">
      {/* Header + sort */}
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold">Albums</h1>
        <div className="flex items-center gap-2">
          {(['newest', 'alphabetical', 'artist'] as SortOption[]).map((opt) => (
            <button
              key={opt}
              onClick={() => handleSortChange(opt)}
              className={`text-xs px-3 py-1.5 rounded-full border transition-colors ${
                sort === opt
                  ? 'border-white/30 bg-white/10 text-white'
                  : 'border-zinc-700 text-zinc-400 hover:text-white hover:border-zinc-500'
              }`}
            >
              {opt === 'newest' ? 'Newest' : opt === 'alphabetical' ? 'A–Z' : 'Artist'}
            </button>
          ))}
        </div>
      </div>

      {error && <p className="text-red-400 text-sm mb-4">{error}</p>}

      {loading && albums.length === 0 ? (
        <p className="text-zinc-500 text-center py-8">Loading albums…</p>
      ) : (
        <AlbumGrid albums={albums} onSelect={handleSelectAlbum} />
      )}
    </div>
  );
}
