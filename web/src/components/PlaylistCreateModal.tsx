import { useState } from 'react';
import { createPlaylist } from '../api/navidrome';
import { useSyncStore } from '../store/syncStore';

interface PlaylistCreateModalProps {
  open: boolean;
  onClose: () => void;
}

export default function PlaylistCreateModal({ open, onClose }: PlaylistCreateModalProps) {
  const [name, setName] = useState('');
  const [saving, setSaving] = useState(false);
  const notifyPlaylistChanged = useSyncStore((s) => s.notifyPlaylistChanged);

  if (!open) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;
    setSaving(true);
    try {
      const id = await createPlaylist(name.trim());
      notifyPlaylistChanged(id, 'created');
      setName('');
      onClose();
    } catch (err) {
      console.error('Failed to create playlist', err);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60" onClick={onClose}>
      <div
        className="bg-zinc-900 border border-zinc-700 rounded-xl p-6 w-full max-w-sm"
        onClick={(e) => e.stopPropagation()}
      >
        <h3 className="text-lg font-semibold mb-4">New Playlist</h3>
        <form onSubmit={handleSubmit}>
          <input
            autoFocus
            type="text"
            placeholder="Playlist name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="w-full bg-zinc-800 border border-zinc-600 rounded-lg px-3 py-2 text-sm mb-4 outline-none focus:border-blue-500"
          />
          <div className="flex justify-end gap-2">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-1.5 text-sm rounded-lg bg-zinc-700 hover:bg-zinc-600"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={!name.trim() || saving}
              className="px-4 py-1.5 text-sm rounded-lg bg-blue-600 hover:bg-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {saving ? 'Creating…' : 'Create'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
