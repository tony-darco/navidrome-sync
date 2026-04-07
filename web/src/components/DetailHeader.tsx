import type { ReactNode } from 'react';

interface DetailHeaderProps {
  coverArtUrl: string;
  title: string;
  subtitle?: string;
  meta: string;
  onShuffle: () => void;
  onPlay: () => void;
  onBack: () => void;
  extraButtons?: ReactNode;
}

export default function DetailHeader({
  coverArtUrl,
  title,
  subtitle,
  meta,
  onShuffle,
  onPlay,
  onBack,
  extraButtons,
}: DetailHeaderProps) {
  return (
    <div className="pb-8">
      {/* Back button */}
      <button
        onClick={onBack}
        className="mb-6 flex items-center gap-1 text-sm text-zinc-400 hover:text-white transition-colors"
      >
        <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
          <path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z" />
        </svg>
        Back
      </button>

      {/* Header: side-by-side on md+, stacked on mobile */}
      <div className="flex flex-col md:flex-row items-center md:items-end gap-5 md:gap-8">
        {/* Cover art */}
        {coverArtUrl ? (
          <img
            src={coverArtUrl}
            alt={title}
            className="w-48 h-48 md:w-56 md:h-56 rounded-xl object-cover shadow-2xl bg-zinc-800 flex-shrink-0"
          />
        ) : (
          <div className="w-48 h-48 md:w-56 md:h-56 rounded-xl bg-zinc-800 flex-shrink-0 flex items-center justify-center">
            <span className="text-zinc-500 text-4xl">♪</span>
          </div>
        )}

        {/* Metadata + actions */}
        <div className="flex flex-col items-center md:items-start gap-1 min-w-0">
          <h2 className="text-2xl md:text-3xl font-bold text-white text-center md:text-left leading-tight">{title}</h2>
          {subtitle && (
            <p className="text-lg text-zinc-300 text-center md:text-left">{subtitle}</p>
          )}
          <p className="text-sm text-zinc-400">{meta}</p>

          {/* Action row */}
          <div className="flex items-center gap-3 mt-4">
            {/* Shuffle */}
            <button
              onClick={onShuffle}
              className="w-10 h-10 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center transition-colors"
              title="Shuffle"
            >
              <svg className="w-5 h-5 text-white" viewBox="0 0 24 24" fill="currentColor">
                <path d="M10.59 9.17L5.41 4 4 5.41l5.17 5.17 1.42-1.41zM14.5 4l2.04 2.04L4 18.59 5.41 20 17.96 7.46 20 9.5V4h-5.5zm.33 9.41l-1.41 1.41 3.13 3.13L14.5 20H20v-5.5l-2.04 2.04-3.13-3.13z" />
              </svg>
            </button>

            {/* Play pill — outlined */}
            <button
              onClick={onPlay}
              className="flex items-center gap-2 px-6 py-2.5 border border-zinc-300/60 text-white font-semibold rounded-full hover:bg-white/10 transition-colors"
            >
              <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
                <path d="M8 5v14l11-7z" />
              </svg>
              Play
            </button>

            {extraButtons}
          </div>
        </div>
      </div>
    </div>
  );
}
