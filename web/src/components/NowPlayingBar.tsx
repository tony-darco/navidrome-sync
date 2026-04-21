import { useNavigate } from 'react-router-dom';
import { useSyncStore } from '../store/syncStore';
import { getCoverArtUrl } from '../api/navidrome';
import type { CrateColor } from '../styles/design-system';
import { TRANSITIONS, RADIUS } from '../styles/design-system';

interface Props {
  crate: CrateColor;
}

export default function NowPlayingBar({ crate }: Props) {
  const nowPlaying = useSyncStore((s) => s.nowPlaying);
  const isPlaying = useSyncStore((s) => s.isPlaying);
  const position = useSyncStore((s) => s.position);
  const myRole = useSyncStore((s) => s.myRole);
  const play = useSyncStore((s) => s.play);
  const pause = useSyncStore((s) => s.pause);
  const next = useSyncStore((s) => s.next);
  const prev = useSyncStore((s) => s.prev);
  const navigate = useNavigate();

  if (!nowPlaying) return null;

  const progress = nowPlaying.durationSecs > 0
    ? (position / nowPlaying.durationSecs) * 100
    : 0;

  return (
    <div
      className="absolute bottom-0 left-0 right-0"
      style={{
        background: crate.playerBg,
        borderTop: `1px solid ${crate.outer}`,
        transition: TRANSITIONS.crateColor,
        zIndex: 40,
      }}
    >
      {/* Progress bar */}
      <div style={{ height: 2, background: crate.progBg }}>
        <div
          style={{
            height: '100%',
            width: `${progress}%`,
            background: crate.progFill,
            transition: 'width 1s linear',
          }}
        />
      </div>

      <div className="flex items-center gap-3" style={{ padding: '8px 20px' }}>
        {/* Album art */}
        <button onClick={() => navigate('/')} style={{ flexShrink: 0, cursor: 'pointer' }}>
          <img
            src={getCoverArtUrl(nowPlaying.coverArtId, 80)}
            alt=""
            style={{
              width: 38,
              height: 38,
              borderRadius: RADIUS.sm,
              objectFit: 'cover',
              background: crate.device,
            }}
          />
        </button>

        {/* Track info */}
        <div style={{ flex: 1, minWidth: 0 }}>
          <p
            className="truncate"
            style={{
              fontSize: 13,
              fontWeight: 600,
              color: crate.text,
              lineHeight: 1.2,
              cursor: nowPlaying.albumId ? 'pointer' : 'default',
              transition: TRANSITIONS.crateColor,
            }}
            onClick={() => nowPlaying.albumId && navigate(`/albums/${nowPlaying.albumId}`)}
          >
            {nowPlaying.title}
          </p>
          <p
            className="truncate"
            style={{
              fontSize: 11,
              color: crate.text,
              opacity: 0.65,
              cursor: nowPlaying.artistId ? 'pointer' : 'default',
              transition: TRANSITIONS.crateColor,
            }}
            onClick={() => nowPlaying.artistId && navigate(`/artists/${nowPlaying.artistId}`)}
          >
            {nowPlaying.artist}
          </p>
        </div>

        {/* Controls */}
        <div className="flex items-center" style={{ gap: 4, flexShrink: 0 }}>
          <CtrlBtn onClick={() => prev()} title="Previous" disabled={myRole !== 'active'} color={crate.accent}>
            <svg viewBox="0 0 24 24" fill="currentColor" style={{ width: 18, height: 18 }}>
              <path d="M9.195 18.44c1.25.714 2.805-.189 2.805-1.629v-2.34l6.945 3.968c1.25.715 2.805-.188 2.805-1.628V7.19c0-1.44-1.555-2.343-2.805-1.628L12 9.53V7.19c0-1.44-1.555-2.343-2.805-1.628l-7.108 4.061c-1.26.72-1.26 2.536 0 3.256l7.108 4.061Z" />
            </svg>
          </CtrlBtn>

          <CtrlBtn
            onClick={isPlaying ? pause : play}
            title={isPlaying ? 'Pause' : 'Play'}
            disabled={myRole !== 'active'}
            color={crate.accent}
            primary
          >
            {isPlaying ? (
              <svg viewBox="0 0 24 24" fill="currentColor" style={{ width: 20, height: 20 }}>
                <path fillRule="evenodd" d="M6.75 5.25a.75.75 0 0 1 .75-.75H9a.75.75 0 0 1 .75.75v13.5a.75.75 0 0 1-.75.75H7.5a.75.75 0 0 1-.75-.75V5.25Zm7.5 0A.75.75 0 0 1 15 4.5h1.5a.75.75 0 0 1 .75.75v13.5a.75.75 0 0 1-.75.75H15a.75.75 0 0 1-.75-.75V5.25Z" clipRule="evenodd" />
              </svg>
            ) : (
              <svg viewBox="0 0 24 24" fill="currentColor" style={{ width: 20, height: 20 }}>
                <path fillRule="evenodd" d="M4.5 5.653c0-1.427 1.529-2.33 2.779-1.643l11.54 6.347c1.295.712 1.295 2.573 0 3.286L7.28 19.99c-1.25.687-2.779-.217-2.779-1.643V5.653Z" clipRule="evenodd" />
              </svg>
            )}
          </CtrlBtn>

          <CtrlBtn onClick={() => next()} title="Next" disabled={myRole !== 'active'} color={crate.accent}>
            <svg viewBox="0 0 24 24" fill="currentColor" style={{ width: 18, height: 18 }}>
              <path d="M5.055 7.06C3.805 6.347 2.25 7.25 2.25 8.69v6.622c0 1.44 1.555 2.343 2.805 1.628L12 12.97v2.34c0 1.44 1.555 2.343 2.805 1.628l7.108-4.061c1.26-.72 1.26-2.536 0-3.256l-7.108-4.06C13.555 4.715 12 5.617 12 7.058v2.34L5.055 5.44Z" />
            </svg>
          </CtrlBtn>
        </div>

        {/* Role pill */}
        <span
          style={{
            fontSize: 10,
            fontWeight: 600,
            letterSpacing: '0.06em',
            textTransform: 'uppercase',
            padding: '2px 8px',
            borderRadius: RADIUS.pill,
            background: crate.pillBg,
            color: crate.pillText,
            transition: TRANSITIONS.crateColor,
            flexShrink: 0,
          }}
        >
          {myRole}
        </span>
      </div>
    </div>
  );
}

function CtrlBtn({
  onClick,
  title,
  disabled,
  color,
  primary,
  children,
}: {
  onClick: () => void;
  title: string;
  disabled: boolean;
  color: string;
  primary?: boolean;
  children: React.ReactNode;
}) {
  return (
    <button
      onClick={(e) => { e.stopPropagation(); onClick(); }}
      title={title}
      disabled={disabled}
      style={{
        padding: primary ? 7 : 5,
        borderRadius: '50%',
        background: primary ? color : 'transparent',
        color: primary ? '#fff' : color,
        cursor: disabled ? 'default' : 'pointer',
        opacity: disabled ? 0.4 : 1,
        border: 'none',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        transition: TRANSITIONS.crateColor,
      }}
    >
      {children}
    </button>
  );
}

