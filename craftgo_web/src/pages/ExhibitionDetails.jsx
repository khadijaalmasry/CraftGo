import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import api from '../services/api';
import { useAuth } from '../context/AuthContext';
import { FaMapMarkerAlt, FaCalendarAlt, FaUsers, FaArrowRight } from 'react-icons/fa';

const ExhibitionDetails = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const { user, isArtisan } = useAuth();
  const [exhibition, setExhibition] = useState(null);
  const [loading, setLoading] = useState(true);
  const [registerLoading, setRegisterLoading] = useState(false);
  const [registerSuccess, setRegisterSuccess] = useState(false);
  const [formData, setFormData] = useState({ craftCategory: '', boothId: '', boothPrice: '', hasPaid: false });

  useEffect(() => {
    api.get(`/exhibitions/${id}`)
      .then(res => setExhibition(res.data.exhibition || res.data))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [id]);

  const handleRegister = async (e) => {
    e.preventDefault();
    setRegisterLoading(true);
    try {
      await api.post(`/exhibitions/${id}/register`, {
        craftsmanId: user.id,
        craftCategory: formData.craftCategory,
        boothId: formData.boothId,
        boothPrice: parseFloat(formData.boothPrice),
        hasPaid: formData.hasPaid,
      });
      setRegisterSuccess(true);
    } catch {
      alert('حدث خطأ أثناء التسجيل.');
    } finally {
      setRegisterLoading(false);
    }
  };

  const formatDate = (d) => { try { return new Date(d).toLocaleDateString('ar-EG', { year: 'numeric', month: 'long', day: 'numeric' }); } catch { return d; } };

  if (loading) return <div className="container" style={{ padding: '4rem', textAlign: 'center' }}>جاري التحميل...</div>;
  if (!exhibition) return <div className="container" style={{ padding: '4rem', textAlign: 'center' }}>المعرض غير موجود.</div>;

  return (
    <div className="container fade-in" style={{ padding: '2rem 1.5rem', minHeight: '80vh' }}>
      <button onClick={() => navigate(-1)} style={{ background: 'none', display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '2rem', color: 'var(--text-secondary)', fontWeight: 'bold' }}>
        <FaArrowRight /> عودة للمعارض
      </button>

      <div style={styles.grid}>
        {/* Main Info */}
        <div style={{ flex: '1 1 60%' }}>
          <div className="glass-card" style={{ marginBottom: '1.5rem' }}>
            <h1 style={{ color: 'var(--accent-color)', marginBottom: '1rem' }}>{exhibition.name || exhibition.title}</h1>
            <p style={{ color: 'var(--text-secondary)', lineHeight: 1.8, marginBottom: '1.5rem' }}>
              {exhibition.description || 'لا يوجد وصف متاح.'}
            </p>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
              <div style={styles.metaItem}><FaMapMarkerAlt color="var(--accent-color)" /><span>{exhibition.location}</span></div>
              <div style={styles.metaItem}><FaCalendarAlt color="var(--accent-color)" /><span>{formatDate(exhibition.startDate)} – {formatDate(exhibition.endDate)}</span></div>
              <div style={styles.metaItem}><FaUsers color="var(--accent-color)" /><span>السعة الإجمالية: {exhibition.capacity} حرفي</span></div>
            </div>
          </div>

          {/* Registered Craftsmen */}
          {exhibition.registrations?.length > 0 && (
            <div className="glass-card">
              <h3 style={{ marginBottom: '1rem' }}>الحرفيون المسجلون ({exhibition.registrations.length})</h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
                {exhibition.registrations.map(reg => (
                  <div key={reg.id} style={{ display: 'flex', justifyContent: 'space-between', padding: '0.75rem', backgroundColor: 'var(--bg-color)', borderRadius: '8px' }}>
                    <span style={{ fontWeight: '600' }}>{reg.Craftsman?.name || reg.craftsman?.name || '—'}</span>
                    <span style={{ color: 'var(--text-dim)', fontSize: '0.85rem' }}>{reg.craftCategory} | بوث #{reg.boothId}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Registration Form (Artisans only) */}
        {isArtisan && (
          <div style={{ flex: '1 1 35%' }}>
            {registerSuccess ? (
              <div className="glass-card" style={{ textAlign: 'center', padding: '2.5rem' }}>
                <div style={{ fontSize: '3rem', marginBottom: '1rem' }}>🎉</div>
                <h3>{parseFloat(formData.boothPrice || 0) === 0 ? 'تم إرسال طلب المشاركة بنجاح!' : 'تم تسجيلك بنجاح!'}</h3>
                <p style={{ color: 'var(--text-secondary)' }}>سيقوم منظم المعرض بمراجعة طلبك وتأكيد موقعك وإشعارك بالقرار.</p>
              </div>
            ) : (
              <div className="glass-card">
                <h3 style={{ marginBottom: '1.5rem' }}>التسجيل بالمعرض</h3>
                <form onSubmit={handleRegister} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                  <div>
                    <label style={styles.label}>فئة الحرفة</label>
                    <input type="text" className="input-field" placeholder="مثال: نسيج، خشب، فخار..." value={formData.craftCategory} onChange={e => setFormData({ ...formData, craftCategory: e.target.value })} required />
                  </div>
                  <div>
                    <label style={styles.label}>رقم البوث المطلوب</label>
                    <input type="text" className="input-field" placeholder="مثال: A12" value={formData.boothId} onChange={e => setFormData({ ...formData, boothId: e.target.value })} required />
                  </div>
                  <div>
                    <label style={styles.label}>سعر البوث (د.أ)</label>
                    <input type="number" className="input-field" placeholder="0" min="0" value={formData.boothPrice} onChange={e => setFormData({ ...formData, boothPrice: e.target.value })} required />
                  </div>
                  {parseFloat(formData.boothPrice || 0) > 0 && (
                    <label style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', cursor: 'pointer', fontWeight: '600' }}>
                      <input type="checkbox" checked={formData.hasPaid} onChange={e => setFormData({ ...formData, hasPaid: e.target.checked })} />
                      تمت عملية الدفع
                    </label>
                  )}
                  <button type="submit" className="btn-primary" disabled={registerLoading}>
                    {registerLoading
                      ? 'جاري المعالجة...'
                      : (parseFloat(formData.boothPrice || 0) === 0
                          ? 'إرسال طلب مشاركة'
                          : 'تسجيل في المعرض')}
                  </button>
                </form>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

const styles = {
  grid: { display: 'flex', flexWrap: 'wrap', gap: '1.5rem', alignItems: 'flex-start' },
  metaItem: { display: 'flex', alignItems: 'center', gap: '0.75rem', color: 'var(--text-secondary)' },
  label: { display: 'block', marginBottom: '0.4rem', fontWeight: '600', fontSize: '0.9rem', color: 'var(--text-primary)' },
};

export default ExhibitionDetails;
