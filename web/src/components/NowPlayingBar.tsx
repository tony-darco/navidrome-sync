import { useNavigate } from 'react-router-dom';
import { useSyncStore } from '../store/syncStore';
import { getCoverArtUrl } from '../api/navidrome';

export default function NowPlayingBar() {
  const nowPlaying = useSyncStore((s) => s.nowPlaying);
  const myRole = useSyncStore((s) => s.myRole);
  const navigate = useNavigate();

  if (!nowPlaying) return null;

  return (
    <button
      onClick={() => navigate('/')}
      className="fixed bottom-0 inset-x-0 bg-zinc-900 border-t border-zinc-800 px-4 py-3 flex items-center gap-3 hover:bg-zinc-800/80 transition-colors cursor-pointer"
    >
      <img
        src={getCoverArtUrl(nowPlaying.coverArtId, 80)}
        alt=""
        className="w-10 h-10 rounded object-cover bg-zinc-800"
      />
      <div className="flex-1 min-w-0 text-left">
        <p className="text-sm font-medium truncate">{nowPlaying.title}</p>
        <p className="text-xs text-zinc-400 truncate">{nowPlaying.artist}</p>
      </div>
      <span
        className={`text-[10px] font-medium px-2 py-0.5 rounded-full ${
          myRole === 'active'
            ? 'bg-blue-900/50 text-blue-400'
            : 'bg-zinc-800 text-zinc-500'
        }`}
      >
        {myRole}
      </span>
    </button>
  );
}
