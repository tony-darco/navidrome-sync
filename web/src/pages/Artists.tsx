import { useState, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { useArtists } from '../hooks/useNavidrome';
import type { ArtistID3 } from '../api/navidrome';

type SortOption = 'az' | 'za' | 'albums';

export default function Artists() {
  const { artists: indexes, loading, error } = useArtists();
  const [filter, setFilter] = useState('');
  const [sort, setSort] = useState<SortOption>('az');
  const navigate = useNavigate();

  // Flatten artist indexes into a single list
  const allArtists = useMemo(() => {
    const flat: ArtistID3[] = [];
    for (const idx of indexes) {
      flat.push(...idx.artist);
    }
    return flat;
  }, [indexes]);

  // Filter and sort
  const displayed = useMemo(() => {
    let list = allArtists;
    if (filter.trim()) {
      const q = filter.toLowerCase();
      list = list.filter((a) => a.name.toLowerCase().includes(q));
    }
    const sorted = [...list];
    switch (sort) {
      case 'az':
        sorted.sort((a, b) => a.name.localeCompare(b.name));
        break;
      case 'za':
        sorted.sort((a, b) => b.name.localeCompare(a.name));
        break;
      case 'albums':
        sorted.sort((a, b) => b.albumCount - a.albumCount);
        break;
    }
    return sorted;
  }, [allArtists, filter, sort]);

  return (
    <div className="p-6 max-w-6xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold">Artists</h1>
        <div className="flex items-center gap-2">
          {(['az', 'za', 'albums'] as SortOption[]).map((opt) => (
            <button
              key={opt}
              onClick={() => setSort(opt)}
              className={`text-xs px-3 py-1.5 rounded-full border transition-colors ${
                sort === opt
                  ? 'border-white/30 bg-white/10 text-white'
                  : 'border-zinc-700 text-zinc-400 hover:text-white hover:border-zinc-500'
              }`}
            >
              {opt === 'az' ? 'A–Z' : opt === 'za' ? 'Z–A' : 'Albums'}
            </button>
          ))}
        </div>
      </div>

      {/* Filter */}
      <div className="mb-6">
        <input
          type="text"
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
          placeholder="Filter artists…"
          className="w-full max-w-sm bg-zinc-900 border border-zinc-800 rounded-lg px-4 py-2 text-sm text-zinc-100 placeholder-zinc-600 focus:outline-none focus:border-zinc-600"
        />
      </div>

      {error && <p className="text-red-400 text-sm mb-4">{error}</p>}

      {loading && allArtists.length === 0 ? (
        <p className="text-zinc-500 text-center py-8">Loading artists…</p>
      ) : displayed.length === 0 ? (
        <p className="text-zinc-500 text-center py-8">No artists found</p>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
          {displayed.map((artist) => (
            <button
              key={artist.id}
              onClick={() => navigate(`/artists/${artist.id}`)}
              className="group text-left rounded-lg p-3 hover:bg-zinc-800/60 transition-colors"
            >
              {/* Artist avatar placeholder */}
              <div className="w-full aspect-square rounded-full bg-zinc-800 mb-3 flex items-center justify-center group-hover:bg-zinc-700 transition-colors">
                <svg className="w-12 h-12 text-zinc-600" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" />
                </svg>
              </div>
              <p className="text-sm font-medium truncate text-center">{artist.name}</p>
              <p className="text-xs text-zinc-500 text-center">{artist.albumCount} album{artist.albumCount !== 1 ? 's' : ''}</p>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
