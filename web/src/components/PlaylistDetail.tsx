import { useCallback, useEffect, useState } from 'react';
import { getPlaylist, deletePlaylist, getCoverArtUrl } from '../api/navidrome';
import type { PlaylistWithSongs, Song } from '../api/navidrome';
import { useSyncStore } from '../store/syncStore';

interface PlaylistDetailProps {
  playlistId: string;
  onBack: () => void;
  onEdit: () => void;
}

export default function PlaylistDetail({ playlistId, onBack, onEdit }: PlaylistDetailProps) {
  const [playlist, setPlaylist] = useState<PlaylistWithSongs | null>(null);
  const [loading, setLoading] = useState(true);
  const playQueue = useSyncStore((s) => s.playQueue);
  const notifyPlaylistChanged = useSyncStore((s) => s.notifyPlaylistChanged);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getPlaylist(playlistId);
      setPlaylist(data);
    } catch (err) {
      console.error('Failed to load playlist', err);
    } finally {
      setLoading(false);
    }
  }, [playlistId]);

  useEffect(() => {
    load();
  }, [load]);

  const handleDelete = async () => {
    if (!confirm('Delete this playlist?')) return;
    await deletePlaylist(playlistId);
    notifyPlaylistChanged(playlistId, 'deleted');
    onBack();
  };

  const songToNowPlaying = (song: Song) => ({
    songId: song.id,
    title: song.title,
    artist: song.artist,
    album: song.album,
    coverArtId: song.coverArt,
    durationSecs: song.duration,
    positionSecs: 0,
  });

  const handlePlayAll = () => {
    if (!playlist || playlist.entry.length === 0) return;
    const queue = playlist.entry.map(songToNowPlaying);
    playQueue(queue, 0);
  };

  const handlePlayTrack = (index: number) => {
    if (!playlist) return;
    const queue = playlist.entry.map(songToNowPlaying);
    playQueue(queue, index);
  };

  if (loading) {
    return <div className="flex justify-center py-12"><div className="text-zinc-500">Loading…</div></div>;
  }

  if (!playlist) {
    return <div className="text-zinc-500 text-center py-12">Playlist not found</div>;
  }

  return (
    <div>
      <button onClick={onBack} className="text-sm text-zinc-400 hover:text-zinc-200 mb-4">
        ← Back to Playlists
      </button>

      <div className="flex items-end gap-4 mb-6">
        {playlist.coverArt ? (
          <img
            src={getCoverArtUrl(playlist.coverArt, 300)}
            alt={playlist.name}
            className="w-32 h-32 rounded-lg object-cover bg-zinc-800"
          />
        ) : (
          <div className="w-32 h-32 rounded-lg bg-zinc-800 flex items-center justify-center">
            <span className="text-zinc-500 text-3xl">♪</span>
          </div>
        )}
        <div>
          <h2 className="text-2xl font-bold">{playlist.name}</h2>
          <p className="text-sm text-zinc-400">{playlist.songCount} tracks</p>
          <div className="flex gap-2 mt-3">
            <button
              onClick={handlePlayAll}
              className="px-4 py-1.5 text-sm bg-blue-600 hover:bg-blue-500 rounded-full"
            >
              Play All
            </button>
            <button
              onClick={onEdit}
              className="px-4 py-1.5 text-sm bg-zinc-700 hover:bg-zinc-600 rounded-full"
            >
              Edit
            </button>
            <button
              onClick={handleDelete}
              className="px-4 py-1.5 text-sm bg-zinc-700 hover:bg-red-600 rounded-full"
            >
              Delete
            </button>
          </div>
        </div>
      </div>

      <div className="space-y-0.5">
        {playlist.entry.map((song, i) => (
          <button
            key={`${song.id}-${i}`}
            onClick={() => handlePlayTrack(i)}
            className="w-full flex items-center gap-3 px-3 py-2 rounded hover:bg-zinc-800/60 transition-colors text-left"
          >
            <span className="text-xs text-zinc-500 w-6 text-right">{i + 1}</span>
            {song.coverArt ? (
              <img
                src={getCoverArtUrl(song.coverArt, 80)}
                alt={song.title}
                className="w-10 h-10 rounded object-cover bg-zinc-800 flex-shrink-0"
              />
            ) : (
              <div className="w-10 h-10 rounded bg-zinc-800 flex-shrink-0" />
            )}
            <div className="min-w-0 flex-1">
              <p className="text-sm truncate">{song.title}</p>
              <p className="text-xs text-zinc-400 truncate">{song.artist}</p>
            </div>
            <span className="text-xs text-zinc-500">
              {Math.floor(song.duration / 60)}:{String(song.duration % 60).padStart(2, '0')}
            </span>
          </button>
        ))}
      </div>
    </div>
  );
}
