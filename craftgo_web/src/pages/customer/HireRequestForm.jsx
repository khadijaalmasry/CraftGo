import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../../services/api';
import { useAuth } from '../../context/AuthContext';
import { FaCheckCircle } from 'react-icons/fa';

const HireRequestForm = () => {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [craftsmen, setCraftsmen] = useState([]);
  const [success, setSuccess] = useState(false);
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState({
    artisanId: '',
    description: '',
    location: '',
    scheduledDate: '',
    estimatedHours: '',
    offeredBudget: '',
  });

  useEffect(() => {
    api.get('/craftsmen').then(res => {
      const data = res.data;
      setCraftsmen(Array.isArray(data) ? data : (data.craftsmen || data.data || []));
    }).catch(() => {});
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      await api.post('/hire-orders/requests', {
        ...formData,
        estimatedHours: parseInt(formData.estimatedHours),
        offeredBudget: parseFloat(formData.offeredBudget),
      });
      setSuccess(true);
    } catch (err) {
      alert('حدث خطأ أثناء إرسال الطلب.');
    } finally {
      setLoading(false);
    }
  };

  if (success) return (
    <div className="container fade-in" style={{ padding: '4rem 1.5rem', textAlign: 'center', minHeight: '70vh' }}>
      <FaCheckCircle size={80} color="var(--success-color)" style={{ marginBottom: '1.5rem' }} />
      <h2>تم إرسال طلب الاستئجار بنجاح!</h2>
      <p style={{ color: 'var(--text-secondary)', marginBottom: '2rem' }}>
        سيتواصل معك الحرفي للتأكيد قريباً.
      </p>
      <button className="btn-primary" onClick={() => navigate('/customer/hire-requests')}>
        عرض طلباتي
      </button>
    </div>
  );

  return (
    <div className="container fade-in" style={{ padding: '2rem 1.5rem', minHeight: '80vh', display: 'flex', justifyContent: 'center' }}>
      <div className="glass-card" style={{ width: '100%', maxWidth: '600px', padding: '2.5rem' }}>
        <h1 style={{ marginBottom: '0.5rem' }}>استئجار حرفي</h1>
        <p style={{ color: 'var(--text-secondary)', marginBottom: '2rem' }}>
          وظّف حرفياً ماهراً للقيام بعمل ميداني في موقعك.
        </p>

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
          <div>
            <label style={styles.label}>اختر الحرفي</label>
            <select className="input-field" value={formData.artisanId} onChange={e => setFormData({ ...formData, artisanId: e.target.value })} required>
              <option value="">-- اختر حرفياً --</option>
              {craftsmen.map(c => (
                <option key={c.id} value={c.id}>{c.name || c.User?.name}</option>
              ))}
            </select>
          </div>

          <div>
            <label style={styles.label}>وصف العمل المطلوب</label>
            <textarea className="input-field" rows="4" placeholder="صف العمل بالتفصيل..." value={formData.description} onChange={e => setFormData({ ...formData, description: e.target.value })} required />
          </div>

          <div>
            <label style={styles.label}>موقع العمل</label>
            <input type="text" className="input-field" placeholder="مثال: نابلس، شارع الجامعة" value={formData.location} onChange={e => setFormData({ ...formData, location: e.target.value })} required />
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
            <div>
              <label style={styles.label}>تاريخ العمل</label>
              <input type="date" className="input-field" value={formData.scheduledDate} min={new Date().toISOString().split('T')[0]} onChange={e => setFormData({ ...formData, scheduledDate: e.target.value })} required />
            </div>
            <div>
              <label style={styles.label}>عدد الساعات المتوقعة</label>
              <input type="number" className="input-field" placeholder="مثال: 4" min="1" value={formData.estimatedHours} onChange={e => setFormData({ ...formData, estimatedHours: e.target.value })} required />
            </div>
          </div>

          <div>
            <label style={styles.label}>الميزانية المقترحة (د.أ)</label>
            <input type="number" className="input-field" placeholder="مثال: 80" min="1" value={formData.offeredBudget} onChange={e => setFormData({ ...formData, offeredBudget: e.target.value })} required />
          </div>

          <button type="submit" className="btn-primary" style={{ padding: '1rem', fontSize: '1.05rem' }} disabled={loading}>
            {loading ? 'جاري الإرسال...' : 'إرسال طلب الاستئجار'}
          </button>
        </form>
      </div>
    </div>
  );
};

const styles = { label: { display: 'block', marginBottom: '0.5rem', fontWeight: '600', color: 'var(--text-primary)' } };

export default HireRequestForm;
