import { useCallback, useEffect, useState } from 'react';
import { getPlaylist, updatePlaylist, search, getCoverArtUrl } from '../api/navidrome';
import type { Song } from '../api/navidrome';
import { useSyncStore } from '../store/syncStore';

interface PlaylistEditSheetProps {
  playlistId: string;
  onClose: () => void;
}

export default function PlaylistEditSheet({ playlistId, onClose }: PlaylistEditSheetProps) {
  const [tracks, setTracks] = useState<Song[]>([]);
  const [playlistName, setPlaylistName] = useState('');
  const [pendingAdds, setPendingAdds] = useState<Set<string>>(new Set());
  const [pendingRemoves, setPendingRemoves] = useState<Set<number>>(new Set());
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<Song[]>([]);
  const [searching, setSearching] = useState(false);
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(true);
  const notifyPlaylistChanged = useSyncStore((s) => s.notifyPlaylistChanged);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getPlaylist(playlistId);
      setTracks(data.entry);
      setPlaylistName(data.name);
    } catch (err) {
      console.error('Failed to load playlist for editing', err);
    } finally {
      setLoading(false);
    }
  }, [playlistId]);

  useEffect(() => {
    load();
  }, [load]);

  const handleSearch = useCallback(async (q: string) => {
    setSearchQuery(q);
    if (!q.trim()) {
      setSearchResults([]);
      return;
    }
    setSearching(true);
    try {
      const results = await search(q);
      setSearchResults(results.songs);
    } catch {
      // ignore search errors
    } finally {
      setSearching(false);
    }
  }, []);

  const handleAddSong = (song: Song) => {
    setPendingAdds((prev) => new Set(prev).add(song.id));
    // Add to the visible track list at the end
    setTracks((prev) => [...prev, song]);
  };

  const handleRemoveTrack = (index: number) => {
    // If this was a pending add (index >= original track count), remove from pendingAdds
    const originalCount = tracks.length - pendingAdds.size;
    if (index >= originalCount) {
      const song = tracks[index];
      setPendingAdds((prev) => {
        const next = new Set(prev);
        next.delete(song.id);
        return next;
      });
    } else {
      setPendingRemoves((prev) => new Set(prev).add(index));
    }
    setTracks((prev) => prev.filter((_, i) => i !== index));
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      await updatePlaylist(
        playlistId,
        Array.from(pendingAdds),
        Array.from(pendingRemoves),
      );
      notifyPlaylistChanged(playlistId, 'updated');
      onClose();
    } catch (err) {
      console.error('Failed to update playlist', err);
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="fixed inset-0 z-50 bg-zinc-950 flex items-center justify-center">
        <div className="text-zinc-500">Loading…</div>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 z-50 bg-zinc-950 flex flex-col">
      <div className="flex items-center justify-between px-4 py-3 border-b border-zinc-800">
        <button onClick={onClose} className="text-sm text-zinc-400 hover:text-zinc-200">
          Cancel
        </button>
        <h3 className="font-semibold">Edit "{playlistName}"</h3>
        <button
          onClick={handleSave}
          disabled={saving || (pendingAdds.size === 0 && pendingRemoves.size === 0)}
          className="text-sm text-blue-500 hover:text-blue-400 disabled:text-zinc-600"
        >
          {saving ? 'Saving…' : 'Save'}
        </button>
      </div>

      <div className="flex-1 overflow-y-auto">
        {/* Search to add songs */}
        <div className="px-4 py-3 border-b border-zinc-800">
          <input
            type="text"
            placeholder="Search songs to add…"
            value={searchQuery}
            onChange={(e) => handleSearch(e.target.value)}
            className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-3 py-2 text-sm outline-none focus:border-blue-500"
          />
          {searching && <p className="text-xs text-zinc-500 mt-1">Searching…</p>}
          {searchResults.length > 0 && (
            <div className="mt-2 space-y-0.5 max-h-48 overflow-y-auto">
              {searchResults.map((song) => (
                <button
                  key={song.id}
                  onClick={() => handleAddSong(song)}
                  disabled={pendingAdds.has(song.id)}
                  className="w-full flex items-center gap-2 px-2 py-1.5 rounded hover:bg-zinc-800/60 text-left text-sm disabled:opacity-40"
                >
                  <span className="text-green-500">+</span>
                  <span className="truncate flex-1">{song.title}</span>
                  <span className="text-xs text-zinc-500">{song.artist}</span>
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Current tracks */}
        <div className="px-4 py-2">
          <h4 className="text-xs text-zinc-500 uppercase tracking-wide mb-2">
            Tracks ({tracks.length})
          </h4>
          {tracks.map((song, i) => (
            <div
              key={`${song.id}-${i}`}
              className="flex items-center gap-3 px-2 py-2 rounded hover:bg-zinc-800/40"
            >
              <span className="text-xs text-zinc-500 w-5 text-right">{i + 1}</span>
              {song.coverArt ? (
                <img
                  src={getCoverArtUrl(song.coverArt, 80)}
                  alt={song.title}
                  className="w-9 h-9 rounded object-cover bg-zinc-800 flex-shrink-0"
                />
              ) : (
                <div className="w-9 h-9 rounded bg-zinc-800 flex-shrink-0" />
              )}
              <div className="min-w-0 flex-1">
                <p className="text-sm truncate">{song.title}</p>
                <p className="text-xs text-zinc-400 truncate">{song.artist}</p>
              </div>
              <button
                onClick={() => handleRemoveTrack(i)}
                className="text-red-500 hover:text-red-400 text-sm px-2"
              >
                ✕
              </button>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
