import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import api from '../../services/api';
import { useAuth } from '../../context/AuthContext';
import { FaHeart, FaTrash, FaShoppingCart } from 'react-icons/fa';
import { useCart } from '../../context/CartContext';

const Favorites = () => {
  const { user } = useAuth();
  const { addToCart } = useCart();
  const [favorites, setFavorites] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get('/interactions').then(res => {
      const data = res.data;
      const all = Array.isArray(data) ? data : (data.interactions || data.data || []);
      const liked = all.filter(i => i.interactionType === 'like' || i.type === 'like');
      setFavorites(liked);
    }).catch(() => {}).finally(() => setLoading(false));
  }, []);

  const handleRemove = async (productId) => {
    try {
      await api.post('/interactions', { productId, interactionType: 'unlike' });
      setFavorites(prev => prev.filter(f => (f.productId || f.Product?.id) !== productId));
    } catch { alert('تعذر الإزالة'); }
  };

  const handleAddToCart = async (productId) => {
    const res = await addToCart(productId, 1);
    if (res.success) alert('تمت الإضافة للسلة!');
  };

  if (loading) return <div className="container" style={{ padding: '4rem', textAlign: 'center' }}>جاري التحميل...</div>;

  return (
    <div className="container fade-in" style={{ padding: '2rem 1.5rem', minHeight: '80vh' }}>
      <h1 style={{ marginBottom: '2rem', display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
        <FaHeart color="var(--danger-color)" /> المفضلة
      </h1>

      {favorites.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '4rem', backgroundColor: 'var(--surface-color)', borderRadius: '12px' }}>
          <FaHeart size={48} color="var(--text-dim)" style={{ marginBottom: '1rem' }} />
          <p style={{ color: 'var(--text-secondary)', marginBottom: '1.5rem' }}>لا توجد منتجات في المفضلة.</p>
          <Link to="/shop" className="btn-primary" style={{ textDecoration: 'none' }}>تصفح المتجر</Link>
        </div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))', gap: '1.5rem' }}>
          {favorites.map(fav => {
            const product = fav.Product || fav;
            return (
              <div key={fav.id} className="glass-card" style={{ padding: 0, overflow: 'hidden' }}>
                <Link to={`/product/${product.id}`}>
                  <img
                    src={product.imageUrl || 'https://via.placeholder.com/300?text=CraftGo'}
                    alt={product.titleAr || product.nameAr}
                    style={{ width: '100%', height: '180px', objectFit: 'cover' }}
                    onError={e => e.target.src = 'https://via.placeholder.com/300?text=CraftGo'}
                  />
                </Link>
                <div style={{ padding: '1rem' }}>
                  <h3 style={{ margin: '0 0 0.5rem', fontSize: '1rem' }}>{product.titleAr || product.nameAr || '—'}</h3>
                  <p style={{ color: 'var(--accent-color)', fontWeight: 'bold', margin: '0 0 1rem' }}>
                    {parseFloat(product.price || 0).toFixed(2)} د.أ
                  </p>
                  <div style={{ display: 'flex', gap: '0.5rem' }}>
                    <button onClick={() => handleAddToCart(product.id)} className="btn-primary" style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.4rem', padding: '0.6rem' }}>
                      <FaShoppingCart size={14} /> سلة
                    </button>
                    <button onClick={() => handleRemove(product.id)} style={{ padding: '0.6rem 0.85rem', backgroundColor: 'rgba(239,68,68,0.1)', color: 'var(--danger-color)', border: '1px solid rgba(239,68,68,0.2)', borderRadius: '8px', cursor: 'pointer' }}>
                      <FaTrash size={14} />
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default Favorites;
