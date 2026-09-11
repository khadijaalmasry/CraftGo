import React, { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import api from '../services/api';
import { FaSearch, FaFilter } from 'react-icons/fa';
import ProductCard from '../components/ProductCard';

const SearchResults = () => {
  const [query, setQuery] = useState('');
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(false);
  const [category, setCategory] = useState('');
  const [sortBy, setSortBy] = useState('new');
  const [searched, setSearched] = useState(false);

  const handleSearch = async (e) => {
    e?.preventDefault();
    if (!query.trim() && !category) return;
    setLoading(true);
    setSearched(true);
    try {
      const params = new URLSearchParams();
      if (query) params.set('search', query);
      if (category) params.set('category', category);
      if (sortBy) params.set('sort', sortBy);
      const res = await api.get(`/products?${params}`);
      const data = res.data;
      setProducts(Array.isArray(data) ? data : (data.products || data.data || []));
    } catch { } finally { setLoading(false); }
  };

  useEffect(() => { handleSearch(); }, [category, sortBy]);

  return (
    <div className="container fade-in" style={{ padding: '2rem 1.5rem', minHeight: '80vh' }}>
      <h1 style={{ marginBottom: '2rem' }}>البحث في المتجر</h1>

      {/* Search Bar */}
      <form onSubmit={handleSearch} style={{ display: 'flex', gap: '0.75rem', marginBottom: '2rem', flexWrap: 'wrap' }}>
        <div style={{ flex: 1, display: 'flex', gap: '0', minWidth: '250px' }}>
          <input
            type="text"
            className="input-field"
            value={query}
            onChange={e => setQuery(e.target.value)}
            placeholder="ابحث عن منتج، حرفي، أو فئة..."
            style={{ flex: 1, borderRadius: '8px 0 0 8px' }}
          />
          <button type="submit" className="btn-primary" style={{ borderRadius: '0 8px 8px 0', padding: '0 1.25rem' }}>
            <FaSearch />
          </button>
        </div>

        <select className="input-field" value={category} onChange={e => setCategory(e.target.value)} style={{ width: 'auto', minWidth: '160px' }}>
          <option value="">كل الفئات</option>
          <option value="نسيج">نسيج</option>
          <option value="خشب">خشب</option>
          <option value="فخار">فخار</option>
          <option value="زجاج">زجاج</option>
          <option value="جلد">جلد</option>
          <option value="مجوهرات">مجوهرات</option>
          <option value="نحاس">نحاس</option>
        </select>

        <select className="input-field" value={sortBy} onChange={e => setSortBy(e.target.value)} style={{ width: 'auto', minWidth: '160px' }}>
          <option value="new">الأحدث</option>
          <option value="price_low">السعر: الأقل أولاً</option>
          <option value="price_high">السعر: الأعلى أولاً</option>
          <option value="most_liked">الأكثر إعجاباً</option>
          <option value="rating">التقييم</option>
        </select>
      </form>

      {loading ? (
        <div style={{ textAlign: 'center', padding: '4rem', color: 'var(--text-dim)' }}>جاري البحث...</div>
      ) : searched && products.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '4rem', color: 'var(--text-dim)' }}>
          <FaSearch size={48} style={{ marginBottom: '1rem', opacity: 0.3 }} />
          <p>لا توجد نتائج لبحثك.</p>
          <Link to="/shop" className="btn-primary" style={{ display: 'inline-block', marginTop: '1rem', textDecoration: 'none' }}>تصفح كل المنتجات</Link>
        </div>
      ) : (
        <>
          {searched && <p style={{ color: 'var(--text-dim)', marginBottom: '1.5rem' }}>{products.length} نتيجة</p>}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(250px, 1fr))', gap: '1.5rem' }}>
            {products.map(p => <div key={p.id} className="fade-in"><ProductCard product={p} /></div>)}
          </div>
        </>
      )}
    </div>
  );
};

export default SearchResults;
