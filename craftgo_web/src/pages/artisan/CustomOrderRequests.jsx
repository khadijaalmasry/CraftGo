import React, { useState, useEffect } from 'react';
import api from '../../services/api';
import { useAuth } from '../../context/AuthContext';
import { FaInbox } from 'react-icons/fa';

const CustomOrderRequests = () => {
  const { user } = useAuth();
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [responding, setResponding] = useState(null);
  const [responseData, setResponseData] = useState({});

  useEffect(() => {
    if (!user?.id) return;
    api.get(`/custom-orders/requests/artisan/${user.id}`)
      .then(res => {
        const data = res.data;
        setRequests(Array.isArray(data) ? data : (data.requests || data.data || []));
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [user]);

  const handleRespond = async (requestId) => {
    const rd = responseData[requestId] || {};
    if (!rd.offeredPrice) return alert('يرجى إدخال السعر المقترح');
    try {
      await api.post(`/custom-orders/requests/${requestId}/respond`, {
        offeredPrice: parseFloat(rd.offeredPrice),
        estimatedDays: parseInt(rd.estimatedDays || 7),
        message: rd.message || '',
      });
      setRequests(prev => prev.map(r => r.id === requestId ? { ...r, status: 'accepted' } : r));
      setResponding(null);
    } catch {
      alert('حدث خطأ أثناء إرسال الرد.');
    }
  };

  const updateRd = (id, field, val) => {
    setResponseData(prev => ({ ...prev, [id]: { ...prev[id], [field]: val } }));
  };

  if (loading) return <div className="container" style={{ padding: '4rem', textAlign: 'center' }}>جاري التحميل...</div>;

  return (
    <div className="container fade-in" style={{ padding: '2rem 1.5rem', minHeight: '80vh' }}>
      <h1 style={{ marginBottom: '2rem' }}>طلبات المنتجات المخصصة</h1>

      {requests.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '4rem', backgroundColor: 'var(--surface-color)', borderRadius: '12px' }}>
          <FaInbox size={48} color="var(--text-dim)" style={{ marginBottom: '1rem' }} />
          <p style={{ color: 'var(--text-secondary)' }}>لا توجد طلبات مخصصة واردة حالياً.</p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
          {requests.map(req => (
            <div key={req.id} className="glass-card" style={{ padding: '1.5rem' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '1px solid var(--border-color)', paddingBottom: '1rem', marginBottom: '1rem' }}>
                <div>
                  <h3 style={{ margin: '0 0 0.25rem' }}>طلب #{req.id}</h3>
                  <p style={{ margin: 0, color: 'var(--text-dim)', fontSize: '0.85rem' }}>
                    من: {req.customer?.name || req.Customer?.name || 'زبون'} | {new Date(req.createdAt).toLocaleDateString('ar-EG')}
                  </p>
                </div>
                <span style={{
                  padding: '0.3rem 0.85rem', borderRadius: '20px', fontWeight: 'bold', fontSize: '0.85rem',
                  backgroundColor: req.status === 'pending' ? 'rgba(212,160,23,0.15)' : 'rgba(16,185,129,0.15)',
                  color: req.status === 'pending' ? 'var(--accent-color)' : 'var(--success-color)',
                }}>
                  {req.status === 'pending' ? 'قيد الانتظار' : 'تم الرد'}
                </span>
              </div>

              <p style={{ color: 'var(--text-secondary)', marginBottom: '1rem', lineHeight: 1.7 }}>{req.description}</p>

              <div style={{ display: 'flex', gap: '2rem', color: 'var(--text-secondary)', fontSize: '0.9rem', marginBottom: '1rem' }}>
                {req.budget && <span>💰 الميزانية: <strong>{parseFloat(req.budget).toFixed(2)} د.أ</strong></span>}
                {req.preferredDeadline && <span>📅 الموعد: <strong>{new Date(req.preferredDeadline).toLocaleDateString('ar-EG')}</strong></span>}
              </div>

              {req.status === 'pending' && (
                responding === req.id ? (
                  <div style={{ backgroundColor: 'var(--bg-color)', padding: '1.25rem', borderRadius: '10px', marginTop: '1rem' }}>
                    <h4 style={{ marginBottom: '1rem' }}>ردّك على الطلب</h4>
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem', marginBottom: '1rem' }}>
                      <div>
                        <label style={{ display: 'block', marginBottom: '0.4rem', fontWeight: '600', fontSize: '0.9rem' }}>السعر المقترح (د.أ) *</label>
                        <input type="number" className="input-field" placeholder="150" min="1"
                          onChange={e => updateRd(req.id, 'offeredPrice', e.target.value)} />
                      </div>
                      <div>
                        <label style={{ display: 'block', marginBottom: '0.4rem', fontWeight: '600', fontSize: '0.9rem' }}>أيام التسليم</label>
                        <input type="number" className="input-field" placeholder="7" min="1"
                          onChange={e => updateRd(req.id, 'estimatedDays', e.target.value)} />
                      </div>
                    </div>
                    <textarea className="input-field" rows="3" placeholder="رسالة للزبون (اختياري)..."
                      onChange={e => updateRd(req.id, 'message', e.target.value)} style={{ marginBottom: '1rem' }} />
                    <div style={{ display: 'flex', gap: '0.75rem' }}>
                      <button className="btn-primary" onClick={() => handleRespond(req.id)}>إرسال الرد</button>
                      <button onClick={() => setResponding(null)} style={{ padding: '0.75rem 1.5rem', background: 'none', color: 'var(--text-dim)', fontWeight: '600' }}>إلغاء</button>
                    </div>
                  </div>
                ) : (
                  <button className="btn-primary" onClick={() => setResponding(req.id)} style={{ marginTop: '0.5rem' }}>
                    الرد وتسعير الطلب
                  </button>
                )
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default CustomOrderRequests;
