import { useEffect, useState } from 'react';
import { getArtistInfo2 } from '../api/navidrome';

const placeholder = (
  <svg className="w-1/3 h-1/3 text-zinc-600" viewBox="0 0 24 24" fill="currentColor">
    <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" />
  </svg>
);

export default function ArtistImage({ artistId, className }: { artistId: string; className?: string }) {
  const [src, setSrc] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    getArtistInfo2(artistId).then((info) => {
      if (cancelled) return;
      setSrc(info.largeImageUrl ?? info.mediumImageUrl ?? info.smallImageUrl ?? null);
    });
    return () => { cancelled = true; };
  }, [artistId]);

  return (
    <div className={`rounded-full bg-zinc-800 flex items-center justify-center overflow-hidden ${className ?? ''}`}>
      {src ? (
        <img src={src} alt="" className="w-full h-full object-cover" />
      ) : (
        placeholder
      )}
    </div>
  );
}
