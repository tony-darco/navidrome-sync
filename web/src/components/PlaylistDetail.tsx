import { useCallback, useEffect, useState } from 'react';
import { getPlaylist, deletePlaylist, updatePlaylist, getCoverArtUrl } from '../api/navidrome';
import type { PlaylistWithSongs, Song } from '../api/navidrome';
import { useSyncStore } from '../store/syncStore';
import { getDominantColor, type RGB } from '../utils/dominantColor';
import DetailHeader from './DetailHeader';
import SongRow from './SongRow';

interface PlaylistDetailProps {
  playlistId: string;
  onBack: () => void;
  onEdit: () => void;
}

function songToNowPlaying(song: Song) {
  return {
    songId: song.id,
    title: song.title,
    artist: song.artist,
    album: song.album,
    coverArtId: song.coverArt,
    durationSecs: song.duration,
    positionSecs: 0,
  };
}

export default function PlaylistDetail({ playlistId, onBack, onEdit }: PlaylistDetailProps) {
  const [playlist, setPlaylist] = useState<PlaylistWithSongs | null>(null);
  const [loading, setLoading] = useState(true);
  const [dominantColor, setDominantColor] = useState<RGB | null>(null);
  const playQueue = useSyncStore((s) => s.playQueue);
  const toggleShuffle = useSyncStore((s) => s.toggleShuffle);
  const appendToQueue = useSyncStore((s) => s.appendToQueue);
  const notifyPlaylistChanged = useSyncStore((s) => s.notifyPlaylistChanged);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getPlaylist(playlistId);
      setPlaylist(data);
      if (data.coverArt) {
        getDominantColor(getCoverArtUrl(data.coverArt, 50)).then(setDominantColor);
      }
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

  const handlePlayAll = () => {
    if (!playlist || playlist.entry.length === 0) return;
    const queue = playlist.entry.map(songToNowPlaying);
    playQueue(queue, 0);
  };

  const handleShuffle = () => {
    toggleShuffle();
    handlePlayAll();
  };

  const handlePlayTrack = (index: number) => {
    if (!playlist) return;
    const queue = playlist.entry.map(songToNowPlaying);
    playQueue(queue, index);
  };

  const handleRemoveTrack = async (index: number) => {
    if (!playlist) return;
    await updatePlaylist(playlistId, [], [index]);
    notifyPlaylistChanged(playlistId, 'updated');
    load();
  };

  if (loading) {
    return <div className="flex justify-center py-12"><div className="text-zinc-500">Loading…</div></div>;
  }

  if (!playlist) {
    return <div className="text-zinc-500 text-center py-12">Playlist not found</div>;
  }

  const coverArtUrl = playlist.coverArt
    ? getCoverArtUrl(playlist.coverArt, 600)
    : '';
  const c = dominantColor ?? { r: 30, g: 30, b: 30 };
  const moodBg = {
    background: `linear-gradient(to bottom, rgba(${c.r},${c.g},${c.b},0.55) 0%, rgba(${c.r},${c.g},${c.b},0.35) 50%, rgba(${c.r},${c.g},${c.b},0.2) 100%)`,
    backgroundColor: `rgb(${Math.round(c.r * 0.15)},${Math.round(c.g * 0.15)},${Math.round(c.b * 0.15)})`,
  };

  return (
    <div className="min-h-full" style={moodBg}>
      <div className="px-6 pt-6 pb-12 max-w-4xl mx-auto">
        <DetailHeader
          coverArtUrl={coverArtUrl}
          title={playlist.name}
          meta={`${playlist.songCount} tracks`}
          onShuffle={handleShuffle}
          onPlay={handlePlayAll}
          onBack={onBack}
          extraButtons={
            <>
              <button
                onClick={onEdit}
                className="w-10 h-10 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center transition-colors"
                title="Edit"
              >
                <svg className="w-4 h-4 text-white" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04c.39-.39.39-1.02 0-1.41l-2.34-2.34a.9959.9959 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z" />
                </svg>
              </button>
              <button
                onClick={handleDelete}
                className="w-10 h-10 rounded-full bg-white/10 hover:bg-red-600/80 flex items-center justify-center transition-colors"
                title="Delete"
              >
                <svg className="w-4 h-4 text-white" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z" />
                </svg>
              </button>
            </>
          }
        />

        <div>
          {playlist.entry.map((song, i) => (
            <SongRow
              key={`${song.id}-${i}`}
              song={song}
              onPlay={() => handlePlayTrack(i)}
              menuItems={[
                { label: 'Play', onClick: () => handlePlayTrack(i) },
                { label: 'Add to Queue', onClick: () => appendToQueue(songToNowPlaying(song)) },
                { label: 'Remove from Playlist', onClick: () => handleRemoveTrack(i), danger: true },
              ]}
            />
          ))}
        </div>
      </div>
    </div>
  );
}
