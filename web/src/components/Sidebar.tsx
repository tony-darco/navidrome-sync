import { NavLink } from 'react-router-dom';
import { useSyncStore } from '../store/syncStore';
import type { CrateColor } from '../styles/design-system';
import { TRANSITIONS, TEXT, BACKGROUNDS } from '../styles/design-system';

const NAV_ITEMS = [
  { to: '/',         label: 'Now Playing', icon: '▶' },
  { to: '/albums',   label: 'Albums',      icon: '◉' },
  { to: '/playlists',label: 'Playlists',   icon: '♫' },
  { to: '/artists',  label: 'Artists',     icon: '♪' },
  { to: '/songs',    label: 'Songs',       icon: '≡' },
  { to: '/search',   label: 'Search',      icon: '⌕' },
  { to: '/settings', label: 'Settings',    icon: '⚙' },
];

export default function Sidebar({ crate }: { crate: CrateColor }) {
  const isConnected = useSyncStore((s) => s.isConnected);

  return (
    <aside
      className="flex-shrink-0 flex flex-col h-full overflow-hidden"
      style={{
        width: 220,
        background: BACKGROUNDS.cream,
        borderRight: `1px solid rgba(0,0,0,0.08)`,
        transition: TRANSITIONS.crateColor,
      }}
    >
      {/* Logo / App name */}
      <div style={{ padding: '28px 20px 16px' }}>
        <h1
          style={{
            fontSize: 13,
            fontWeight: 700,
            letterSpacing: '0.08em',
            textTransform: 'uppercase',
            color: TEXT.primary,
          }}
        >
          navidrome-sync
        </h1>
        {/* Connection dot */}
        <div className="flex items-center gap-1.5 mt-1">
          <span
            style={{
              width: 6,
              height: 6,
              borderRadius: '50%',
              background: isConnected ? crate.accent : '#D63030',
              display: 'inline-block',
              transition: TRANSITIONS.crateColor,
            }}
          />
          <span style={{ fontSize: 10, color: TEXT.tertiary, letterSpacing: '0.04em' }}>
            {isConnected ? 'connected' : 'offline'}
          </span>
        </div>
      </div>

      {/* Nav items */}
      <nav style={{ flex: 1, padding: '4px 12px' }}>
        {NAV_ITEMS.map(({ to, label, icon }) => (
          <NavLink
            key={to}
            to={to}
            end={to === '/'}
            style={({ isActive }) => ({
              display: 'flex',
              alignItems: 'center',
              gap: 10,
              padding: '8px 10px',
              borderRadius: 10,
              marginBottom: 2,
              textDecoration: 'none',
              fontSize: 14,
              fontWeight: isActive ? 600 : 400,
              color: isActive ? crate.text : TEXT.secondary,
              background: isActive ? crate.device : 'transparent',
              transition: TRANSITIONS.crateColor,
            })}
          >
            <span
              style={{
                width: 22,
                textAlign: 'center',
                fontSize: 13,
                opacity: 0.8,
              }}
            >
              {icon}
            </span>
            {label}
          </NavLink>
        ))}
      </nav>

      {/* Bottom accent line */}
      <div
        style={{
          height: 3,
          background: crate.accent,
          margin: '0 12px 12px',
          borderRadius: 2,
          opacity: 0.6,
          transition: TRANSITIONS.crateColor,
        }}
      />
    </aside>
  );
}

