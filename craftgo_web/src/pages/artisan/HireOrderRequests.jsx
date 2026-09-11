import React, { useState, useEffect } from 'react';
import api from '../../services/api';
import { useAuth } from '../../context/AuthContext';
import { FaInbox, FaCheckCircle, FaTimesCircle } from 'react-icons/fa';

const HireOrderRequests = () => {
  const { user } = useAuth();
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [processing, setProcessing] = useState(null);

  useEffect(() => {
    if (!user?.id) return;
    api.get(`/hire-orders/requests/artisan/${user.id}`)
      .then(res => {
        const data = res.data;
        setRequests(Array.isArray(data) ? data : (data.requests || data.data || []));
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [user]);

  const handleRespond = async (id, status) => {
    setProcessing(id + status);
    try {
      await api.post(`/hire-orders/requests/${id}/respond`, { status });
      setRequests(prev => prev.map(r => r.id === id ? { ...r, status } : r));
    } catch {
      alert('حدث خطأ أثناء معالجة الطلب.');
    } finally {
      setProcessing(null);
    }
  };

  if (loading) return <div className="container" style={{ padding: '4rem', textAlign: 'center' }}>جاري التحميل...</div>;

  return (
    <div className="container fade-in" style={{ padding: '2rem 1.5rem', minHeight: '80vh' }}>
      <h1 style={{ marginBottom: '2rem' }}>طلبات الاستئجار الواردة</h1>

      {requests.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '4rem', backgroundColor: 'var(--surface-color)', borderRadius: '12px' }}>
          <FaInbox size={48} color="var(--text-dim)" style={{ marginBottom: '1rem' }} />
          <p style={{ color: 'var(--text-secondary)' }}>لا توجد طلبات استئجار حالياً.</p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
          {requests.map(req => (
            <div key={req.id} className="glass-card" style={{ padding: '1.5rem' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '1px solid var(--border-color)', paddingBottom: '1rem', marginBottom: '1rem' }}>
                <div>
                  <h3 style={{ margin: '0 0 0.25rem' }}>طلب استئجار #{req.id}</h3>
                  <p style={{ margin: 0, color: 'var(--text-dim)', fontSize: '0.85rem' }}>
                    من: {req.customer?.name || req.Customer?.name || 'زبون'} | {new Date(req.createdAt).toLocaleDateString('ar-EG')}
                  </p>
                </div>
                <span style={{
                  padding: '0.3rem 0.85rem', borderRadius: '20px', fontWeight: 'bold', fontSize: '0.85rem',
                  backgroundColor: req.status === 'pending' ? 'rgba(212,160,23,0.15)' : req.status === 'accepted' ? 'rgba(16,185,129,0.15)' : 'rgba(239,68,68,0.15)',
                  color: req.status === 'pending' ? 'var(--accent-color)' : req.status === 'accepted' ? 'var(--success-color)' : 'var(--danger-color)',
                }}>
                  {req.status === 'pending' ? 'قيد الانتظار' : req.status === 'accepted' ? 'مقبول' : 'مرفوض'}
                </span>
              </div>

              <p style={{ color: 'var(--text-secondary)', marginBottom: '1rem', lineHeight: 1.7 }}>{req.description}</p>

              <div style={{ display: 'flex', gap: '1.5rem', flexWrap: 'wrap', color: 'var(--text-secondary)', fontSize: '0.9rem', marginBottom: req.status === 'pending' ? '1.25rem' : 0 }}>
                <span>📍 {req.location || '—'}</span>
                <span>📅 {req.scheduledDate ? new Date(req.scheduledDate).toLocaleDateString('ar-EG') : '—'}</span>
                <span>⏱ {req.estimatedHours || '—'} ساعات</span>
                <span>💰 <strong style={{ color: 'var(--accent-color)' }}>{req.offeredBudget ? parseFloat(req.offeredBudget).toFixed(2) + ' د.أ' : '—'}</strong></span>
              </div>

              {req.status === 'pending' && (
                <div style={{ display: 'flex', gap: '0.75rem' }}>
                  <button
                    onClick={() => handleRespond(req.id, 'accepted')}
                    disabled={!!processing}
                    style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', padding: '0.65rem 1.25rem', backgroundColor: 'rgba(16,185,129,0.1)', color: 'var(--success-color)', border: '1px solid rgba(16,185,129,0.3)', borderRadius: '8px', fontWeight: '600', cursor: 'pointer', fontFamily: 'var(--font-primary)' }}
                  >
                    <FaCheckCircle /> {processing === req.id + 'accepted' ? '...' : 'قبول'}
                  </button>
                  <button
                    onClick={() => handleRespond(req.id, 'rejected')}
                    disabled={!!processing}
                    style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', padding: '0.65rem 1.25rem', backgroundColor: 'rgba(239,68,68,0.1)', color: 'var(--danger-color)', border: '1px solid rgba(239,68,68,0.3)', borderRadius: '8px', fontWeight: '600', cursor: 'pointer', fontFamily: 'var(--font-primary)' }}
                  >
                    <FaTimesCircle /> {processing === req.id + 'rejected' ? '...' : 'رفض'}
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default HireOrderRequests;
