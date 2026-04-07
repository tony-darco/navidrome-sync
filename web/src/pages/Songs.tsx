import { useState, useMemo, useCallback } from 'react';
import { useSongs } from '../hooks/useNavidrome';
import { useSyncStore } from '../store/syncStore';
import type { Song } from '../api/navidrome';
import SongRow from '../components/SongRow';

type SortOption = 'title' | 'artist' | 'album';

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

export default function Songs() {
  const { songs, loading, error, loadMore } = useSongs();
  const [filter, setFilter] = useState('');
  const [sort, setSort] = useState<SortOption>('title');
  const playQueue = useSyncStore((s) => s.playQueue);
  const appendToQueue = useSyncStore((s) => s.appendToQueue);

  const displayed = useMemo(() => {
    let list = songs;
    if (filter.trim()) {
      const q = filter.toLowerCase();
      list = list.filter(
        (s) =>
          s.title.toLowerCase().includes(q) ||
          s.artist.toLowerCase().includes(q) ||
          s.album.toLowerCase().includes(q),
      );
    }
    const sorted = [...list];
    switch (sort) {
      case 'title':
        sorted.sort((a, b) => a.title.localeCompare(b.title));
        break;
      case 'artist':
        sorted.sort((a, b) => a.artist.localeCompare(b.artist));
        break;
      case 'album':
        sorted.sort((a, b) => a.album.localeCompare(b.album));
        break;
    }
    return sorted;
  }, [songs, filter, sort]);

  const handlePlay = useCallback(
    (song: Song) => {
      const queue = displayed.map(songToNowPlaying);
      const idx = displayed.findIndex((s) => s.id === song.id);
      playQueue(queue, idx >= 0 ? idx : 0);
    },
    [displayed, playQueue],
  );

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold">Songs</h1>
        <div className="flex items-center gap-2">
          {(['title', 'artist', 'album'] as SortOption[]).map((opt) => (
            <button
              key={opt}
              onClick={() => setSort(opt)}
              className={`text-xs px-3 py-1.5 rounded-full border transition-colors ${
                sort === opt
                  ? 'border-white/30 bg-white/10 text-white'
                  : 'border-zinc-700 text-zinc-400 hover:text-white hover:border-zinc-500'
              }`}
            >
              {opt.charAt(0).toUpperCase() + opt.slice(1)}
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
          placeholder="Filter songs…"
          className="w-full max-w-sm bg-zinc-900 border border-zinc-800 rounded-lg px-4 py-2 text-sm text-zinc-100 placeholder-zinc-600 focus:outline-none focus:border-zinc-600"
        />
      </div>

      {error && <p className="text-red-400 text-sm mb-4">{error}</p>}

      {loading && songs.length === 0 ? (
        <p className="text-zinc-500 text-center py-8">Loading songs…</p>
      ) : displayed.length === 0 ? (
        <p className="text-zinc-500 text-center py-8">No songs found</p>
      ) : (
        <div>
          {displayed.map((song) => (
            <SongRow
              key={song.id}
              song={song}
              onPlay={() => handlePlay(song)}
              menuItems={[
                { label: 'Play', onClick: () => handlePlay(song) },
                { label: 'Add to Queue', onClick: () => appendToQueue(songToNowPlaying(song)) },
              ]}
            />
          ))}
          {songs.length >= 50 && (
            <button
              onClick={() => loadMore(songs.length)}
              className="mt-4 w-full py-2 text-sm text-zinc-400 hover:text-white border border-zinc-800 rounded-lg hover:border-zinc-600 transition-colors"
            >
              Load more
            </button>
          )}
        </div>
      )}
    </div>
  );
}
