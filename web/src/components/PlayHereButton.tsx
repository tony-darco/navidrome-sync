import { useSyncStore } from '../store/syncStore';

export default function PlayHereButton() {
  const myRole = useSyncStore((s) => s.myRole);
  const nowPlaying = useSyncStore((s) => s.nowPlaying);
  const playSong = useSyncStore((s) => s.playSong);

  if (myRole === 'active' || !nowPlaying) return null;

  return (
    <button
      onClick={() => playSong(nowPlaying)}
      className="px-6 py-2.5 bg-green-600 hover:bg-green-500 text-white font-medium rounded-full transition-colors"
    >
      Play Here
    </button>
  );
}
