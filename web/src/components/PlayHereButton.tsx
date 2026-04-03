import { useSyncStore } from '../store/syncStore';

export default function PlayHereButton() {
  const myRole = useSyncStore((s) => s.myRole);
  const nowPlaying = useSyncStore((s) => s.nowPlaying);
  const claim = useSyncStore((s) => s.claim);

  if (myRole === 'active' || !nowPlaying) return null;

  return (
    <button
      onClick={() => claim()}
      className="text-xs font-medium text-green-500 border border-green-500/30 bg-green-500/10 hover:bg-green-500/20 px-3 py-1 rounded-full transition-colors"
    >
      Play Here
    </button>
  );
}
