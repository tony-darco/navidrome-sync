import { useState, useEffect, useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { init as initNavidrome, getAlbums, getSongsByGenre } from '../api/navidrome';
import type { Album, Song } from '../api/navidrome';
import { useSyncStore } from '../store/syncStore';
import AlbumGrid from '../components/AlbumGrid';
import SongRow from '../components/SongRow';

function songToNowPlaying(song: Song) {
  return {
    songId: song.id,
    title: song.title,
    artist: song.artist,
    album: song.album,
    albumId: song.albumId,
    artistId: song.artistId,
    coverArtId: song.coverArt,
    durationSecs: song.duration,
    positionSecs: 0,
  };
}

type Tab = 'albums' | 'songs';

export default function GenreDetail() {
  const { name } = useParams<{ name: string }>();
  const genreName = name ? decodeURIComponent(name) : '';
  const navigate = useNavigate();
  const playQueue = useSyncStore((s) => s.playQueue);
  const appendToQueue = useSyncStore((s) => s.appendToQueue);

  const [tab, setTab] = useState<Tab>('albums');
  const [albums, setAlbums] = useState<Album[]>([]);
  const [songs, setSongs] = useState<Song[]>([]);
  const [loadingAlbums, setLoadingAlbums] = useState(true);
  const [loadingSongs, setLoadingSongs] = useState(true);

  useEffect(() => {
    initNavidrome();
  }, []);

  useEffect(() => {
    if (!genreName) return;
    let cancelled = false;
    queueMicrotask(() => { if (!cancelled) setLoadingAlbums(true); });
    getAlbums('byGenre', 500, 0, genreName)
      .then((result) => { if (!cancelled) setAlbums(result); })
      .catch(() => {})
      .finally(() => { if (!cancelled) setLoadingAlbums(false); });
    return () => { cancelled = true; };
  }, [genreName]);

  useEffect(() => {
    if (!genreName) return;
    let cancelled = false;
    queueMicrotask(() => { if (!cancelled) setLoadingSongs(true); });
    getSongsByGenre(genreName, 200)
      .then((result) => { if (!cancelled) setSongs(result); })
      .catch(() => {})
      .finally(() => { if (!cancelled) setLoadingSongs(false); });
    return () => { cancelled = true; };
  }, [genreName]);

  const handleSelectAlbum = useCallback((album: Album) => {
    navigate(`/albums/${album.id}`);
  }, [navigate]);

  const handlePlaySong = useCallback((song: Song) => {
    const queue = songs.map(songToNowPlaying);
    const idx = songs.findIndex((s) => s.id === song.id);
    playQueue(queue, idx >= 0 ? idx : 0);
  }, [songs, playQueue]);

  return (
    <div className="p-6 max-w-6xl mx-auto">
      <h1 className="text-2xl font-bold mb-4">{genreName}</h1>

      {/* Tab switcher */}
      <div className="flex items-center gap-2 mb-6">
        {(['albums', 'songs'] as Tab[]).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={`text-xs px-3 py-1.5 rounded-full border transition-colors ${
              tab === t
                ? 'border-white/30 bg-white/10 text-white'
                : 'border-zinc-700 text-zinc-400 hover:text-white hover:border-zinc-500'
            }`}
          >
            {t === 'albums' ? 'Albums' : 'Songs'}
          </button>
        ))}
      </div>

      {tab === 'albums' && (
        <>
          {loadingAlbums && albums.length === 0 ? (
            <p className="text-zinc-500 text-center py-8">Loading albums…</p>
          ) : albums.length === 0 ? (
            <p className="text-zinc-500 text-center py-8">No albums in this genre.</p>
          ) : (
            <AlbumGrid albums={albums} onSelect={handleSelectAlbum} />
          )}
        </>
      )}

      {tab === 'songs' && (
        <>
          {loadingSongs && songs.length === 0 ? (
            <p className="text-zinc-500 text-center py-8">Loading songs…</p>
          ) : songs.length === 0 ? (
            <p className="text-zinc-500 text-center py-8">No songs in this genre.</p>
          ) : (
            <div className="space-y-0">
              {songs.map((song) => (
                <SongRow
                  key={song.id}
                  song={song}
                  onPlay={() => handlePlaySong(song)}
                  menuItems={[
                    { label: 'Play', onClick: () => handlePlaySong(song) },
                    { label: 'Add to Queue', onClick: () => appendToQueue(songToNowPlaying(song)) },
                  ]}
                />
              ))}
            </div>
          )}
        </>
      )}
    </div>
  );
}
