import { useState } from 'react';
import { usePlaylists } from '../hooks/usePlaylists';
import { updatePlaylist } from '../api/navidrome';
import { getCoverArtUrl } from '../api/navidrome';
import { useSyncStore } from '../store/syncStore';
import PlaylistCreateModal from './PlaylistCreateModal';

interface Props {
  songId: string;
  onClose: () => void;
}

export default function AddToPlaylistModal({ songId, onClose }: Props) {
  const { playlists, loading } = usePlaylists();
  const notifyPlaylistChanged = useSyncStore((s) => s.notifyPlaylistChanged);
  const [adding, setAdding] = useState<string | null>(null);
  const [added, setAdded] = useState<Set<string>>(new Set());
  const [showCreate, setShowCreate] = useState(false);

  async function handleAdd(playlistId: string) {
    setAdding(playlistId);
    try {
      await updatePlaylist(playlistId, [songId], []);
      setAdded((prev) => new Set(prev).add(playlistId));
      notifyPlaylistChanged(playlistId, 'updated');
    } catch (err) {
      console.error('[add-to-playlist]', err);
    } finally {
      setAdding(null);
    }
  }

  return (
    <>
      {/* Backdrop */}
      <div className="fixed inset-0 z-[100] bg-black/60 backdrop-blur-sm" onClick={onClose} />

      {/* Modal */}
      <div className="fixed inset-x-4 top-1/2 -translate-y-1/2 z-[101] max-w-md mx-auto bg-zinc-900 rounded-xl border border-zinc-700 shadow-2xl overflow-hidden max-h-[70vh] flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-zinc-800 flex-shrink-0">
          <h2 className="text-base font-semibold">Add to Playlist</h2>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setShowCreate(true)}
              className="text-zinc-400 hover:text-white transition-colors p-1"
              aria-label="New playlist"
              title="New playlist"
            >
              <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z" />
              </svg>
            </button>
            <button
              onClick={onClose}
              className="text-zinc-400 hover:text-white transition-colors p-1"
              aria-label="Close"
            >
              <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                <path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z" />
              </svg>
            </button>
          </div>
        </div>

        {/* Playlist list */}
        <div className="overflow-y-auto flex-1">
          {loading && playlists.length === 0 ? (
            <div className="flex items-center justify-center py-12 text-zinc-500 text-sm">Loading…</div>
          ) : playlists.length === 0 ? (
            <div className="flex items-center justify-center py-12 text-zinc-500 text-sm">No playlists yet</div>
          ) : (
            playlists.map((pl) => (
              <button
                key={pl.id}
                onClick={() => handleAdd(pl.id)}
                disabled={adding !== null}
                className="w-full flex items-center gap-3 px-4 py-3 hover:bg-zinc-800 transition-colors text-left disabled:opacity-50"
              >
                {pl.coverArt ? (
                  <img
                    src={getCoverArtUrl(pl.coverArt, 80)}
                    alt=""
                    className="w-10 h-10 rounded-md object-cover bg-zinc-800 flex-shrink-0"
                  />
                ) : (
                  <div className="w-10 h-10 rounded-md bg-zinc-800 flex items-center justify-center flex-shrink-0">
                    <svg className="w-5 h-5 text-zinc-600" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M15 6H3v2h12V6zm0 4H3v2h12v-2zM3 16h8v-2H3v2zM17 6v8.18c-.31-.11-.65-.18-1-.18-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3V8h3V6h-5z" />
                    </svg>
                  </div>
                )}
                <div className="flex-1 min-w-0">
                  <p className="text-sm text-zinc-100 truncate">{pl.name}</p>
                  <p className="text-xs text-zinc-500">{pl.songCount} songs</p>
                </div>
                {added.has(pl.id) ? (
                  <svg className="w-5 h-5 text-green-500 flex-shrink-0" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z" />
                  </svg>
                ) : adding === pl.id ? (
                  <div className="w-5 h-5 border-2 border-zinc-500 border-t-transparent rounded-full animate-spin flex-shrink-0" />
                ) : null}
              </button>
            ))
          )}
        </div>
      </div>

      <PlaylistCreateModal open={showCreate} onClose={() => setShowCreate(false)} />
    </>
  );
}
