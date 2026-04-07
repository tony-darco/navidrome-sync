import type { Playlist } from '../api/navidrome';
import { getCoverArtUrl } from '../api/navidrome';

interface PlaylistGridProps {
  playlists: Playlist[];
  onSelect: (playlist: Playlist) => void;
}

export default function PlaylistGrid({ playlists, onSelect }: PlaylistGridProps) {
  if (playlists.length === 0) {
    return <p className="text-zinc-500 text-center py-8">No playlists yet</p>;
  }

  return (
    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
      {playlists.map((pl) => (
        <button
          key={pl.id}
          onClick={() => onSelect(pl)}
          className="group text-left rounded-lg p-2 hover:bg-zinc-800/60 transition-colors"
        >
          {pl.coverArt ? (
            <img
              src={getCoverArtUrl(pl.coverArt, 300)}
              alt={pl.name}
              className="w-full aspect-square rounded-md object-cover bg-zinc-800 mb-2"
              loading="lazy"
            />
          ) : (
            <div className="w-full aspect-square rounded-md bg-zinc-800 mb-2 flex items-center justify-center">
              <span className="text-zinc-500 text-4xl">♪</span>
            </div>
          )}
          <p className="text-sm font-medium truncate">{pl.name}</p>
          <p className="text-xs text-zinc-400">{pl.songCount} tracks</p>
        </button>
      ))}
    </div>
  );
}
