import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useSyncStore } from '../store/syncStore';
import { getCoverArtUrl } from '../api/navidrome';
import { getDominantColor, type RGB } from '../utils/dominantColor';

export default function NowPlayingBar() {
  const nowPlaying = useSyncStore((s) => s.nowPlaying);
  const isPlaying = useSyncStore((s) => s.isPlaying);
  const myRole = useSyncStore((s) => s.myRole);
  const play = useSyncStore((s) => s.play);
  const pause = useSyncStore((s) => s.pause);
  const next = useSyncStore((s) => s.next);
  const prev = useSyncStore((s) => s.prev);
  const navigate = useNavigate();

  const [color, setColor] = useState<RGB | null>(null);

  useEffect(() => {
    if (!nowPlaying?.coverArtId) return;
    let cancelled = false;
    getDominantColor(getCoverArtUrl(nowPlaying.coverArtId, 80)).then((c) => {
      if (!cancelled) setColor(c);
    });
    return () => { cancelled = true; };
  }, [nowPlaying?.coverArtId]);

  if (!nowPlaying) return null;

  const bg = color
    ? {
        background: `linear-gradient(135deg, rgba(${color.r},${color.g},${color.b},0.85), rgba(${color.r},${color.g},${color.b},0.6))`,
        boxShadow: `0 -4px 24px rgba(${color.r},${color.g},${color.b},0.3)`,
      }
    : { background: 'rgb(24,24,27)' };

  return (
    <div className="fixed bottom-4 left-1/2 -translate-x-1/2 z-50 flex items-center gap-3 rounded-xl px-3 py-2 backdrop-blur-md max-w-lg w-[calc(100%-2rem)]"
      style={bg}
    >
      {/* Cover — clickable to go to Now Playing */}
      <button
        onClick={() => navigate('/')}
        className="shrink-0 cursor-pointer"
      >
        <img
          src={getCoverArtUrl(nowPlaying.coverArtId, 80)}
          alt=""
          className="w-11 h-11 rounded-lg object-cover bg-zinc-800"
        />
      </button>

      {/* Song info — title and artist are separate click targets */}
      <div className="min-w-0 flex-1">
        <p
          className={`text-sm font-semibold truncate text-white ${nowPlaying.albumId ? 'cursor-pointer hover:underline' : ''}`}
          onClick={() => nowPlaying.albumId && navigate(`/albums/${nowPlaying.albumId}`)}
        >
          {nowPlaying.title}
        </p>
        <p
          className={`text-xs truncate text-white/70 ${nowPlaying.artistId ? 'cursor-pointer hover:underline' : ''}`}
          onClick={() => nowPlaying.artistId && navigate(`/artists/${nowPlaying.artistId}`)}
        >
          {nowPlaying.artist}
        </p>
      </div>

      {/* Playback controls */}
      <div className="flex items-center gap-1 shrink-0">
        <button onClick={(e) => { e.stopPropagation(); prev(); }} className="p-1.5 rounded-full hover:bg-white/15 transition-colors cursor-pointer" aria-label="Previous">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5 text-white">
            <path d="M9.195 18.44c1.25.714 2.805-.189 2.805-1.629v-2.34l6.945 3.968c1.25.715 2.805-.188 2.805-1.628V7.19c0-1.44-1.555-2.343-2.805-1.628L12 9.53V7.19c0-1.44-1.555-2.343-2.805-1.628l-7.108 4.061c-1.26.72-1.26 2.536 0 3.256l7.108 4.061Z" />
          </svg>
        </button>

        <button onClick={(e) => { e.stopPropagation(); isPlaying ? pause() : play(); }} className="p-2 rounded-full bg-white/20 hover:bg-white/30 transition-colors cursor-pointer" aria-label={isPlaying ? 'Pause' : 'Play'}>
          {isPlaying ? (
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5 text-white">
              <path fillRule="evenodd" d="M6.75 5.25a.75.75 0 0 1 .75-.75H9a.75.75 0 0 1 .75.75v13.5a.75.75 0 0 1-.75.75H7.5a.75.75 0 0 1-.75-.75V5.25Zm7.5 0A.75.75 0 0 1 15 4.5h1.5a.75.75 0 0 1 .75.75v13.5a.75.75 0 0 1-.75.75H15a.75.75 0 0 1-.75-.75V5.25Z" clipRule="evenodd" />
            </svg>
          ) : (
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5 text-white">
              <path fillRule="evenodd" d="M4.5 5.653c0-1.427 1.529-2.33 2.779-1.643l11.54 6.347c1.295.712 1.295 2.573 0 3.286L7.28 19.99c-1.25.687-2.779-.217-2.779-1.643V5.653Z" clipRule="evenodd" />
            </svg>
          )}
        </button>

        <button onClick={(e) => { e.stopPropagation(); next(); }} className="p-1.5 rounded-full hover:bg-white/15 transition-colors cursor-pointer" aria-label="Next">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5 text-white">
            <path d="M5.055 7.06C3.805 6.347 2.25 7.25 2.25 8.69v6.622c0 1.44 1.555 2.343 2.805 1.628L12 12.97v2.34c0 1.44 1.555 2.343 2.805 1.628l7.108-4.061c1.26-.72 1.26-2.536 0-3.256l-7.108-4.06C13.555 4.715 12 5.617 12 7.058v2.34L5.055 5.44Z" />
          </svg>
        </button>
      </div>

      {/* Role badge */}
      <span
        className={`text-[10px] font-medium px-2 py-0.5 rounded-full shrink-0 ${
          myRole === 'active'
            ? 'bg-white/20 text-white'
            : 'bg-black/20 text-white/60'
        }`}
      >
        {myRole}
      </span>
    </div>
  );
}
