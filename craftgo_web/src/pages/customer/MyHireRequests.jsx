import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import api from '../../services/api';
import { useAuth } from '../../context/AuthContext';
import { FaPlus, FaMapMarkerAlt } from 'react-icons/fa';

const statusConfig = {
  pending:   { text: 'قيد الانتظار',  color: 'var(--accent-color)' },
  accepted:  { text: 'مقبول',          color: 'var(--success-color)' },
  rejected:  { text: 'مرفوض',          color: 'var(--danger-color)' },
  completed: { text: 'مكتمل',          color: '#8B5CF6' },
};

const MyHireRequests = () => {
  const { user } = useAuth();
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!user?.id) return;
    api.get(`/hire-orders/requests/customer/${user.id}`)
      .then(res => {
        const data = res.data;
        setRequests(Array.isArray(data) ? data : (data.requests || data.data || []));
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [user]);

  if (loading) return <div className="container" style={{ padding: '4rem', textAlign: 'center' }}>جاري التحميل...</div>;

  return (
    <div className="container fade-in" style={{ padding: '2rem 1.5rem', minHeight: '80vh' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <h1 style={{ margin: 0 }}>طلبات استئجار الحرفيين</h1>
        <Link to="/hire-request/new" className="btn-primary" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', textDecoration: 'none' }}>
          <FaPlus /> طلب جديد
        </Link>
      </div>

      {requests.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '4rem', backgroundColor: 'var(--surface-color)', borderRadius: '12px' }}>
          <p style={{ color: 'var(--text-secondary)', marginBottom: '1.5rem' }}>لا توجد طلبات استئجار بعد.</p>
          <Link to="/hire-request/new" className="btn-primary" style={{ textDecoration: 'none' }}>استئجار حرفي</Link>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
          {requests.map(req => {
            const sc = statusConfig[req.status] || { text: req.status, color: 'var(--text-dim)' };
            return (
              <div key={req.id} className="glass-card" style={{ padding: '1.5rem' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '1rem' }}>
                  <div>
                    <h3 style={{ margin: '0 0 0.25rem' }}>طلب استئجار #{req.id}</h3>
                    <p style={{ margin: 0, color: 'var(--text-dim)', fontSize: '0.85rem' }}>
                      {new Date(req.createdAt).toLocaleDateString('ar-EG')}
                    </p>
                  </div>
                  <span style={{ backgroundColor: sc.color + '20', color: sc.color, padding: '0.3rem 0.85rem', borderRadius: '20px', fontWeight: 'bold', fontSize: '0.85rem' }}>
                    {sc.text}
                  </span>
                </div>

                <p style={{ color: 'var(--text-secondary)', marginBottom: '1rem', lineHeight: 1.7 }}>
                  {req.description?.slice(0, 180)}{req.description?.length > 180 ? '...' : ''}
                </p>

                <div style={{ display: 'flex', gap: '1.5rem', flexWrap: 'wrap', color: 'var(--text-secondary)', fontSize: '0.9rem' }}>
                  <span>🎯 الحرفي: <strong style={{ color: 'var(--text-primary)' }}>{req.artisan?.name || req.Artisan?.name || '—'}</strong></span>
                  <span><FaMapMarkerAlt color="var(--accent-color)" style={{ marginLeft: '0.25rem' }} />{req.location || '—'}</span>
                  <span>📅 {req.scheduledDate ? new Date(req.scheduledDate).toLocaleDateString('ar-EG') : '—'}</span>
                  <span>💰 <strong style={{ color: 'var(--accent-color)' }}>{req.offeredBudget ? parseFloat(req.offeredBudget).toFixed(2) + ' د.أ' : '—'}</strong></span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default MyHireRequests;
