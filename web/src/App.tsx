import { useEffect, useState } from 'react';
import { BrowserRouter, Routes, Route, useLocation } from 'react-router-dom';
import { useWebSocket } from './hooks/useWebSocket';
import NowPlaying from './pages/NowPlaying';
import Albums from './pages/Albums';
import Artists from './pages/Artists';
import ArtistDetail from './pages/ArtistDetail';
import Songs from './pages/Songs';
import Playlists from './pages/Playlists';
import Genres from './pages/Genres';
import GenreDetail from './pages/GenreDetail';
import AlbumDetailPage from './pages/AlbumDetailPage';
import PlaylistDetailPage from './pages/PlaylistDetailPage';
import NowPlayingBar from './components/NowPlayingBar';
import AudioManager from './components/AudioManager';
import Sidebar from './components/Sidebar';
import { useSyncStore } from './store/syncStore';
import { getCoverArtUrl } from './api/navidrome';
import { getDominantColor, type RGB } from './utils/dominantColor';

function AppContent() {
  useWebSocket();
  const location = useLocation();
  const isNowPlaying = location.pathname === '/';
  const coverArtId = useSyncStore((s) => s.nowPlaying?.coverArtId);
  const [color, setColor] = useState<RGB | null>(null);

  useEffect(() => {
    if (!coverArtId) { setColor(null); return; }
    let cancelled = false;
    getDominantColor(getCoverArtUrl(coverArtId, 80)).then((c) => {
      if (!cancelled) setColor(c);
    });
    return () => { cancelled = true; };
  }, [coverArtId]);

  const mainBg = color
    ? {
        background: `linear-gradient(to bottom, rgba(${color.r},${color.g},${color.b},0.45) 0%, rgba(${color.r},${color.g},${color.b},0.25) 40%, rgba(${color.r},${color.g},${color.b},0.1) 100%)`,
      }
    : undefined;

  const sidebarBg = color
    ? {
        background: `linear-gradient(to bottom, rgba(${color.r},${color.g},${color.b},0.25) 0%, rgba(${color.r},${color.g},${color.b},0.1) 100%)`,
      }
    : undefined;

  return (
    <div className="flex h-screen bg-zinc-950 text-zinc-100">
      <Sidebar bgStyle={sidebarBg} />

      <div className="flex-1 flex flex-col min-w-0" style={mainBg}>
        <main className={`flex-1 overflow-y-auto ${isNowPlaying ? '' : 'pb-20'}`}>
          <Routes>
            <Route path="/" element={<NowPlaying />} />
            <Route path="/albums" element={<Albums />} />
            <Route path="/albums/:id" element={<AlbumDetailPage />} />
            <Route path="/artists" element={<Artists />} />
            <Route path="/artists/:id" element={<ArtistDetail />} />
            <Route path="/songs" element={<Songs />} />
            <Route path="/genres" element={<Genres />} />
            <Route path="/genres/:name" element={<GenreDetail />} />
            <Route path="/playlists" element={<Playlists />} />
            <Route path="/playlists/:id" element={<PlaylistDetailPage />} />
          </Routes>
        </main>

        {!isNowPlaying && <NowPlayingBar />}
        <AudioManager />
      </div>
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
