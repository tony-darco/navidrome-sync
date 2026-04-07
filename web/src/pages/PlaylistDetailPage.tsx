import { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import PlaylistDetail from '../components/PlaylistDetail';
import PlaylistEditSheet from '../components/PlaylistEditSheet';

export default function PlaylistDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [editing, setEditing] = useState(false);

  if (!id) {
    return <div className="p-6 text-center text-zinc-500">Playlist not found</div>;
  }

  if (editing) {
    return (
      <PlaylistEditSheet
        playlistId={id}
        onClose={() => setEditing(false)}
      />
    );
  }

  return (
    <PlaylistDetail
      playlistId={id}
      onBack={() => navigate(-1)}
      onEdit={() => setEditing(true)}
    />
  );
}
