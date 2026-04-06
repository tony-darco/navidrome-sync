import { BrowserRouter, Routes, Route, NavLink, useLocation } from 'react-router-dom';
import { useWebSocket } from './hooks/useWebSocket';
import { useSyncStore } from './store/syncStore';
import NowPlaying from './pages/NowPlaying';
import Library from './pages/Library';
import Playlists from './pages/Playlists';
import NowPlayingBar from './components/NowPlayingBar';
import AudioManager from './components/AudioManager';

function AppContent() {
  useWebSocket();
  const isConnected = useSyncStore((s) => s.isConnected);
  const location = useLocation();
  const isNowPlaying = location.pathname === '/';

  return (
    <div className="flex flex-col h-screen bg-zinc-950 text-zinc-100">
      <nav className="sticky top-0 z-50 flex items-center gap-4 px-4 py-3 border-b border-zinc-800 bg-zinc-950">
        <span className="font-semibold text-sm tracking-wide text-zinc-400">navidrome-sync</span>
        <NavLink
          to="/"
          end
          className={({ isActive }) =>
            `text-sm px-3 py-1 rounded ${isActive ? 'bg-zinc-800 text-white' : 'text-zinc-400 hover:text-zinc-200'}`
          }
        >
          Now Playing
        </NavLink>
        <NavLink
          to="/library"
          className={({ isActive }) =>
            `text-sm px-3 py-1 rounded ${isActive ? 'bg-zinc-800 text-white' : 'text-zinc-400 hover:text-zinc-200'}`
          }
        >
          Library
        </NavLink>
        <NavLink
          to="/playlists"
          className={({ isActive }) =>
            `text-sm px-3 py-1 rounded ${isActive ? 'bg-zinc-800 text-white' : 'text-zinc-400 hover:text-zinc-200'}`
          }
        >
          Playlists
        </NavLink>
        <div className="ml-auto flex items-center gap-2">
          <span
            className={`w-2 h-2 rounded-full ${isConnected ? 'bg-blue-500' : 'bg-red-500'}`}
          />
          <span className="text-xs text-zinc-500">
            {isConnected ? 'connected' : 'disconnected'}
          </span>
        </div>
      </nav>

      <main className={`flex-1 overflow-y-auto ${isNowPlaying ? '' : 'pb-24'}`}>
        <Routes>
          <Route path="/" element={<NowPlaying />} />
          <Route path="/library" element={<Library />} />
          <Route path="/playlists" element={<Playlists />} />
        </Routes>
      </main>

      {!isNowPlaying && <NowPlayingBar />}
      <AudioManager />
    </div>
  );
}

function App() {
  return (
    <BrowserRouter>
      <AppContent />
    </BrowserRouter>
  );
}

export default App;
