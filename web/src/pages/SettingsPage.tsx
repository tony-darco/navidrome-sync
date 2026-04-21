import { useSyncStore } from '../store/syncStore';
import { setCrateOverride, clearCrateOverride, getCrateOverride } from '../hooks/useCrateColor';
import { CRATE_COLORS, TRANSITIONS, TEXT, BACKGROUNDS, RADIUS, SPACING } from '../styles/design-system';

export default function SettingsPage() {
  const isConnected = useSyncStore((s) => s.isConnected);
  const myRole = useSyncStore((s) => s.myRole);
  const myClientId = useSyncStore((s) => s.myClientId);
  const connectedClients = useSyncStore((s) => s.connectedClients);
  const overrideIndex = getCrateOverride();

  return (
    <div style={{ padding: '32px 28px', background: BACKGROUNDS.cream, minHeight: '100%' }}>
      <h1 style={{ fontSize: 32, fontWeight: 700, letterSpacing: '-0.02em', color: TEXT.primary, marginBottom: 28 }}>
        Settings
      </h1>

      {/* Connection status */}
      <SettingsSection title="Connection">
        <SettingsRow label="Status">
          <StatusBadge connected={isConnected} />
        </SettingsRow>
        <SettingsRow label="Role">
          <span style={{ fontSize: 13, color: TEXT.secondary, textTransform: 'capitalize' }}>
            {myRole}
          </span>
        </SettingsRow>
        <SettingsRow label="Client ID">
          <span style={{ fontSize: 12, color: TEXT.tertiary, fontVariantNumeric: 'tabular-nums', fontFamily: 'monospace' }}>
            {myClientId.slice(0, 8)}…
          </span>
        </SettingsRow>
        {connectedClients.length > 0 && (
          <SettingsRow label="Connected Clients">
            <span style={{ fontSize: 13, color: TEXT.secondary }}>
              {connectedClients.length}
            </span>
          </SettingsRow>
        )}
      </SettingsSection>

      {/* Appearance */}
      <SettingsSection title="Appearance">
        <div style={{ padding: '12px 0 4px' }}>
          <p style={{ fontSize: 14, color: TEXT.primary, marginBottom: 12 }}>Crate Color</p>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
            {/* Auto swatch */}
            <CrateSwatchButton
              active={overrideIndex === -1}
              onClick={clearCrateOverride}
              title="Auto (follows track)"
            >
              <div
                style={{
                  width: 28,
                  height: 28,
                  borderRadius: '50%',
                  background: `conic-gradient(${CRATE_COLORS.map((c) => c.accent).join(', ')})`,
                }}
              />
            </CrateSwatchButton>

            {/* Individual swatches */}
            {CRATE_COLORS.map((c, i) => (
              <CrateSwatchButton
                key={c.name}
                active={overrideIndex === i}
                onClick={() => setCrateOverride(i)}
                title={c.name.charAt(0).toUpperCase() + c.name.slice(1)}
              >
                <div
                  style={{
                    width: 28,
                    height: 28,
                    borderRadius: '50%',
                    background: c.device,
                    border: `2px solid ${c.accent}`,
                  }}
                />
              </CrateSwatchButton>
            ))}
          </div>
          <p style={{ fontSize: 11, color: TEXT.tertiary, marginTop: 8 }}>
            {overrideIndex === -1 ? 'Auto (follows playing track)' : `Fixed — ${CRATE_COLORS[overrideIndex].name.charAt(0).toUpperCase() + CRATE_COLORS[overrideIndex].name.slice(1)}`}
          </p>
        </div>
      </SettingsSection>

      {/* Server info */}
      <SettingsSection title="Server">
        <p style={{ fontSize: 13, color: TEXT.secondary, lineHeight: 1.6 }}>
          Server credentials are configured via environment variables or the proxy config. The web client connects through the local proxy at <code style={{ fontFamily: 'monospace', background: 'rgba(0,0,0,0.06)', padding: '1px 5px', borderRadius: 4 }}>/api/config</code>.
        </p>
      </SettingsSection>

      {/* About */}
      <SettingsSection title="About">
        <SettingsRow label="App">
          <span style={{ fontSize: 13, color: TEXT.secondary }}>navidrome-sync</span>
        </SettingsRow>
        <SettingsRow label="Client">
          <span style={{ fontSize: 12, color: TEXT.tertiary, fontFamily: 'monospace' }}>Web</span>
        </SettingsRow>
      </SettingsSection>
    </div>
  );
}

/* ─── Section wrapper ─── */
function SettingsSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div style={{ marginBottom: 28 }}>
      <p
        style={{
          fontSize: 11,
          fontWeight: 600,
          letterSpacing: '0.1em',
          textTransform: 'uppercase',
          color: TEXT.secondary,
          marginBottom: 10,
        }}
      >
        {title}
      </p>
      <div
        style={{
          background: '#fff',
          borderRadius: RADIUS.lg,
          overflow: 'hidden',
          boxShadow: '0 1px 4px rgba(0,0,0,0.07)',
          padding: `0 ${SPACING.lg}px`,
        }}
      >
        {children}
      </div>
    </div>
  );
}

/* ─── Row ─── */
function SettingsRow({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        height: 48,
        borderBottom: '1px solid rgba(0,0,0,0.06)',
      }}
    >
      <span style={{ fontSize: 15, color: TEXT.primary }}>{label}</span>
      {children}
    </div>
  );
}

/* ─── Connection badge ─── */
function StatusBadge({ connected }: { connected: boolean }) {
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 5,
        padding: '3px 10px',
        borderRadius: RADIUS.pill,
        background: connected ? '#D4F5E3' : '#FFE8E8',
        transition: TRANSITIONS.crateColor,
      }}
    >
      <div
        style={{
          width: 6,
          height: 6,
          borderRadius: '50%',
          background: connected ? '#1A9E5C' : '#D63030',
          transition: TRANSITIONS.crateColor,
        }}
      />
      <span
        style={{
          fontSize: 11,
          fontWeight: 600,
          color: connected ? '#0D5C32' : '#8B1A1A',
          transition: TRANSITIONS.crateColor,
        }}
      >
        {connected ? 'Connected' : 'Offline'}
      </span>
    </div>
  );
}

/* ─── Crate swatch button ─── */
function CrateSwatchButton({
  active,
  onClick,
  title,
  children,
}: {
  active: boolean;
  onClick: () => void;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <button
      onClick={onClick}
      title={title}
      style={{
        background: 'none',
        border: 'none',
        padding: 3,
        borderRadius: '50%',
        cursor: 'pointer',
        outline: active ? `2.5px solid ${TEXT.primary}` : 'none',
        outlineOffset: 2,
        transition: 'outline 0.15s ease',
      }}
    >
      {children}
    </button>
  );
}
