import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import api from '../services/api';
import ProductCard from '../components/ProductCard';

const Home = () => {
  const [featuredProducts, setFeaturedProducts] = useState([]);
  
  useEffect(() => {
    const fetchFeatured = async () => {
      try {
        const res = await api.get('/products');
        const data = res.data;
        const productsList = Array.isArray(data) ? data : (data.products || data.data || []);
        // Just take the first 4 for the home page
        setFeaturedProducts(productsList.slice(0, 4));
      } catch (err) {
        console.error('Failed to fetch featured products', err);
      }
    };
    fetchFeatured();
  }, []);

  return (
    <div>
      {/* Hero Section */}
      <section style={styles.hero}>
        <div className="container" style={styles.heroContent}>
          <div style={styles.heroText}>
            <h1 style={styles.heroTitle}>CraftGo</h1>
            <p style={styles.heroSubtitle}>
              وجهتك الأولى لدعم الحرفيين المبدعين. اكتشف منتجات فريدة مصنوعة بحب، أو اطلب عملاً مخصصاً ليناسب ذوقك الرفيع.
            </p>
            <div style={styles.heroButtons}>
              <Link to="/shop" className="btn-primary" style={{ display: 'inline-block', fontSize: '1.1rem' }}>
                تسوق الآن
              </Link>
            </div>
          </div>
        </div>
      </section>

      {/* Featured Products */}
      <section className="container" style={{ padding: '4rem 1.5rem' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
          <h2 style={{ color: 'var(--text-primary)', margin: 0 }}>منتجات مميزة</h2>
          <Link to="/shop" style={{ color: 'var(--accent-color)', fontWeight: 'bold' }}>
            عرض الكل &larr;
          </Link>
        </div>
        
        {featuredProducts.length > 0 ? (
          <div style={styles.grid}>
            {featuredProducts.map(product => (
              <div key={product.id} className="fade-in">
                <ProductCard product={product} />
              </div>
            ))}
          </div>
        ) : (
          <div style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-dim)' }}>
            <p>جاري التحميل...</p>
          </div>
        )}
      </section>
      
      {/* Features Banner */}
      <section style={{ backgroundColor: 'var(--surface-color)', padding: '4rem 0', borderTop: '1px solid var(--border-color)', borderBottom: '1px solid var(--border-color)' }}>
        <div className="container" style={styles.featuresGrid}>
          <div style={styles.featureItem}>
            <div style={styles.featureIcon}>🎨</div>
            <h3>منتجات يدوية أصيلة</h3>
            <p style={{ color: 'var(--text-dim)' }}>أعمال فريدة من نوعها من صنع حرفيين محليين مهرة.</p>
          </div>
          <div style={styles.featureItem}>
            <div style={styles.featureIcon}>🛠️</div>
            <h3>طلبات مخصصة</h3>
            <p style={{ color: 'var(--text-dim)' }}>تواصل مع الحرفي واطلب تصميماً يناسبك تماماً.</p>
          </div>
          <div style={styles.featureItem}>
            <div style={styles.featureIcon}>🚚</div>
            <h3>توصيل آمن وسريع</h3>
            <p style={{ color: 'var(--text-dim)' }}>نضمن وصول منتجاتك بأفضل حال وفي الوقت المحدد.</p>
          </div>
        </div>
      </section>
    </div>
  );
};

const styles = {
  hero: {
    backgroundColor: 'var(--surface-color)',
    padding: '4rem 0',
    borderBottom: '1px solid var(--border-color)',
    position: 'relative',
    overflow: 'hidden',
  },
  heroContent: {
    position: 'relative',
    zIndex: 2,
    display: 'flex',
    alignItems: 'center',
    minHeight: '40vh',
  },
  heroText: {
    maxWidth: '600px',
  },
  heroTitle: {
    fontSize: '3.5rem',
    color: 'var(--accent-color)',
    marginBottom: '1rem',
    lineHeight: 1.2,
  },
  heroSubtitle: {
    fontSize: '1.2rem',
    color: 'var(--text-secondary)',
    marginBottom: '2rem',
    lineHeight: 1.8,
  },
  heroButtons: {
    display: 'flex',
    gap: '1rem',
  },
  grid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(250px, 1fr))',
    gap: '1.5rem',
  },
  featuresGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
    gap: '2rem',
    textAlign: 'center',
  },
  featureItem: {
    padding: '1.5rem',
  },
  featureIcon: {
    fontSize: '3rem',
    marginBottom: '1rem',
  }
};

export default Home;
