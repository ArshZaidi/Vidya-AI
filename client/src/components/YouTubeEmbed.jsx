export default function YouTubeEmbed({ videoId, title }) {
  if (!videoId) return null;
  return (
    <div className="rounded-2xl overflow-hidden bg-black aspect-video shadow-xl">
      <iframe
        className="w-full h-full"
        src={`https://www.youtube.com/embed/${videoId}?cc_load_policy=1&rel=0`}
        title={title || 'Video lesson'}
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
        allowFullScreen
      />
    </div>
  );
}
