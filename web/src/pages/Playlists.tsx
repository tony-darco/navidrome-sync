import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { usePlaylists } from '../hooks/usePlaylists';
import PlaylistGrid from '../components/PlaylistGrid';
import PlaylistCreateModal from '../components/PlaylistCreateModal';
import type { Playlist } from '../api/navidrome';

export default function Playlists() {
  const { playlists, loading, error, refetch } = usePlaylists();
  const [showCreate, setShowCreate] = useState(false);
  const navigate = useNavigate();

  const handleSelect = (pl: Playlist) => {
    navigate(`/playlists/${pl.id}`);
  };

  return (
    <div className="p-6 max-w-6xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold">Playlists</h1>
        <button
          onClick={() => setShowCreate(true)}
          className="px-4 py-2 text-sm bg-blue-600 hover:bg-blue-500 rounded-full font-medium"
        >
          + New Playlist
        </button>
      </div>

      {loading && playlists.length === 0 && (
        <div className="text-zinc-500 text-center py-12">Loading…</div>
      )}
      {error && (
        <div className="text-red-400 text-center py-12">
          {error}
          <button onClick={refetch} className="block mx-auto mt-2 text-sm text-zinc-400 hover:text-zinc-200">
            Retry
          </button>
        </div>
      )}
      {!loading && !error && (
        <PlaylistGrid playlists={playlists} onSelect={handleSelect} />
      )}

      <PlaylistCreateModal open={showCreate} onClose={() => setShowCreate(false)} />
    </div>
  );
}
