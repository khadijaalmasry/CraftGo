import React, { useState, useEffect } from 'react';
import api from '../../services/api';
import { FaCheckCircle, FaTimesCircle, FaUserClock } from 'react-icons/fa';

const PendingArtisans = () => {
  const [artisans, setArtisans] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [processing, setProcessing] = useState(null);

  useEffect(() => {
    const fetch = async () => {
      try {
        const res = await api.get('/admin/pending-artisans');
        const data = res.data;
        setArtisans(Array.isArray(data) ? data : (data.artisans || data.data || []));
      } catch (err) {
        setError('تعذر جلب الحرفيين قيد المراجعة.');
      } finally {
        setLoading(false);
      }
    };
    fetch();
  }, []);

  const handleReview = async (artisanProfileId, action) => {
    setProcessing(artisanProfileId + action);
    try {
      await api.patch(`/admin/artisans/${artisanProfileId}/review`, { action });
      setArtisans(prev => prev.filter(a => (a.id || a.artisanProfileId) !== artisanProfileId));
    } catch (err) {
      alert('حدث خطأ أثناء معالجة الطلب.');
    } finally {
      setProcessing(null);
    }
  };

  if (loading) return <div className="container" style={{ padding: '4rem', textAlign: 'center' }}>جاري التحميل...</div>;

  return (
    <div className="container fade-in" style={{ padding: '2rem 1.5rem', minHeight: '80vh' }}>
      <h1 style={{ marginBottom: '0.5rem' }}>الحرفيون قيد المراجعة</h1>
      <p style={{ color: 'var(--text-secondary)', marginBottom: '2rem' }}>
        مراجعة طلبات تسجيل الحرفيين الجدد والموافقة عليها أو رفضها.
      </p>

      {error && (
        <div style={{ color: 'var(--danger-color)', padding: '1rem', backgroundColor: 'rgba(239,68,68,0.1)', borderRadius: '8px', marginBottom: '1.5rem' }}>
          {error}
        </div>
      )}

      {artisans.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '4rem', backgroundColor: 'var(--surface-color)', borderRadius: '12px' }}>
          <FaUserClock size={48} color="var(--text-dim)" style={{ marginBottom: '1rem' }} />
          <p style={{ color: 'var(--text-secondary)' }}>لا يوجد حرفيون قيد المراجعة حالياً.</p>
        </div>
      ) : (
        <div style={{ overflowX: 'auto' }}>
          <table style={styles.table}>
            <thead>
              <tr style={{ backgroundColor: 'var(--bg-color)' }}>
                <th style={styles.th}>الاسم</th>
                <th style={styles.th}>البريد الإلكتروني</th>
                <th style={styles.th}>التخصص</th>
                <th style={styles.th}>تاريخ التسجيل</th>
                <th style={styles.th}>الإجراء</th>
              </tr>
            </thead>
            <tbody>
              {artisans.map((artisan, i) => {
                const profileId = artisan.id || artisan.artisanProfileId;
                const name = artisan.name || artisan.User?.name || '—';
                const email = artisan.email || artisan.User?.email || '—';
                const specialty = artisan.specialty || artisan.category || artisan.craftType || '—';
                const date = artisan.createdAt ? new Date(artisan.createdAt).toLocaleDateString('ar-EG') : '—';

                return (
                  <tr key={profileId || i} style={{ borderBottom: '1px solid var(--border-color)', backgroundColor: i % 2 === 0 ? 'var(--surface-color)' : 'var(--bg-color)' }}>
                    <td style={styles.td}>{name}</td>
                    <td style={styles.td}>{email}</td>
                    <td style={styles.td}>{specialty}</td>
                    <td style={styles.td}>{date}</td>
                    <td style={styles.td}>
                      <div style={{ display: 'flex', gap: '0.5rem' }}>
                        <button
                          onClick={() => handleReview(profileId, 'approve')}
                          disabled={processing === profileId + 'approve'}
                          style={{ ...styles.approveBtn, opacity: processing ? 0.7 : 1 }}
                        >
                          <FaCheckCircle size={14} />
                          {processing === profileId + 'approve' ? '...' : 'قبول'}
                        </button>
                        <button
                          onClick={() => handleReview(profileId, 'reject')}
                          disabled={processing === profileId + 'reject'}
                          style={{ ...styles.rejectBtn, opacity: processing ? 0.7 : 1 }}
                        >
                          <FaTimesCircle size={14} />
                          {processing === profileId + 'reject' ? '...' : 'رفض'}
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};

const styles = {
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    backgroundColor: 'var(--surface-color)',
    borderRadius: '12px',
    overflow: 'hidden',
    boxShadow: 'var(--shadow-md)',
  },
  th: {
    padding: '1rem 1.25rem',
    textAlign: 'right',
    fontWeight: '700',
    color: 'var(--text-primary)',
    fontSize: '0.9rem',
    borderBottom: '2px solid var(--border-color)',
  },
  td: {
    padding: '1rem 1.25rem',
    color: 'var(--text-secondary)',
    fontSize: '0.9rem',
  },
  approveBtn: {
    display: 'flex',
    alignItems: 'center',
    gap: '0.35rem',
    padding: '0.45rem 0.85rem',
    backgroundColor: 'rgba(16,185,129,0.1)',
    color: 'var(--success-color)',
    border: '1px solid rgba(16,185,129,0.3)',
    borderRadius: '6px',
    fontWeight: '600',
    fontSize: '0.85rem',
    cursor: 'pointer',
    fontFamily: 'var(--font-primary)',
  },
  rejectBtn: {
    display: 'flex',
    alignItems: 'center',
    gap: '0.35rem',
    padding: '0.45rem 0.85rem',
    backgroundColor: 'rgba(239,68,68,0.1)',
    color: 'var(--danger-color)',
    border: '1px solid rgba(239,68,68,0.3)',
    borderRadius: '6px',
    fontWeight: '600',
    fontSize: '0.85rem',
    cursor: 'pointer',
    fontFamily: 'var(--font-primary)',
  },
};

export default PendingArtisans;
