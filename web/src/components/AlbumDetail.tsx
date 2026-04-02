import type { Song, Album } from '../api/navidrome';
import { getCoverArtUrl } from '../api/navidrome';

interface AlbumDetailProps {
  album: Album;
  songs: Song[];
  onPlayTrack: (song: Song, albumSongs: Song[]) => void;
  onBack: () => void;
}

function formatDuration(secs: number) {
  const m = Math.floor(secs / 60);
  const s = secs % 60;
  return `${m}:${s.toString().padStart(2, '0')}`;
}

export default function AlbumDetail({ album, songs, onPlayTrack, onBack }: AlbumDetailProps) {
  return (
    <div>
      <button
        onClick={onBack}
        className="text-sm text-zinc-400 hover:text-white mb-4 flex items-center gap-1"
      >
        <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z" /></svg>
        Back
      </button>

      <div className="flex gap-4 mb-6">
        <img
          src={getCoverArtUrl(album.coverArt, 300)}
          alt={album.name}
          className="w-32 h-32 rounded-lg object-cover bg-zinc-800"
        />
        <div className="flex flex-col justify-end">
          <h2 className="text-xl font-semibold">{album.name}</h2>
          <p className="text-zinc-400">{album.artist}</p>
          {album.year && <p className="text-zinc-500 text-sm">{album.year}</p>}
          <p className="text-zinc-600 text-xs mt-1">{album.songCount} tracks</p>
        </div>
      </div>

      <div className="divide-y divide-zinc-800/50">
        {songs.map((song) => (
          <button
            key={song.id}
            onClick={() => onPlayTrack(song, songs)}
            className="w-full flex items-center gap-3 py-2.5 px-2 hover:bg-zinc-800/40 rounded transition-colors text-left"
          >
            <span className="w-6 text-right text-xs text-zinc-600 tabular-nums">
              {song.track}
            </span>
            <div className="flex-1 min-w-0">
              <p className="text-sm truncate">{song.title}</p>
              <p className="text-xs text-zinc-500 truncate">{song.artist}</p>
            </div>
            <span className="text-xs text-zinc-600 tabular-nums">
              {formatDuration(song.duration)}
            </span>
          </button>
        ))}
      </div>
    </div>
  );
}
