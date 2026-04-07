import { BrowserRouter, Routes, Route, useLocation } from 'react-router-dom';
import { useWebSocket } from './hooks/useWebSocket';
import NowPlaying from './pages/NowPlaying';
import Albums from './pages/Albums';
import Artists from './pages/Artists';
import ArtistDetail from './pages/ArtistDetail';
import Songs from './pages/Songs';
import Playlists from './pages/Playlists';
import AlbumDetailPage from './pages/AlbumDetailPage';
import PlaylistDetailPage from './pages/PlaylistDetailPage';
import NowPlayingBar from './components/NowPlayingBar';
import AudioManager from './components/AudioManager';
import Sidebar from './components/Sidebar';

function AppContent() {
  useWebSocket();
  const location = useLocation();
  const isNowPlaying = location.pathname === '/';

  return (
    <div className="flex h-screen bg-zinc-950 text-zinc-100">
      <Sidebar />

      <div className="flex-1 flex flex-col min-w-0">
        <main className={`flex-1 overflow-y-auto ${isNowPlaying ? '' : 'pb-20'}`}>
          <Routes>
            <Route path="/" element={<NowPlaying />} />
            <Route path="/albums" element={<Albums />} />
            <Route path="/albums/:id" element={<AlbumDetailPage />} />
            <Route path="/artists" element={<Artists />} />
            <Route path="/artists/:id" element={<ArtistDetail />} />
            <Route path="/songs" element={<Songs />} />
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
