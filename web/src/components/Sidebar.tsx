import { useState, useRef, useCallback } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { useSyncStore } from '../store/syncStore';
import { usePlaylists } from '../hooks/usePlaylists';
import { useSearch } from '../hooks/useNavidrome';
import { getCoverArtUrl } from '../api/navidrome';
import type { Album, Song } from '../api/navidrome';

export default function Sidebar({ bgStyle }: { bgStyle?: React.CSSProperties }) {
  const isConnected = useSyncStore((s) => s.isConnected);
  const { playlists } = usePlaylists();
  const { results, loading: searchLoading, doSearch } = useSearch();
  const [query, setQuery] = useState('');
  const [searchOpen, setSearchOpen] = useState(false);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const navigate = useNavigate();
  const playQueue = useSyncStore((s) => s.playQueue);

  const recentPlaylists = playlists.slice(0, 4);

  const handleSearchInput = useCallback(
    (value: string) => {
      setQuery(value);
      clearTimeout(debounceRef.current);
      if (!value.trim()) {
        setSearchOpen(false);
        return;
      }
      setSearchOpen(true);
      debounceRef.current = setTimeout(() => {
        doSearch(value);
      }, 300);
    },
    [doSearch],
  );

  const handleSelectAlbum = (album: Album) => {
    setQuery('');
    setSearchOpen(false);
    navigate(`/albums/${album.id}`);
  };

  const handlePlaySong = (song: Song) => {
    setQuery('');
    setSearchOpen(false);
    const np = {
      songId: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      coverArtId: song.coverArt,
      durationSecs: song.duration,
      positionSecs: 0,
    };
    playQueue([np], 0);
    navigate('/');
  };

  const linkClass = ({ isActive }: { isActive: boolean }) =>
    `flex items-center gap-3 px-3 py-1.5 rounded-lg text-sm transition-colors ${
      isActive
        ? 'bg-white/10 text-white font-medium'
        : 'text-zinc-400 hover:text-white hover:bg-white/5'
    }`;

  return (
    <aside className="w-60 flex-shrink-0 border-r border-zinc-800/50 flex flex-col h-full overflow-hidden backdrop-blur-md" style={bgStyle ?? { background: 'rgba(24,24,27,0.8)' }}>
      {/* Search */}
      <div className="p-3 relative">
        <div className="relative">
          <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="11" cy="11" r="8" />
            <path d="m21 21-4.35-4.35" />
          </svg>
          <input
            type="text"
            value={query}
            onChange={(e) => handleSearchInput(e.target.value)}
            onFocus={() => { if (query.trim()) setSearchOpen(true); }}
            onBlur={() => setTimeout(() => setSearchOpen(false), 200)}
            placeholder="Search"
            className="w-full bg-zinc-800 border border-zinc-700 rounded-lg pl-9 pr-3 py-2 text-sm text-zinc-100 placeholder-zinc-500 focus:outline-none focus:border-zinc-500"
          />
        </div>

        {/* Search results dropdown */}
        {searchOpen && (
          <div className="absolute left-3 right-3 top-full mt-1 z-50 bg-zinc-800 border border-zinc-700 rounded-lg shadow-xl max-h-80 overflow-y-auto">
            {searchLoading && <p className="text-xs text-zinc-500 p-3">Searching…</p>}
            {results.albums.length > 0 && (
              <div className="p-2">
                <p className="text-[10px] font-medium text-zinc-500 uppercase tracking-wider px-2 mb-1">Albums</p>
                {results.albums.slice(0, 5).map((album) => (
                  <button
                    key={album.id}
                    onMouseDown={() => handleSelectAlbum(album)}
                    className="w-full flex items-center gap-2 px-2 py-1.5 rounded hover:bg-white/10 text-left"
                  >
                    <img src={getCoverArtUrl(album.coverArt, 40)} alt="" className="w-8 h-8 rounded object-cover bg-zinc-700" />
                    <div className="min-w-0 flex-1">
                      <p className="text-sm truncate">{album.name}</p>
                      <p className="text-xs text-zinc-500 truncate">{album.artist}</p>
                    </div>
                  </button>
                ))}
              </div>
            )}
            {results.songs.length > 0 && (
              <div className="p-2 border-t border-zinc-700">
                <p className="text-[10px] font-medium text-zinc-500 uppercase tracking-wider px-2 mb-1">Songs</p>
                {results.songs.slice(0, 5).map((song) => (
                  <button
                    key={song.id}
                    onMouseDown={() => handlePlaySong(song)}
                    className="w-full flex items-center gap-2 px-2 py-1.5 rounded hover:bg-white/10 text-left"
                  >
                    <div className="min-w-0 flex-1">
                      <p className="text-sm truncate">{song.title}</p>
                      <p className="text-xs text-zinc-500 truncate">{song.artist}</p>
                    </div>
                  </button>
                ))}
              </div>
            )}
            {!searchLoading && results.albums.length === 0 && results.songs.length === 0 && query.trim() && (
              <p className="text-sm text-zinc-500 text-center py-4">No results</p>
            )}
          </div>
        )}
      </div>

      {/* Navigation */}
      <nav className="flex-1 overflow-y-auto px-2 pb-4 space-y-6">
        {/* Now Playing */}
        <div>
          <NavLink to="/" end className={linkClass}>
            <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
              <path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z" />
            </svg>
            Now Playing
          </NavLink>
        </div>

        {/* Library section */}
        <div>
          <p className="px-3 mb-2 text-[11px] font-semibold text-zinc-500 uppercase tracking-wider">Library</p>
          <div className="space-y-0.5">
            <NavLink to="/albums" className={linkClass}>
              <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 14.5c-2.49 0-4.5-2.01-4.5-4.5S9.51 7.5 12 7.5s4.5 2.01 4.5 4.5-2.01 4.5-4.5 4.5zm0-5.5c-.55 0-1 .45-1 1s.45 1 1 1 1-.45 1-1-.45-1-1-1z" />
              </svg>
              Albums
            </NavLink>
            <NavLink to="/artists" className={linkClass}>
              <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" />
              </svg>
              Artists
            </NavLink>
            <NavLink to="/songs" className={linkClass}>
              <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                <path d="M15 6H3v2h12V6zm0 4H3v2h12v-2zM3 16h8v-2H3v2zM17 6v8.18c-.31-.11-.65-.18-1-.18-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3V8h3V6h-5z" />
              </svg>
              Songs
            </NavLink>
          </div>
        </div>

        {/* Playlists section */}
        <div>
          <p className="px-3 mb-2 text-[11px] font-semibold text-zinc-500 uppercase tracking-wider">Playlists</p>
          <div className="space-y-0.5">
            <NavLink to="/playlists" end className={linkClass}>
              <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                <path d="M4 10h12v2H4zm0-4h12v2H4zm0 8h8v2H4zm10 0v6l5-3z" />
              </svg>
              All Playlists
            </NavLink>
            {recentPlaylists.map((pl) => (
              <NavLink key={pl.id} to={`/playlists/${pl.id}`} className={linkClass}>
                {pl.coverArt ? (
                  <img
                    src={getCoverArtUrl(pl.coverArt, 40)}
                    alt=""
                    className="w-5 h-5 rounded object-cover bg-zinc-700 flex-shrink-0"
                  />
                ) : (
                  <span className="w-5 h-5 rounded bg-zinc-700 flex items-center justify-center text-[10px] text-zinc-400 flex-shrink-0">♪</span>
                )}
                <span className="truncate">{pl.name}</span>
              </NavLink>
            ))}
          </div>
        </div>
      </nav>

      {/* Connection status */}
      <div className="px-4 py-3 border-t border-zinc-800 flex items-center gap-2">
        <span className={`w-2 h-2 rounded-full ${isConnected ? 'bg-blue-500' : 'bg-red-500'}`} />
        <span className="text-xs text-zinc-500">{isConnected ? 'Connected' : 'Disconnected'}</span>
      </div>
    </aside>
  );
}
