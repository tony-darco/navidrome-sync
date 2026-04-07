import { useState, useRef, useEffect } from 'react';
import type { Song } from '../api/navidrome';
import { getCoverArtUrl } from '../api/navidrome';

export interface MenuItem {
  label: string;
  onClick: () => void;
  danger?: boolean;
}

interface SongRowProps {
  song: Song;
  onPlay: () => void;
  menuItems: MenuItem[];
}

function formatDuration(secs: number) {
  const m = Math.floor(secs / 60);
  const s = secs % 60;
  return `${m}:${s.toString().padStart(2, '0')}`;
}

export default function SongRow({ song, onPlay, menuItems }: SongRowProps) {
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!menuOpen) return;
    function handleClick(e: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setMenuOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, [menuOpen]);

  return (
    <div className="flex items-center gap-3 px-2 py-2.5 hover:bg-white/5 rounded-lg transition-colors border-b border-white/5 last:border-b-0">
      {/* Clickable area: thumbnail + title + artist + duration */}
      <button
        onClick={onPlay}
        className="flex items-center gap-3 flex-1 min-w-0 text-left"
      >
        {song.coverArt ? (
          <img
            src={getCoverArtUrl(song.coverArt, 80)}
            alt=""
            className="w-11 h-11 rounded-md object-cover bg-zinc-800 flex-shrink-0"
          />
        ) : (
          <div className="w-11 h-11 rounded-md bg-zinc-800 flex-shrink-0" />
        )}
        <span className="flex-1 text-sm text-zinc-100 truncate">{song.title}</span>
        <span className="text-sm text-zinc-400 truncate flex-shrink-0 max-w-[200px] hidden sm:block">{song.artist}</span>
        <span className="text-sm text-zinc-500 tabular-nums flex-shrink-0 ml-3">
          {formatDuration(song.duration)}
        </span>
      </button>

      {/* Menu button */}
      <div className="relative flex-shrink-0" ref={menuRef}>
        <button
          onClick={() => setMenuOpen((o) => !o)}
          className="w-8 h-8 flex items-center justify-center rounded-full hover:bg-white/10 transition-colors text-zinc-500 hover:text-white"
        >
          <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
            <circle cx="12" cy="5" r="2" />
            <circle cx="12" cy="12" r="2" />
            <circle cx="12" cy="19" r="2" />
          </svg>
        </button>
        {menuOpen && (
          <div className="absolute right-0 top-full mt-1 z-20 w-44 bg-zinc-800 rounded-lg shadow-xl border border-zinc-700 py-1 overflow-hidden">
            {menuItems.map((item) => (
              <button
                key={item.label}
                onClick={() => {
                  setMenuOpen(false);
                  item.onClick();
                }}
                className={`w-full text-left px-3 py-2 text-sm transition-colors ${
                  item.danger
                    ? 'text-red-400 hover:bg-red-600/20'
                    : 'text-zinc-200 hover:bg-zinc-700'
                }`}
              >
                {item.label}
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
