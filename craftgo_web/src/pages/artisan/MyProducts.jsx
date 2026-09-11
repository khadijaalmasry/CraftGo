import React, { useState, useEffect } from 'react';
import api from '../../services/api';
import { useAuth } from '../../context/AuthContext';
import { FaPlus, FaEdit, FaTrash } from 'react-icons/fa';

const MyProducts = () => {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const { user } = useAuth();

  useEffect(() => {
    fetchProducts();
  }, []);

  const fetchProducts = async () => {
    try {
      // Assuming we get all products and filter by artisan if there's no specific route
      // or we can use /products/craftsman/:id if the user has an ID. Let's use the general one and filter.
      const res = await api.get('/products');
      const data = res.data;
      const productsList = Array.isArray(data) ? data : (data.products || data.data || []);
      
      // Filter products belonging to this artisan
      const myProds = productsList.filter(p => p.craftsmanId === user?.id || p.Craftsman?.id === user?.id || p.artisanId === user?.id);
      setProducts(myProds);
    } catch (err) {
      console.error('Failed to fetch products', err);
      setError('تعذر جلب المنتجات.');
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id) => {
    if (window.confirm('هل أنت متأكد من حذف هذا المنتج؟')) {
      try {
        const res = await api.delete(`/products/${id}`);
        if (res.status === 200 || res.data.success) {
          setProducts(products.filter(p => p.id !== id));
        }
      } catch (err) {
        alert('حدث خطأ أثناء الحذف');
      }
    }
  };

  if (loading) return <div className="container" style={{ padding: '4rem', textAlign: 'center' }}>جاري التحميل...</div>;

  return (
    <div className="container fade-in" style={{ padding: '2rem 1.5rem', minHeight: '80vh' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <h1 style={{ color: 'var(--text-primary)', margin: 0 }}>منتجاتي</h1>
        <button className="btn-primary" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <FaPlus /> إضافة منتج جديد
        </button>
      </div>

      {error && <div style={{ color: 'var(--danger-color)', marginBottom: '1rem' }}>{error}</div>}

      {products.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '4rem', backgroundColor: 'var(--surface-color)', borderRadius: '12px' }}>
          <p style={{ color: 'var(--text-secondary)' }}>لا يوجد لديك أي منتجات حالياً.</p>
        </div>
      ) : (
        <div style={styles.grid}>
          {products.map(product => (
            <div key={product.id} className="glass-card" style={styles.card}>
              <img 
                src={product.imageUrl || 'https://via.placeholder.com/300?text=CraftGo'} 
                alt={product.titleAr} 
                style={styles.image} 
              />
              <div style={styles.content}>
                <h3 style={styles.title}>{product.titleAr || product.nameAr}</h3>
                <p style={styles.price}>{parseFloat(product.price).toFixed(2)} د.أ</p>
                <p style={styles.stock}>الكمية المتوفرة: {product.stock || 10}</p>
                
                <div style={styles.actions}>
                  <button style={{ ...styles.actionBtn, color: '#3B82F6' }} title="تعديل">
                    <FaEdit />
                  </button>
                  <button 
                    style={{ ...styles.actionBtn, color: 'var(--danger-color)' }} 
                    title="حذف"
                    onClick={() => handleDelete(product.id)}
                  >
                    <FaTrash />
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

const styles = {
  grid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(250px, 1fr))',
    gap: '1.5rem',
  },
  card: {
    padding: 0,
    overflow: 'hidden',
    display: 'flex',
    flexDirection: 'column',
  },
  image: {
    width: '100%',
    height: '200px',
    objectFit: 'cover',
  },
  content: {
    padding: '1rem',
    flex: 1,
    display: 'flex',
    flexDirection: 'column',
  },
  title: {
    fontSize: '1.1rem',
    margin: '0 0 0.5rem 0',
  },
  price: {
    color: 'var(--accent-color)',
    fontWeight: 'bold',
    fontSize: '1.2rem',
    margin: '0 0 0.5rem 0',
  },
  stock: {
    color: 'var(--text-dim)',
    fontSize: '0.9rem',
    margin: '0 0 1rem 0',
  },
  actions: {
    display: 'flex',
    justifyContent: 'flex-end',
    gap: '1rem',
    marginTop: 'auto',
    borderTop: '1px solid var(--border-color)',
    paddingTop: '1rem',
  },
  actionBtn: {
    background: 'none',
    fontSize: '1.2rem',
    padding: '0.25rem',
  }
};

export default MyProducts;
