import type { Album } from '../api/navidrome';
import { getCoverArtUrl } from '../api/navidrome';

interface AlbumGridProps {
  albums: Album[];
  onSelect: (album: Album) => void;
}

export default function AlbumGrid({ albums, onSelect }: AlbumGridProps) {
  if (albums.length === 0) {
    return <p className="text-zinc-500 text-center py-8">No albums found</p>;
  }

  return (
    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
      {albums.map((album) => (
        <button
          key={album.id}
          onClick={() => onSelect(album)}
          className="group text-left rounded-lg p-2 hover:bg-zinc-800/60 transition-colors"
        >
          <img
            src={getCoverArtUrl(album.coverArt, 300)}
            alt={album.name}
            className="w-full aspect-square rounded-md object-cover bg-zinc-800 mb-2"
            loading="lazy"
          />
          <p className="text-sm font-medium truncate">{album.name}</p>
          <p className="text-xs text-zinc-400 truncate">{album.artist}</p>
        </button>
      ))}
    </div>
  );
}
