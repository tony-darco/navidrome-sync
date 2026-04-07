import { useState, useEffect, useRef, useCallback } from 'react';
import { useSyncStore } from '../store/syncStore';
import { useAlbums, useAlbumDetail, useSearch } from '../hooks/useNavidrome';
import { init as initNalidrome } from '../api/navidrome';
import type { Song } from '../api/navidrome';
import AlbumGrid from '../components/AlbumGrid';
import AlbumDetail from '../components/AlbumDetail';
import type { Album } from '../api/navidrome';  

export default function Library() {
  const { albums, loading, error } = useAlbums();
  const [selectedAlbumId, setSelectedAlbumId] = useState<string | null>(null);
  const { album: albumDetail, songs, loading: detailLoading } = useAlbumDetail(selectedAlbumId);
  const { results: searchResults, loading: searchLoading, doSearch } = useSearch();
  const [query, setQuery] = useState('');
  const [isSearching, setIsSearching] = useState(false);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

  const playQueue = useSyncStore((s) => s.playQueue);

  // Initialize the navidrome API config on mount
  useEffect(() => {
    initNalidrome();
  }, []);

  const handleSearchInput = useCallback(
    (value: string) => {
      setQuery(value);
      clearTimeout(debounceRef.current);
      if (!value.trim()) {
        setIsSearching(false);
        return;
      }
      setIsSearching(true);
      debounceRef.current = setTimeout(() => {
        doSearch(value);
      }, 300);
    },
    [doSearch],
  );

  const songToNowPlaying = useCallback(
    (song: Song) => ({
      songId: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      coverArtId: song.coverArt,
      durationSecs: song.duration,
      positionSecs: 0,
    }),
    [],
  );

  const handlePlayTrack = useCallback(
    (song: Song, albumSongs?: Song[]) => {
      const list = albumSongs ?? [song];
      const queue = list.map(songToNowPlaying);
      const startIndex = list.findIndex((s) => s.id === song.id);
      playQueue(queue, startIndex >= 0 ? startIndex : 0);
    },
    [playQueue, songToNowPlaying],
  );

  const handleSelectAlbum = useCallback((album: Album) => {
    setSelectedAlbumId(album.id);
  }, []);

  // Album detail view
  if (selectedAlbumId && albumDetail) {
    return (
      <AlbumDetail
        album={albumDetail}
        songs={songs}
        onPlayTrack={(song, albumSongs) => handlePlayTrack(song, albumSongs)}
        onBack={() => setSelectedAlbumId(null)}
      />
    );
  }

  if (selectedAlbumId && detailLoading) {
    return <div className="p-4 text-center text-zinc-500">Loading album...</div>;
  }

  return (
    <div className="p-4 max-w-5xl mx-auto">
      {/* Search bar */}
      <div className="mb-6">
        <input
          type="text"
          value={query}
          onChange={(e) => handleSearchInput(e.target.value)}
          placeholder="Search albums and songs..."
          className="w-full bg-zinc-900 border border-zinc-800 rounded-lg px-4 py-2.5 text-sm text-zinc-100 placeholder-zinc-600 focus:outline-none focus:border-zinc-600"
        />
      </div>

      {error && <p className="text-red-400 text-sm mb-4">{error}</p>}

      {/* Search results */}
      {isSearching ? (
        <div>
          {searchLoading && <p className="text-zinc-500 text-sm mb-4">Searching...</p>}
          {searchResults.albums.length > 0 && (
            <div className="mb-8">
              <h3 className="text-sm font-medium text-zinc-400 mb-3">Albums</h3>
              <AlbumGrid albums={searchResults.albums} onSelect={handleSelectAlbum} />
            </div>
          )}
          {searchResults.songs.length > 0 && (
            <div>
              <h3 className="text-sm font-medium text-zinc-400 mb-3">Songs</h3>
              <div className="divide-y divide-zinc-800/50">
                {searchResults.songs.map((song) => (
                  <button
                    key={song.id}
                    onClick={() => handlePlayTrack(song)}
                    className="w-full flex items-center gap-3 py-2.5 px-2 hover:bg-zinc-800/40 rounded transition-colors text-left"
                  >
                    <div className="flex-1 min-w-0">
                      <p className="text-sm truncate">{song.title}</p>
                      <p className="text-xs text-zinc-500 truncate">
                        {song.artist} — {song.album}
                      </p>
                    </div>
                  </button>
                ))}
              </div>
            </div>
          )}
          {!searchLoading && searchResults.albums.length === 0 && searchResults.songs.length === 0 && (
            <p className="text-zinc-500 text-center py-8">No results</p>
          )}
        </div>
      ) : (
        <>
          {loading && albums.length === 0 && (
            <p className="text-zinc-500 text-center py-8">Loading albums...</p>
          )}
          <AlbumGrid albums={albums} onSelect={handleSelectAlbum} />
        </>
      )}
    </div>
  );
}
