import React, { useState, useEffect } from 'react';
import { useAuth } from '../../context/AuthContext';
import api from '../../services/api';
import { FaUser, FaEnvelope, FaPhone, FaMapMarkerAlt, FaEdit } from 'react-icons/fa';

const CustomerProfile = () => {
  const { user } = useAuth();
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);
  const [isEditing, setIsEditing] = useState(false);
  const [formData, setFormData] = useState({});

  useEffect(() => {
    if (!user?.id) return;
    api.get('/auth/me').then(res => {
      setProfile(res.data.user || res.data);
      setFormData(res.data.user || res.data);
    }).catch(() => {}).finally(() => setLoading(false));
  }, [user]);

  const handleUpdate = async (e) => {
    e.preventDefault();
    try {
      await api.patch('/auth/update', formData);
      setProfile(formData);
      setIsEditing(false);
      alert('تم التحديث بنجاح');
    } catch {
      alert('فشل في تحديث البيانات');
    }
  };

  if (loading) return <div className="container" style={{ padding: '4rem', textAlign: 'center' }}>جاري التحميل...</div>;
  if (!profile) return <div className="container" style={{ padding: '4rem', textAlign: 'center' }}>حدث خطأ.</div>;

  return (
    <div className="container fade-in" style={{ padding: '2rem 1.5rem', minHeight: '80vh', display: 'flex', justifyContent: 'center' }}>
      <div className="glass-card" style={{ width: '100%', maxWidth: '600px', padding: '2.5rem' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
          <h1 style={{ margin: 0, display: 'flex', alignItems: 'center', gap: '0.75rem' }}><FaUser /> ملفي الشخصي</h1>
          <button onClick={() => setIsEditing(!isEditing)} style={{ background: 'none', border: 'none', color: 'var(--accent-color)', cursor: 'pointer', fontSize: '1.2rem' }}>
            <FaEdit />
          </button>
        </div>

        {isEditing ? (
          <form onSubmit={handleUpdate} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            <div>
              <label style={styles.label}>الاسم</label>
              <input type="text" className="input-field" value={formData.name || ''} onChange={e => setFormData({ ...formData, name: e.target.value })} required />
            </div>
            <div>
              <label style={styles.label}>رقم الهاتف</label>
              <input type="text" className="input-field" value={formData.phone || ''} onChange={e => setFormData({ ...formData, phone: e.target.value })} />
            </div>
            <div>
              <label style={styles.label}>العنوان</label>
              <input type="text" className="input-field" value={formData.address || ''} onChange={e => setFormData({ ...formData, address: e.target.value })} />
            </div>
            <button type="submit" className="btn-primary" style={{ marginTop: '1rem' }}>حفظ التغييرات</button>
          </form>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
            <div style={styles.infoRow}><FaUser color="var(--text-dim)" /> <strong>الاسم:</strong> {profile.name}</div>
            <div style={styles.infoRow}><FaEnvelope color="var(--text-dim)" /> <strong>البريد الإلكتروني:</strong> {profile.email}</div>
            <div style={styles.infoRow}><FaPhone color="var(--text-dim)" /> <strong>رقم الهاتف:</strong> {profile.phone || '—'}</div>
            <div style={styles.infoRow}><FaMapMarkerAlt color="var(--text-dim)" /> <strong>العنوان:</strong> {profile.address || '—'}</div>
          </div>
        )}
      </div>
    </div>
  );
};

const styles = {
  label: { display: 'block', marginBottom: '0.5rem', fontWeight: '600', color: 'var(--text-primary)' },
  infoRow: { display: 'flex', alignItems: 'center', gap: '0.75rem', fontSize: '1.1rem', color: 'var(--text-secondary)' }
};

export default CustomerProfile;
