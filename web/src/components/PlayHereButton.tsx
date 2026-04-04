import { useSyncStore } from '../store/syncStore';

export default function PlayHereButton() {
  const myRole = useSyncStore((s) => s.myRole);
  const nowPlaying = useSyncStore((s) => s.nowPlaying);
  const claim = useSyncStore((s) => s.claim);

  if (myRole === 'active' || !nowPlaying) return null;

  return (
    <button
      onClick={() => claim()}
      className="text-xs font-medium text-blue-500 border border-blue-500/30 bg-blue-500/10 hover:bg-blue-500/20 px-3 py-1 rounded-full transition-colors"
    >
      Play Here
    </button>
  );
}
