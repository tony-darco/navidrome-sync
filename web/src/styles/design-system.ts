// navidrome-sync Design System
// "Editorial Crate Digger" — bold editorial typography meets vinyl crate physicality
// All colors, spacing, typography, and component tokens live here.
// Never hardcode values in components — always import from this file.

// ─── CRATE COLORS ────────────────────────────────────────────────────────────
// 6 crate identities. Each album is assigned one deterministically:
//   crateIndex = albumId.charCodeAt(0) % 6
// The identity travels with the album everywhere in the UI.

export const CRATE_COLORS = [
  {
    name: 'blue',
    // Device / UI surfaces
    device:     '#C8DFF5',
    outer:      '#B5D4F4',
    ring:       '#A8CBEE',
    center:     '#D8E8F8',
    inner:      '#CCDFF4',
    // Content / text
    accent:     '#185FA5',
    text:       '#0C447C',
    light:      '#B5D4F4',
    // Art zone
    artBg:      '#0C2A4A',
    artLabel:   '#1A4A7A',
    artRing:    '#185FA555',
    // Mini player / popover
    playerBg:   '#DAF0FF',
    pop:        '#DAF0FF',
    // Progress / status
    progFill:   '#185FA5',
    progBg:     '#185FA511',
    // Pill
    pillBg:     '#E6F1FB',
    pillText:   '#0C447C',
    // Sync dot
    dot:        '#185FA5',
  },
  {
    name: 'amber',
    device:     '#F5D898',
    outer:      '#FAC775',
    ring:       '#F0BC65',
    center:     '#FAD898',
    inner:      '#F5D090',
    accent:     '#BA7517',
    text:       '#633806',
    light:      '#FAC775',
    artBg:      '#2A1800',
    artLabel:   '#4A2C00',
    artRing:    '#BA751755',
    playerBg:   '#FFF5DC',
    pop:        '#FFF5DC',
    progFill:   '#BA7517',
    progBg:     '#BA751711',
    pillBg:     '#FAEEDA',
    pillText:   '#633806',
    dot:        '#BA7517',
  },
  {
    name: 'coral',
    device:     '#F0C4B0',
    outer:      '#F5C4B3',
    ring:       '#EDB8A5',
    center:     '#F5CFC3',
    inner:      '#EEC8BA',
    accent:     '#993C1D',
    text:       '#712B13',
    light:      '#F5C4B3',
    artBg:      '#2A0C04',
    artLabel:   '#4A1808',
    artRing:    '#993C1D55',
    playerBg:   '#FDE8DF',
    pop:        '#FDE8DF',
    progFill:   '#993C1D',
    progBg:     '#993C1D11',
    pillBg:     '#FAECE7',
    pillText:   '#712B13',
    dot:        '#993C1D',
  },
  {
    name: 'green',
    device:     '#C4DC98',
    outer:      '#C0DD97',
    ring:       '#B2D288',
    center:     '#CCE4A2',
    inner:      '#C4DC9A',
    accent:     '#3B6D11',
    text:       '#27500A',
    light:      '#C0DD97',
    artBg:      '#0A1E04',
    artLabel:   '#183808',
    artRing:    '#3B6D1155',
    playerBg:   '#E8F8D4',
    pop:        '#E8F8D4',
    progFill:   '#3B6D11',
    progBg:     '#3B6D1111',
    pillBg:     '#EAF3DE',
    pillText:   '#27500A',
    dot:        '#3B6D11',
  },
  {
    name: 'purple',
    device:     '#CBC8F0',
    outer:      '#CECBF6',
    ring:       '#C0BCF0',
    center:     '#D8D5F8',
    inner:      '#CECBF4',
    accent:     '#534AB7',
    text:       '#3C3489',
    light:      '#CECBF6',
    artBg:      '#100E30',
    artLabel:   '#201C58',
    artRing:    '#534AB755',
    playerBg:   '#EEEEFF',
    pop:        '#EEEEFF',
    progFill:   '#534AB7',
    progBg:     '#534AB711',
    pillBg:     '#EEEDFE',
    pillText:   '#3C3489',
    dot:        '#534AB7',
  },
  {
    name: 'teal',
    device:     '#A4DCC8',
    outer:      '#9FE1CB',
    ring:       '#90D4BE',
    center:     '#B0E4D4',
    inner:      '#A8DCCC',
    accent:     '#0F6E56',
    text:       '#085041',
    light:      '#9FE1CB',
    artBg:      '#021A14',
    artLabel:   '#063028',
    artRing:    '#0F6E5655',
    playerBg:   '#D8F5EB',
    pop:        '#D8F5EB',
    progFill:   '#0F6E56',
    progBg:     '#0F6E5611',
    pillBg:     '#E1F5EE',
    pillText:   '#085041',
    dot:        '#0F6E56',
  },
] as const;

export type CrateColor = typeof CRATE_COLORS[number];

// Deterministic crate assignment from album ID
export function getCrateColor(albumId: string): CrateColor {
  const index = albumId.charCodeAt(0) % CRATE_COLORS.length;
  return CRATE_COLORS[index];
}

// ─── BACKGROUND COLORS ───────────────────────────────────────────────────────

export const BACKGROUNDS = {
  // Light views: Library, Songs, Artists, Search, Settings, Playlists
  cream:        '#F7F5F0',
  creamHover:   '#F0EDE5',
  creamActive:  '#EAE7DF',
  // Now Playing
  playerDark:   '#0A0A0A',
  playerCard:   '#1A1A1A',
  // White card groups (Settings)
  card:         '#FFFFFF',
} as const;

// ─── TEXT COLORS ─────────────────────────────────────────────────────────────

export const TEXT = {
  primary:      '#1A1A1A',
  secondary:    'rgba(0,0,0,0.45)',
  tertiary:     'rgba(0,0,0,0.28)',
  muted:        'rgba(0,0,0,0.18)',
  onDark:       '#FFFFFF',
  onDarkMuted:  'rgba(255,255,255,0.5)',
  onDarkHint:   'rgba(255,255,255,0.3)',
} as const;

// ─── STATUS COLORS ───────────────────────────────────────────────────────────

export const STATUS = {
  syncedBg:     '#D4F5E3',
  syncedText:   '#0D5C32',
  syncedDot:    '#1A9E5C',
  syncingBg:    '#FFF3D6',
  syncingText:  '#7A4E00',
  syncingDot:   '#E09000',
  errorBg:      '#FFE8E8',
  errorText:    '#8B1A1A',
  errorDot:     '#D63030',
} as const;

// ─── TYPOGRAPHY ──────────────────────────────────────────────────────────────

export const TYPOGRAPHY = {
  // iOS pt / Web px
  display: {
    size:   40,   // iOS: 40pt SF Pro Display / Web: 48px
    weight: 700,
    tracking: -0.03,
    lineHeight: 1.0,
  },
  h1: {
    size:   32,
    weight: 700,
    tracking: -0.02,
    lineHeight: 1.1,
  },
  h2: {
    size:   22,
    weight: 500,
    tracking: 0,
    lineHeight: 1.2,
  },
  sectionLabel: {
    size:       11,
    weight:     600,
    tracking:   0.10,
    uppercase:  true,
  },
  body: {
    size:       15,
    weight:     400,
    lineHeight: 1.6,
  },
  rowTitle: {
    size:   13,
    weight: 600,
  },
  rowSub: {
    size:   10,
    weight: 400,
  },
  // Always use monospace for these
  mono: {
    timestamp:  true,
    trackNumber:true,
    count:      true,
    duration:   true,
  },
} as const;

// ─── SPACING ─────────────────────────────────────────────────────────────────

export const SPACING = {
  xs:   4,
  sm:   8,
  md:   12,
  lg:   16,
  xl:   20,
  xxl:  28,
} as const;

// ─── BORDER RADIUS ───────────────────────────────────────────────────────────

export const RADIUS = {
  sm:       6,
  md:       8,
  lg:       12,   // Cards, playlist cards, mini player
  xl:       16,
  pill:     20,   // Genre tags, status pills
  circle:   9999, // Avatars, vinyl dots
  // iOS device
  device:   32,
  screen:   14,
  sideBar:  6,
} as const;

// ─── BORDERS ─────────────────────────────────────────────────────────────────

export const BORDERS = {
  subtle:   'rgba(0,0,0,0.06)',
  light:    'rgba(0,0,0,0.08)',
  medium:   'rgba(0,0,0,0.12)',
  onDark:   'rgba(255,255,255,0.10)',
  width:    0.5,
} as const;

// ─── TRANSITIONS ─────────────────────────────────────────────────────────────

export const TRANSITIONS = {
  // Crate color change — everything transitions together
  crateColor: 'background 0.5s ease, border-color 0.5s ease, color 0.5s ease',
  // Nav popover spring
  popoverIn:  'transform 0.2s cubic-bezier(0.34,1.56,0.64,1), opacity 0.18s ease',
  // CoverFlow
  coverFlow:  'transform 0.38s cubic-bezier(0.25,0.46,0.45,0.94), opacity 0.38s ease',
  // Row tap
  rowPress:   'background 0.12s ease',
  // Swatch select
  swatch:     'transform 0.15s ease',
  // Card tap
  cardPress:  'transform 0.15s ease',
} as const;

// ─── COMPONENT DIMENSIONS ────────────────────────────────────────────────────

export const DIMENSIONS = {
  // iOS device shell
  deviceWidth:        300,
  sideBarWidth:       14,
  screenHeight:       315,  // graphic zone
  notchWidth:         80,
  notchHeight:        22,
  // Click wheel
  wheelDiameter:      190,
  wheelRingInset:     4,
  wheelCenterInset:   55,
  wheelCenterInner:   66,
  // Row heights
  crateRowHeight:     82,   // Albums crate rows
  listRowHeight:      58,   // Songs / Artists rows
  // Thumbnails
  thumbSm:            34,   // Mini player art
  thumbMd:            36,   // List row art
  thumbLg:            52,   // Now Playing compact
  // Album chip (Search / horizontal strips)
  albumChipSize:      80,
  // Mini player
  miniPlayerRadius:   12,
  miniPlayerPadding:  9,
  miniProgressHeight: 2,
  // Bottom nav
  bottomNavHeight:    46,
  // Nav popover
  navPopoverWidth:    148,
  navPopoverRadius:   12,
} as const;

// ─── CLICK WHEEL ─────────────────────────────────────────────────────────────

export const CLICK_WHEEL = {
  labels: {
    top:    '+',      // Volume up
    bottom: '−',      // Volume down
    left:   '◀◀',    // Previous
    right:  '▶▶',    // Next
    center: '▶',      // Play (changes to ⏸ when playing)
  },
  // Ring interaction zones (as fraction of radius)
  ringInnerFraction:  0.38,
  ringOuterFraction:  0.93,
} as const;

// ─── NOW PLAYING ─────────────────────────────────────────────────────────────

export const NOW_PLAYING = {
  // Graphic zone overlay gradient
  overlayGradient: 'linear-gradient(to bottom, rgba(0,0,0,0.10) 0%, rgba(0,0,0,0.00) 30%, rgba(0,0,0,0.62) 100%)',
  // Vinyl SVG opacity in Library view (faded background)
  vinylLibraryOpacity: 0.08,
  // Progress bar
  progressHeight:  2,
  progressDotSize: 8,
} as const;

// ─── COVERFLOW (Albums) ───────────────────────────────────────────────────────

export const COVER_FLOW = {
  artSize:          180,   // px, focused cover
  spacing:          230,   // px between cover centers
  sideRotateX:      52,    // degrees
  sideScale:        0.58,
  sideScaleDecay:   0.14,  // scale reduction per step away from focus
  opacityDecay:     0.55,  // opacity reduction per step
  reflectionHeight: 54,
  reflectionOpacity:0.22,
  visibleRadius:    3,     // covers visible each side of focus
} as const;

// ─── SORT OPTIONS ─────────────────────────────────────────────────────────────

export const SORT_OPTIONS = [
  { id: 'album-az',   label: 'Album A→Z' },
  { id: 'album-za',   label: 'Album Z→A' },
  { id: 'artist-az',  label: 'Artist A→Z' },
  { id: 'artist-za',  label: 'Artist Z→A' },
  { id: 'recent',     label: 'Recently Played' },
] as const;

export type SortOption = typeof SORT_OPTIONS[number]['id'];

// ─── SEGMENTED SELECTORS (Settings) ──────────────────────────────────────────

export const SETTINGS_OPTIONS = {
  syncInterval: ['1 min', '5 min', '15 min', '30 min', '1 hr', 'Manual'],
  cacheSize:    ['512 MB', '1 GB', '2 GB', '4 GB', '8 GB'],
  quality:      ['96 kbps', '128 kbps', '256 kbps', '320 kbps'],
} as const;

// ─── NAV ITEMS ────────────────────────────────────────────────────────────────

export const NAV_ITEMS = [
  { id: 'library',   label: 'Library',  icon: '♪' },
  { id: 'albums',    label: 'Albums',   icon: '◉' },
  { id: 'search',    label: 'Search',   icon: '⌕' },
  { id: 'settings',  label: 'Settings', icon: '⚙' },
] as const;

export type NavItemId = typeof NAV_ITEMS[number]['id'];

// ─── NAVIDROME API ────────────────────────────────────────────────────────────

export const API = {
  version:    '1.16.1',
  client:     'navidrome-sync',
  format:     'json',
  coverArt:   (id: string, size = 300) =>
    `/rest/getCoverArt?id=${id}&size=${size}`,
} as const;
