import { useState } from 'react';
import { usePlaylists } from '../hooks/usePlaylists';
import PlaylistList from '../components/PlaylistList';
import PlaylistDetail from '../components/PlaylistDetail';
import PlaylistCreateModal from '../components/PlaylistCreateModal';
import PlaylistEditSheet from '../components/PlaylistEditSheet';
import type { Playlist } from '../api/navidrome';  // type-only import

export default function Playlists() {
  const { playlists, loading, error, refetch } = usePlaylists();
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [showCreate, setShowCreate] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);

  if (editingId) {
    return (
      <PlaylistEditSheet
        playlistId={editingId}
        onClose={() => {
          setEditingId(null);
          refetch();
        }}
      />
    );
  }

  if (selectedId) {
    return (
      <div className="p-4">
        <PlaylistDetail
          playlistId={selectedId}
          onBack={() => setSelectedId(null)}
          onEdit={() => setEditingId(selectedId)}
        />
      </div>
    );
  }

  return (
    <div className="p-4">
      <div className="flex items-center justify-between mb-4">
        <h1 className="text-xl font-bold">Playlists</h1>
        <button
          onClick={() => setShowCreate(true)}
          className="px-3 py-1.5 text-sm bg-blue-600 hover:bg-blue-500 rounded-full"
        >
          + New
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
        <PlaylistList
          playlists={playlists}
          onSelect={(pl: Playlist) => setSelectedId(pl.id)}
        />
      )}

      <PlaylistCreateModal open={showCreate} onClose={() => setShowCreate(false)} />
    </div>
  );
}
