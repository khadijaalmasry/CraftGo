import React from 'react';
import { Link } from 'react-router-dom';
import { FaShoppingCart, FaHeart, FaStar } from 'react-icons/fa';
import { useCart } from '../context/CartContext';
import { useAuth } from '../context/AuthContext';

const ProductCard = ({ product }) => {
  const { addToCart } = useCart();
  const { isAuthenticated, isArtisan } = useAuth();
  
  const handleAddToCart = async (e) => {
    e.preventDefault();
    if (!isAuthenticated) {
      alert('الرجاء تسجيل الدخول أولاً');
      return;
    }
    const res = await addToCart(product.id, 1);
    if (res.success) {
      alert('تمت إضافة المنتج للسلة بنجاح!');
    }
  };

  return (
    <Link to={`/product/${product.id}`} style={styles.card} className="glass-card">
      <div style={styles.imageContainer}>
        <img 
          src={product.imageUrl || '/images/pottery.jpg'} 
          alt={product.nameAr || product.titleAr} 
          style={styles.image} 
          onError={(e) => e.target.src = '/images/plate.jpg'}
        />
        <div style={styles.favoriteBtn}>
          <FaHeart color="var(--text-dim)" size={18} />
        </div>
      </div>
      
      <div style={styles.content}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <h3 style={styles.title}>{product.nameAr || product.titleAr || product.title}</h3>
          <span style={styles.price}>{parseFloat(product.price).toFixed(2)} د.أ</span>
        </div>
        
        <p style={styles.artisanName}>
          {product.Craftsman?.name || product.artisan || 'حرفي مبدع'}
        </p>

        <div style={styles.footer}>
          <div style={styles.rating}>
            <FaStar color="#FFD700" size={14} />
            <span style={{ fontSize: '0.85rem', color: 'var(--text-dim)' }}>4.8</span>
          </div>
          
          {!isArtisan && (
            <button 
              onClick={handleAddToCart}
              style={styles.cartBtn}
              title="إضافة للسلة"
            >
              <FaShoppingCart size={16} />
            </button>
          )}
        </div>
      </div>
    </Link>
  );
};

const styles = {
  card: {
    display: 'flex',
    flexDirection: 'column',
    overflow: 'hidden',
    padding: '0',
    color: 'inherit',
    textDecoration: 'none',
    height: '100%',
  },
  imageContainer: {
    position: 'relative',
    height: '200px',
    width: '100%',
    backgroundColor: '#eee',
    borderTopLeftRadius: '16px',
    borderTopRightRadius: '16px',
    overflow: 'hidden',
  },
  image: {
    width: '100%',
    height: '100%',
    objectFit: 'cover',
  },
  favoriteBtn: {
    position: 'absolute',
    top: '10px',
    right: '10px',
    backgroundColor: 'var(--surface-color)',
    borderRadius: '50%',
    width: '32px',
    height: '32px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    boxShadow: 'var(--shadow-sm)',
    cursor: 'pointer',
  },
  content: {
    padding: '1rem',
    display: 'flex',
    flexDirection: 'column',
    flex: 1,
  },
  title: {
    fontSize: '1.1rem',
    margin: 0,
    fontWeight: 'bold',
    fontFamily: 'var(--font-primary)',
    display: '-webkit-box',
    WebkitLineClamp: 2,
    WebkitBoxOrient: 'vertical',
    overflow: 'hidden',
  },
  price: {
    color: 'var(--accent-color)',
    fontWeight: 'bold',
    fontSize: '1.1rem',
    whiteSpace: 'nowrap',
    marginLeft: '0.5rem',
  },
  artisanName: {
    fontSize: '0.9rem',
    color: 'var(--text-dim)',
    marginTop: '0.25rem',
    marginBottom: '1rem',
  },
  footer: {
    marginTop: 'auto',
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  rating: {
    display: 'flex',
    alignItems: 'center',
    gap: '4px',
  },
  cartBtn: {
    backgroundColor: 'var(--accent-color)',
    color: '#0D1420',
    width: '36px',
    height: '36px',
    borderRadius: '8px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  }
};

export default ProductCard;
