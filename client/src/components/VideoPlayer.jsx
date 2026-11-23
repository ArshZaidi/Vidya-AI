import YouTubeEmbed from './YouTubeEmbed';

export default function VideoPlayer({ chapter }) {
  if (!chapter) return null;
  const hasYt = !!chapter.youtubeId;
  const hasMp4 = !!chapter.videoUrl;
  if (!hasYt && !hasMp4) return null;

  return (
    <div className="mt-12">
      <p className="font-display uppercase text-xs tracking-[0.2em] text-raspberry mb-3">
        Video Lesson · Subtitled
      </p>
      {hasYt ? (
        <YouTubeEmbed videoId={chapter.youtubeId} title={chapter.title} />
      ) : (
        <video controls className="w-full aspect-video rounded-2xl bg-black">
          <source src={chapter.videoUrl} />
          <track kind="captions" src={chapter.subtitlesUrl} srcLang="en" label="English" default />
        </video>
      )}
      <p className="text-xs text-ink/40 mt-2 text-center">
        Turn on CC (captions) for deaf-student accessibility
      </p>
    </div>
  );
}
