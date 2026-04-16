import { useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useAlbumDetail } from '../hooks/useNavidrome';
import { useSyncStore } from '../store/syncStore';
import AlbumDetail from '../components/AlbumDetail';
import type { Song } from '../api/navidrome';

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

export default function AlbumDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { album, songs, loading } = useAlbumDetail(id ?? null);
  const navigate = useNavigate();
  const playQueue = useSyncStore((s) => s.playQueue);

  const handlePlayTrack = useCallback(
    (song: Song, albumSongs?: Song[]) => {
      const list = albumSongs ?? [song];
      const queue = list.map(songToNowPlaying);
      const startIndex = list.findIndex((s) => s.id === song.id);
      playQueue(queue, startIndex >= 0 ? startIndex : 0);
    },
    [playQueue],
  );

  if (loading) {
    return <div className="p-6 text-center text-zinc-500">Loading album…</div>;
  }

  if (!album) {
    return <div className="p-6 text-center text-zinc-500">Album not found</div>;
  }

  return (
    <AlbumDetail
      album={album}
      songs={songs}
      onPlayTrack={(song, albumSongs) => handlePlayTrack(song, albumSongs)}
      onBack={() => navigate(-1)}
    />
  );
}
