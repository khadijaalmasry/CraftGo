import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import api from '../services/api';
import { FaMapMarkerAlt, FaCalendarAlt, FaUsers, FaChevronLeft } from 'react-icons/fa';

const Exhibitions = () => {
  const [exhibitions, setExhibitions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const fetchExhibitions = async () => {
      try {
        const res = await api.get('/exhibitions');
        const data = res.data;
        setExhibitions(Array.isArray(data) ? data : (data.exhibitions || data.data || []));
      } catch (err) {
        setError('تعذر جلب المعارض. الرجاء المحاولة لاحقاً.');
      } finally {
        setLoading(false);
      }
    };
    fetchExhibitions();
  }, []);

  const formatDate = (dateStr) => {
    try {
      return new Date(dateStr).toLocaleDateString('ar-EG', { year: 'numeric', month: 'long', day: 'numeric' });
    } catch { return dateStr; }
  };

  const isUpcoming = (startDate) => new Date(startDate) > new Date();
  const isActive = (startDate, endDate) => new Date(startDate) <= new Date() && new Date(endDate) >= new Date();

  const getStatusBadge = (ex) => {
    if (isActive(ex.startDate, ex.endDate)) return { text: 'جارٍ الآن', color: 'var(--success-color)' };
    if (isUpcoming(ex.startDate)) return { text: 'قادم', color: '#3B82F6' };
    return { text: 'انتهى', color: 'var(--text-dim)' };
  };

  if (loading) return <div className="container" style={{ padding: '4rem', textAlign: 'center' }}>جاري التحميل...</div>;

  return (
    <div className="container fade-in" style={{ padding: '2rem 1.5rem', minHeight: '80vh' }}>
      <h1 style={{ color: 'var(--text-primary)', marginBottom: '0.5rem' }}>المعارض الحرفية</h1>
      <p style={{ color: 'var(--text-secondary)', marginBottom: '2.5rem' }}>
        اكتشف معارض الحرفيين المحليين وقابل أصحاب الموهبة وجهاً لوجه.
      </p>

      {error && (
        <div style={{ backgroundColor: 'rgba(239,68,68,0.1)', color: 'var(--danger-color)', padding: '1rem', borderRadius: '8px', marginBottom: '2rem' }}>
          {error}
        </div>
      )}

      {exhibitions.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '4rem', backgroundColor: 'var(--surface-color)', borderRadius: '12px' }}>
          <p style={{ color: 'var(--text-secondary)' }}>لا توجد معارض متاحة حالياً.</p>
        </div>
      ) : (
        <div style={styles.grid}>
          {exhibitions.map(ex => {
            const badge = getStatusBadge(ex);
            return (
              <div key={ex.id} className="glass-card" style={styles.card}>
                <div style={{ ...styles.cardTop, borderTopColor: badge.color }} />
                
                <div style={styles.cardHeader}>
                  <h3 style={styles.cardTitle}>{ex.name || ex.title}</h3>
                  <span style={{ ...styles.badge, backgroundColor: badge.color + '20', color: badge.color }}>
                    {badge.text}
                  </span>
                </div>

                <p style={styles.description}>
                  {ex.description?.slice(0, 120) || 'معرض حرفي متميز.'}{ex.description?.length > 120 ? '...' : ''}
                </p>

                <div style={styles.metaList}>
                  <div style={styles.metaItem}>
                    <FaMapMarkerAlt color="var(--accent-color)" size={14} />
                    <span>{ex.location || 'غير محدد'}</span>
                  </div>
                  <div style={styles.metaItem}>
                    <FaCalendarAlt color="var(--accent-color)" size={14} />
                    <span>{formatDate(ex.startDate)} – {formatDate(ex.endDate)}</span>
                  </div>
                  <div style={styles.metaItem}>
                    <FaUsers color="var(--accent-color)" size={14} />
                    <span>السعة: {ex.capacity || '—'} حرفي</span>
                  </div>
                </div>

                <Link to={`/exhibitions/${ex.id}`} style={styles.detailsBtn}>
                  عرض التفاصيل <FaChevronLeft size={12} />
                </Link>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

const styles = {
  grid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))',
    gap: '1.5rem',
  },
  card: {
    padding: 0,
    overflow: 'hidden',
    display: 'flex',
    flexDirection: 'column',
  },
  cardTop: {
    height: '5px',
    borderTop: '5px solid',
  },
  cardHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    padding: '1.25rem 1.25rem 0.5rem',
    gap: '0.75rem',
  },
  cardTitle: {
    fontSize: '1.1rem',
    margin: 0,
    flex: 1,
  },
  badge: {
    padding: '0.25rem 0.75rem',
    borderRadius: '20px',
    fontSize: '0.8rem',
    fontWeight: 'bold',
    whiteSpace: 'nowrap',
  },
  description: {
    padding: '0 1.25rem',
    color: 'var(--text-secondary)',
    fontSize: '0.9rem',
    lineHeight: 1.6,
    marginBottom: '1rem',
  },
  metaList: {
    padding: '0 1.25rem',
    display: 'flex',
    flexDirection: 'column',
    gap: '0.5rem',
    marginBottom: '1.25rem',
  },
  metaItem: {
    display: 'flex',
    alignItems: 'center',
    gap: '0.5rem',
    fontSize: '0.85rem',
    color: 'var(--text-secondary)',
  },
  detailsBtn: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '0.5rem',
    padding: '0.85rem',
    backgroundColor: 'var(--bg-color)',
    color: 'var(--accent-color)',
    fontWeight: 'bold',
    fontSize: '0.9rem',
    borderTop: '1px solid var(--border-color)',
    marginTop: 'auto',
    textDecoration: 'none',
    transition: 'background-color 0.2s',
  }
};

export default Exhibitions;
