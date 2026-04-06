import { getCoverArtUrl } from '../api/navidrome';
import type { Playlist } from '../api/navidrome';

interface PlaylistListProps {
  playlists: Playlist[];
  onSelect: (playlist: Playlist) => void;
}

export default function PlaylistList({ playlists, onSelect }: PlaylistListProps) {
  if (playlists.length === 0) {
    return <p className="text-zinc-500 text-center py-8">No playlists yet</p>;
  }

  return (
    <div className="space-y-1">
      {playlists.map((pl) => (
        <button
          key={pl.id}
          onClick={() => onSelect(pl)}
          className="w-full flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-zinc-800/60 transition-colors text-left"
        >
          {pl.coverArt ? (
            <img
              src={getCoverArtUrl(pl.coverArt, 80)}
              alt={pl.name}
              className="w-12 h-12 rounded object-cover bg-zinc-800 flex-shrink-0"
            />
          ) : (
            <div className="w-12 h-12 rounded bg-zinc-800 flex items-center justify-center flex-shrink-0">
              <span className="text-zinc-500 text-lg">♪</span>
            </div>
          )}
          <div className="min-w-0">
            <p className="text-sm font-medium truncate">{pl.name}</p>
            <p className="text-xs text-zinc-400">{pl.songCount} tracks</p>
          </div>
        </button>
      ))}
    </div>
  );
}
