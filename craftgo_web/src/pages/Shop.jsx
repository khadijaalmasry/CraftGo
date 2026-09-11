import React, { useState, useEffect } from 'react';
import api from '../services/api';
import ProductCard from '../components/ProductCard';

const Shop = () => {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const fetchProducts = async () => {
      try {
        const res = await api.get('/products');
        const data = res.data;
        // The API returns either an array directly or inside 'data' or 'products'
        const productsList = Array.isArray(data) ? data : (data.products || data.data || []);
        setProducts(productsList);
      } catch (err) {
        console.error('Failed to fetch products', err);
        setError('تعذر جلب المنتجات. الرجاء المحاولة لاحقاً.');
      } finally {
        setLoading(false);
      }
    };

    fetchProducts();
  }, []);

  return (
    <div className="container" style={{ padding: '2rem 1.5rem', minHeight: '80vh' }}>
      <h1 style={{ color: 'var(--accent-color)', marginBottom: '2rem', textAlign: 'center' }}>
        المتجر
      </h1>
      
      {error && (
        <div style={{ backgroundColor: 'rgba(239, 68, 68, 0.1)', color: 'var(--danger-color)', padding: '1rem', borderRadius: '8px', textAlign: 'center', marginBottom: '2rem' }}>
          {error}
        </div>
      )}

      {loading ? (
        <div style={{ display: 'flex', justifyContent: 'center', padding: '4rem' }}>
          <p style={{ color: 'var(--text-dim)', fontSize: '1.2rem' }}>جاري التحميل...</p>
        </div>
      ) : products.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '4rem', color: 'var(--text-dim)' }}>
          <p>لا توجد منتجات متاحة حالياً.</p>
        </div>
      ) : (
        <div style={styles.grid}>
          {products.map(product => (
            <div key={product.id} className="fade-in">
              <ProductCard product={product} />
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

const styles = {
  grid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(250px, 1fr))',
    gap: '1.5rem',
  }
};

export default Shop;
