import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import api from '../services/api';
import { useAuth } from '../context/AuthContext';
import { FaStar, FaHammer, FaArrowRight, FaComments } from 'react-icons/fa';

const ArtisanProfile = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const { user, isAuthenticated } = useAuth();
  const [artisan, setArtisan] = useState(null);
  const [products, setProducts] = useState([]);
  const [reviews, setReviews] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      api.get(`/craftsmen/profile/${id}`),
      api.get(`/products/craftsman/${id}`),
      api.get(`/craftsmen/reviews/${id}`),
    ]).then(([profileRes, productsRes, reviewsRes]) => {
      setArtisan(profileRes.data.craftsman || profileRes.data);
      const pd = productsRes.data;
      setProducts(Array.isArray(pd) ? pd : (pd.products || pd.data || []));
      const rd = reviewsRes.data;
      setReviews(Array.isArray(rd) ? rd : (rd.reviews || rd.data || []));
    }).catch(() => {}).finally(() => setLoading(false));
  }, [id]);

  const startChat = async () => {
    if (!isAuthenticated) return navigate('/login');
    try {
      await api.post('/chats', { craftsmanId: id });
      navigate('/chat');
    } catch { alert('تعذر بدء المحادثة'); }
  };

  if (loading) return <div className="container" style={{ padding: '4rem', textAlign: 'center' }}>جاري التحميل...</div>;
  if (!artisan) return <div className="container" style={{ padding: '4rem', textAlign: 'center' }}>الحرفي غير موجود.</div>;

  const avgRating = reviews.length ? (reviews.reduce((s, r) => s + (r.rating || 0), 0) / reviews.length).toFixed(1) : 'جديد';

  return (
    <div className="container fade-in" style={{ padding: '2rem 1.5rem', minHeight: '80vh' }}>
      <button onClick={() => navigate(-1)} style={{ background: 'none', display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '2rem', color: 'var(--text-secondary)', fontWeight: 'bold' }}>
        <FaArrowRight /> عودة
      </button>

      {/* Profile Header */}
      <div className="glass-card" style={{ marginBottom: '2rem', display: 'flex', gap: '2rem', alignItems: 'center', flexWrap: 'wrap' }}>
        <div style={{ width: '100px', height: '100px', borderRadius: '50%', backgroundColor: 'var(--accent-color)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '2.5rem', color: '#fff', fontWeight: 'bold', flexShrink: 0 }}>
          {(artisan.name || artisan.User?.name || 'ح')[0]}
        </div>
        <div style={{ flex: 1 }}>
          <h1 style={{ margin: '0 0 0.5rem', color: 'var(--text-primary)' }}>{artisan.name || artisan.User?.name}</h1>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.75rem' }}>
            <FaStar color="#FFD700" />
            <span style={{ fontWeight: 'bold' }}>{avgRating}</span>
            <span style={{ color: 'var(--text-dim)' }}>({reviews.length} تقييم)</span>
          </div>
          <p style={{ color: 'var(--text-secondary)', margin: 0 }}>
            {artisan.bio || artisan.specialty || 'حرفي مبدع في CraftGo'}
          </p>
        </div>
        {isAuthenticated && user?.id !== id && (
          <button onClick={startChat} className="btn-primary" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <FaComments /> مراسلة
          </button>
        )}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '2rem', flexWrap: 'wrap' }}>
        {/* Products */}
        <div>
          <h2 style={{ marginBottom: '1.25rem' }}>منتجاته ({products.length})</h2>
          {products.length === 0 ? (
            <p style={{ color: 'var(--text-dim)' }}>لا توجد منتجات حالياً.</p>
          ) : (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: '1rem' }}>
              {products.map(p => (
                <div key={p.id} className="glass-card" style={{ padding: 0, overflow: 'hidden', cursor: 'pointer' }} onClick={() => navigate(`/product/${p.id}`)}>
                  <img src={p.imageUrl || 'https://via.placeholder.com/200?text=CraftGo'} alt={p.titleAr} style={{ width: '100%', height: '140px', objectFit: 'cover' }} />
                  <div style={{ padding: '0.75rem' }}>
                    <p style={{ margin: '0 0 0.25rem', fontWeight: 'bold', fontSize: '0.9rem' }}>{p.titleAr || p.nameAr}</p>
                    <p style={{ margin: 0, color: 'var(--accent-color)', fontWeight: 'bold' }}>{parseFloat(p.price).toFixed(2)} د.أ</p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Reviews */}
        <div>
          <h2 style={{ marginBottom: '1.25rem' }}>التقييمات ({reviews.length})</h2>
          {reviews.length === 0 ? (
            <p style={{ color: 'var(--text-dim)' }}>لا توجد تقييمات بعد.</p>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              {reviews.slice(0, 5).map(r => (
                <div key={r.id} className="glass-card" style={{ padding: '1rem' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.5rem' }}>
                    {[1,2,3,4,5].map(s => <FaStar key={s} color={s <= (r.rating || 0) ? '#FFD700' : 'var(--border-color)'} size={14} />)}
                    <span style={{ color: 'var(--text-dim)', fontSize: '0.8rem' }}>{new Date(r.createdAt).toLocaleDateString('ar-EG')}</span>
                  </div>
                  <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: '0.9rem' }}>{r.comment || r.review || '—'}</p>
                  <p style={{ margin: '0.5rem 0 0', color: 'var(--text-dim)', fontSize: '0.8rem' }}>— {r.Customer?.name || r.customer?.name || 'زبون'}</p>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default ArtisanProfile;
