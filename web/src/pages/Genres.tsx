import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useGenres } from '../hooks/useNavidrome';
import { init as initNavidrome } from '../api/navidrome';

export default function Genres() {
  const { genres, loading, error } = useGenres();
  const navigate = useNavigate();

  useEffect(() => {
    initNavidrome();
  }, []);

  return (
    <div className="p-6 max-w-4xl mx-auto">
      <h1 className="text-2xl font-bold mb-6">Genres</h1>

      {error && <p className="text-red-400 text-sm mb-4">{error}</p>}

      {loading && genres.length === 0 ? (
        <p className="text-zinc-500 text-center py-8">Loading genres…</p>
      ) : genres.length === 0 ? (
        <p className="text-zinc-500 text-center py-8">No genres found. Your music files may not have genre tags.</p>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
          {genres.map((genre) => (
            <button
              key={genre.value}
              onClick={() => navigate(`/genres/${encodeURIComponent(genre.value)}`)}
              className="text-left p-4 rounded-xl border border-zinc-800 hover:border-zinc-600 hover:bg-white/5 transition-colors"
            >
              <p className="font-medium truncate">{genre.value}</p>
              <p className="text-xs text-zinc-500 mt-1">
                {genre.albumCount} albums · {genre.songCount} songs
              </p>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
