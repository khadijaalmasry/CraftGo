import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import api from '../services/api';
import { useCart } from '../context/CartContext';
import { useAuth } from '../context/AuthContext';
import { FaShoppingCart, FaHeart, FaStar, FaArrowRight } from 'react-icons/fa';

const ProductDetails = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const [product, setProduct] = useState(null);
  const [loading, setLoading] = useState(true);
  const [quantity, setQuantity] = useState(1);
  const { addToCart } = useCart();
  const { isAuthenticated, isArtisan } = useAuth();

  useEffect(() => {
    const fetchProduct = async () => {
      try {
        const res = await api.get(`/products/${id}`);
        setProduct(res.data.product || res.data);
      } catch (err) {
        console.error('Failed to fetch product details', err);
      } finally {
        setLoading(false);
      }
    };
    fetchProduct();
  }, [id]);

  const handleAddToCart = async () => {
    if (!isAuthenticated) {
      alert('الرجاء تسجيل الدخول أولاً');
      return navigate('/login');
    }
    const res = await addToCart(product.id, quantity);
    if (res.success) {
      alert('تمت إضافة المنتج للسلة بنجاح!');
    } else {
      alert(res.message || 'حدث خطأ أثناء الإضافة للسلة');
    }
  };

  if (loading) return <div className="container" style={{ padding: '4rem', textAlign: 'center' }}>جاري التحميل...</div>;
  if (!product) return <div className="container" style={{ padding: '4rem', textAlign: 'center' }}>المنتج غير موجود.</div>;

  return (
    <div className="container fade-in" style={{ padding: '2rem 1.5rem', minHeight: '80vh' }}>
      <button 
        onClick={() => navigate(-1)} 
        style={{ background: 'none', display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '2rem', color: 'var(--text-secondary)', fontWeight: 'bold' }}
      >
        <FaArrowRight /> عودة
      </button>

      <div style={styles.grid}>
        {/* Image Section */}
        <div style={styles.imageSection}>
          <img 
            src={product.imageUrl || 'https://via.placeholder.com/600?text=CraftGo'} 
            alt={product.nameAr || product.titleAr}
            style={styles.image}
            onError={(e) => e.target.src = 'https://via.placeholder.com/600?text=CraftGo'}
          />
        </div>

        {/* Details Section */}
        <div style={styles.detailsSection}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <h1 style={styles.title}>{product.nameAr || product.titleAr || product.title}</h1>
            <button style={styles.favBtn}><FaHeart size={20} color="var(--text-dim)" /></button>
          </div>

          <div style={styles.rating}>
            <FaStar color="#FFD700" size={18} />
            <span style={{ fontWeight: 'bold' }}>4.8</span>
            <span style={{ color: 'var(--text-dim)' }}>(120 تقييم)</span>
          </div>

          <h2 style={styles.price}>{parseFloat(product.price).toFixed(2)} د.أ</h2>
          
          <p style={styles.description}>
            {product.descriptionAr || product.description || 'لا يوجد وصف متاح لهذا المنتج.'}
          </p>

          <div style={styles.artisanInfo}>
            <div style={styles.avatar}>
              {(product.Craftsman?.name || product.artisan || 'H')[0].toUpperCase()}
            </div>
            <div>
              <p style={{ margin: 0, fontWeight: 'bold' }}>الحرفي</p>
              <p style={{ margin: 0, color: 'var(--text-secondary)' }}>{product.Craftsman?.name || product.artisan || 'حرفي مبدع'}</p>
            </div>
          </div>

          {!isArtisan && (
            <div style={styles.actionSection}>
              <div style={styles.quantityControl}>
                <button style={styles.qtyBtn} onClick={() => setQuantity(Math.max(1, quantity - 1))}>-</button>
                <span style={styles.qtyVal}>{quantity}</span>
                <button style={styles.qtyBtn} onClick={() => setQuantity(quantity + 1)}>+</button>
              </div>
              <button className="btn-primary" style={styles.addToCartBtn} onClick={handleAddToCart}>
                <FaShoppingCart />
                إضافة للسلة
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

const styles = {
  grid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
    gap: '3rem',
    alignItems: 'start',
  },
  imageSection: {
    borderRadius: '16px',
    overflow: 'hidden',
    boxShadow: 'var(--shadow-md)',
  },
  image: {
    width: '100%',
    height: 'auto',
    display: 'block',
  },
  detailsSection: {
    display: 'flex',
    flexDirection: 'column',
    gap: '1.5rem',
  },
  title: {
    fontSize: '2rem',
    margin: 0,
    color: 'var(--text-primary)',
  },
  favBtn: {
    background: 'none',
    padding: '0.5rem',
    borderRadius: '50%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  },
  rating: {
    display: 'flex',
    alignItems: 'center',
    gap: '0.5rem',
  },
  price: {
    fontSize: '2.5rem',
    color: 'var(--accent-color)',
    margin: 0,
  },
  description: {
    color: 'var(--text-secondary)',
    lineHeight: 1.8,
    fontSize: '1.1rem',
  },
  artisanInfo: {
    display: 'flex',
    alignItems: 'center',
    gap: '1rem',
    padding: '1rem',
    backgroundColor: 'var(--bg-color)',
    borderRadius: '12px',
    border: '1px solid var(--border-color)',
  },
  avatar: {
    width: '50px',
    height: '50px',
    borderRadius: '50%',
    backgroundColor: 'var(--accent-color)',
    color: 'white',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: '1.5rem',
    fontWeight: 'bold',
  },
  actionSection: {
    display: 'flex',
    gap: '1rem',
    marginTop: '1rem',
  },
  quantityControl: {
    display: 'flex',
    alignItems: 'center',
    border: '1px solid var(--border-color)',
    borderRadius: '8px',
    overflow: 'hidden',
  },
  qtyBtn: {
    padding: '0.75rem 1rem',
    background: 'var(--bg-color)',
    color: 'var(--text-primary)',
    fontSize: '1.2rem',
    fontWeight: 'bold',
  },
  qtyVal: {
    padding: '0 1rem',
    fontWeight: 'bold',
  },
  addToCartBtn: {
    flex: 1,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '0.75rem',
    fontSize: '1.1rem',
  }
};

export default ProductDetails;
