import React, { useState, useEffect } from 'react';
import api from '../services/api';
import { FaHeart, FaComment, FaTrash } from 'react-icons/fa';
import { useAuth } from '../context/AuthContext';

const Stories = () => {
  const { user, isArtisan } = useAuth();
  const [stories, setStories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [mediaFile, setMediaFile] = useState(null);
  const [caption, setCaption] = useState('');
  const [uploading, setUploading] = useState(false);

  useEffect(() => {
    fetchStories();
  }, []);

  const fetchStories = async () => {
    try {
      const res = await api.get('/stories');
      setStories(res.data.stories || res.data || []);
    } catch { } finally { setLoading(false); }
  };

  const handleUpload = async (e) => {
    e.preventDefault();
    if (!mediaFile) return alert('الرجاء اختيار صورة أو فيديو');
    setUploading(true);
    
    // Fake upload for UI since we might need proper multipart/form-data support on backend
    const formData = new FormData();
    formData.append('media', mediaFile);
    formData.append('mediaType', mediaFile.type.startsWith('video') ? 'video' : 'image');
    formData.append('caption', caption);

    try {
      await api.post('/stories', formData, { headers: { 'Content-Type': 'multipart/form-data' } });
      alert('تم نشر القصة!');
      setMediaFile(null);
      setCaption('');
      fetchStories();
    } catch {
      alert('حدث خطأ أثناء الرفع.');
    } finally {
      setUploading(false);
    }
  };

  const handleLike = async (id) => {
    try {
      await api.post(`/stories/${id}/like`);
      fetchStories();
    } catch { alert('تعذر الإعجاب بالقصة'); }
  };

  if (loading) return <div className="container" style={{ padding: '4rem', textAlign: 'center' }}>جاري التحميل...</div>;

  return (
    <div className="container fade-in" style={{ padding: '2rem 1.5rem', minHeight: '80vh', maxWidth: '800px', margin: '0 auto' }}>
      <h1 style={{ marginBottom: '2rem' }}>يوميات الحرفيين (القصص)</h1>

      {isArtisan && (
        <div className="glass-card" style={{ marginBottom: '2rem', padding: '1.5rem' }}>
          <h3>إضافة قصة جديدة</h3>
          <form onSubmit={handleUpload} style={{ display: 'flex', flexDirection: 'column', gap: '1rem', marginTop: '1rem' }}>
            <input type="file" className="input-field" accept="image/*,video/*" onChange={e => setMediaFile(e.target.files[0])} />
            <input type="text" className="input-field" placeholder="اكتب تعليقاً..." value={caption} onChange={e => setCaption(e.target.value)} />
            <button type="submit" className="btn-primary" disabled={uploading}>
              {uploading ? 'جاري النشر...' : 'نشر القصة'}
            </button>
          </form>
        </div>
      )}

      {stories.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '4rem', color: 'var(--text-dim)', backgroundColor: 'var(--surface-color)', borderRadius: '12px' }}>
          لا توجد قصص نشطة حالياً.
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
          {stories.map(story => (
            <div key={story.id} className="glass-card" style={{ padding: 0, overflow: 'hidden' }}>
              <div style={{ padding: '1rem', display: 'flex', alignItems: 'center', gap: '0.75rem', borderBottom: '1px solid var(--border-color)' }}>
                <div style={{ width: '40px', height: '40px', borderRadius: '50%', backgroundColor: 'var(--accent-color)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold' }}>
                  {(story.Craftsman?.name || story.Craftsman?.User?.name || 'ح')[0]}
                </div>
                <div>
                  <h4 style={{ margin: 0 }}>{story.Craftsman?.name || story.Craftsman?.User?.name || 'حرفي'}</h4>
                  <span style={{ fontSize: '0.8rem', color: 'var(--text-dim)' }}>{new Date(story.createdAt).toLocaleTimeString('ar-EG')}</span>
                </div>
              </div>
              
              {story.mediaType === 'video' ? (
                <video src={story.mediaUrl} controls style={{ width: '100%', maxHeight: '400px', backgroundColor: '#000' }} />
              ) : (
                <img src={story.mediaUrl || 'https://via.placeholder.com/600x400?text=CraftGo'} alt={story.caption} style={{ width: '100%', maxHeight: '400px', objectFit: 'cover' }} />
              )}
              
              <div style={{ padding: '1rem' }}>
                <p style={{ margin: '0 0 1rem', color: 'var(--text-primary)' }}>{story.caption}</p>
                <div style={{ display: 'flex', gap: '1.5rem', color: 'var(--text-secondary)' }}>
                  <button onClick={() => handleLike(story.id)} style={{ background: 'none', border: 'none', color: 'var(--danger-color)', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '0.4rem', fontSize: '1rem' }}>
                    <FaHeart /> إعجاب
                  </button>
                  <button style={{ background: 'none', border: 'none', color: 'var(--text-dim)', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '0.4rem', fontSize: '1rem' }}>
                    <FaComment /> تعليق
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default Stories;
