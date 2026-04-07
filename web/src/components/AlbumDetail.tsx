import { useState, useEffect } from 'react';
import type { Song, Album } from '../api/navidrome';
import { getCoverArtUrl } from '../api/navidrome';
import { useSyncStore } from '../store/syncStore';
import { getDominantColor, type RGB } from '../utils/dominantColor';
import DetailHeader from './DetailHeader';
import SongRow from './SongRow';

interface AlbumDetailProps {
  album: Album;
  songs: Song[];
  onPlayTrack: (song: Song, albumSongs: Song[]) => void;
  onBack: () => void;
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

export default function AlbumDetail({ album, songs, onPlayTrack, onBack }: AlbumDetailProps) {
  const [dominantColor, setDominantColor] = useState<RGB | null>(null);
  const toggleShuffle = useSyncStore((s) => s.toggleShuffle);
  const playQueue = useSyncStore((s) => s.playQueue);
  const appendToQueue = useSyncStore((s) => s.appendToQueue);

  useEffect(() => {
    getDominantColor(getCoverArtUrl(album.coverArt, 50)).then(setDominantColor);
  }, [album.coverArt]);

  const handlePlayAll = () => {
    const queue = songs.map(songToNowPlaying);
    playQueue(queue, 0);
  };

  const handleShuffle = () => {
    toggleShuffle();
    handlePlayAll();
  };

  const meta = [album.year, `${album.songCount} tracks`].filter(Boolean).join(' \u00b7 ');
  const c = dominantColor ?? { r: 30, g: 30, b: 30 };
  const moodBg = {
    background: `linear-gradient(to bottom, rgba(${c.r},${c.g},${c.b},0.55) 0%, rgba(${c.r},${c.g},${c.b},0.35) 50%, rgba(${c.r},${c.g},${c.b},0.2) 100%)`,
    backgroundColor: `rgb(${Math.round(c.r * 0.15)},${Math.round(c.g * 0.15)},${Math.round(c.b * 0.15)})`,
  };

  return (
    <div className="min-h-full" style={moodBg}>
      <div className="px-6 pt-6 pb-12 max-w-4xl mx-auto">
        <DetailHeader
          coverArtUrl={getCoverArtUrl(album.coverArt, 600)}
          title={album.name}
          subtitle={album.artist}
          meta={meta}
          onShuffle={handleShuffle}
          onPlay={handlePlayAll}
          onBack={onBack}
        />

        <div>
          {songs.map((song) => (
            <SongRow
              key={song.id}
              song={song}
              onPlay={() => onPlayTrack(song, songs)}
              menuItems={[
                { label: 'Play', onClick: () => onPlayTrack(song, songs) },
                { label: 'Add to Queue', onClick: () => appendToQueue(songToNowPlaying(song)) },
              ]}
            />
          ))}
        </div>
      </div>
    </div>
  );
}
