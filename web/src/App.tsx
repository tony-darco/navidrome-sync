import { BrowserRouter, Routes, Route, useLocation } from 'react-router-dom';
import { useWebSocket } from './hooks/useWebSocket';
import { useCrateColor } from './hooks/useCrateColor';
import { TRANSITIONS } from './styles/design-system';
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
import SearchPage from './pages/SearchPage';
import SettingsPage from './pages/SettingsPage';
import NowPlayingBar from './components/NowPlayingBar';
import AudioManager from './components/AudioManager';
import Sidebar from './components/Sidebar';

function AppContent() {
  useWebSocket();
  const location = useLocation();
  const crate = useCrateColor();
  const isNowPlaying = location.pathname === '/';

  return (
    <div
      className="flex h-screen overflow-hidden"
      style={{
        background: isNowPlaying ? '#0A0A0A' : '#F7F5F0',
        transition: TRANSITIONS.crateColor,
      }}
    >
      <Sidebar crate={crate} />

      <div className="flex-1 flex flex-col min-w-0 relative">
        <main className="flex-1 overflow-y-auto" style={{ paddingBottom: isNowPlaying ? 0 : 80 }}>
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
            <Route path="/search" element={<SearchPage />} />
            <Route path="/settings" element={<SettingsPage />} />
          </Routes>
        </main>

        {!isNowPlaying && <NowPlayingBar crate={crate} />}
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
