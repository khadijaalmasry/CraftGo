import React, { useState, useEffect, useRef } from 'react';
import { FaBell, FaCheckDouble, FaTrash } from 'react-icons/fa';
import api from '../services/api';
import { useAuth } from '../context/AuthContext';

const NotificationBell = () => {
  const { isAuthenticated } = useAuth();
  const [notifications, setNotifications] = useState([]);
  const [open, setOpen] = useState(false);
  const dropdownRef = useRef(null);

  const unreadCount = notifications.filter(n => !n.isRead).length;

  const fetchNotifications = async () => {
    if (!isAuthenticated) return;
    try {
      const res = await api.get('/notifications');
      const data = res.data;
      setNotifications(Array.isArray(data) ? data : (data.notifications || data.data || []));
    } catch (err) {
      // silently fail
    }
  };

  useEffect(() => {
    fetchNotifications();
    const interval = setInterval(fetchNotifications, 30000);
    return () => clearInterval(interval);
  }, [isAuthenticated]);

  // Close on outside click
  useEffect(() => {
    const handleClickOutside = (e) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target)) {
        setOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const handleMarkRead = async (id) => {
    try {
      await api.patch(`/notifications/${id}/read`);
      setNotifications(prev => prev.map(n => n.id === id ? { ...n, isRead: true } : n));
    } catch (err) {}
  };

  const handleMarkAllRead = async () => {
    try {
      await api.patch('/notifications/read-all');
      setNotifications(prev => prev.map(n => ({ ...n, isRead: true })));
    } catch (err) {}
  };

  const formatTime = (date) => {
    try {
      return new Date(date).toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit' });
    } catch { return ''; }
  };

  if (!isAuthenticated) return null;

  return (
    <div ref={dropdownRef} style={{ position: 'relative' }}>
      <button
        onClick={() => setOpen(!open)}
        style={{ background: 'none', position: 'relative', display: 'flex', alignItems: 'center', color: 'var(--text-primary)' }}
        title="الإشعارات"
      >
        <FaBell size={22} />
        {unreadCount > 0 && (
          <span style={{
            position: 'absolute', top: '-6px', right: '-6px',
            backgroundColor: 'var(--danger-color)', color: '#fff',
            fontSize: '0.65rem', fontWeight: 'bold', borderRadius: '50%',
            width: '16px', height: '16px', display: 'flex', alignItems: 'center', justifyContent: 'center'
          }}>
            {unreadCount > 9 ? '9+' : unreadCount}
          </span>
        )}
      </button>

      {open && (
        <div style={styles.dropdown}>
          <div style={styles.dropdownHeader}>
            <h4 style={{ margin: 0 }}>الإشعارات</h4>
            {unreadCount > 0 && (
              <button onClick={handleMarkAllRead} style={styles.markAllBtn} title="تعليم الكل كمقروء">
                <FaCheckDouble size={14} /> تعليم الكل
              </button>
            )}
          </div>

          <div style={styles.notifList}>
            {notifications.length === 0 ? (
              <p style={{ textAlign: 'center', color: 'var(--text-dim)', padding: '2rem 1rem' }}>
                لا توجد إشعارات
              </p>
            ) : (
              notifications.slice(0, 8).map(notif => (
                <div
                  key={notif.id}
                  onClick={() => handleMarkRead(notif.id)}
                  style={{
                    ...styles.notifItem,
                    backgroundColor: notif.isRead ? 'transparent' : 'rgba(212, 160, 23, 0.07)',
                    borderRight: notif.isRead ? '3px solid transparent' : '3px solid var(--accent-color)'
                  }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                    <strong style={{ fontSize: '0.9rem', color: 'var(--text-primary)' }}>
                      {notif.title || notif.type || 'إشعار'}
                    </strong>
                    <span style={{ fontSize: '0.75rem', color: 'var(--text-dim)', whiteSpace: 'nowrap', marginRight: '0.5rem' }}>
                      {formatTime(notif.createdAt)}
                    </span>
                  </div>
                  <p style={{ margin: '0.25rem 0 0', fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
                    {notif.body || notif.message || ''}
                  </p>
                </div>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  );
};

const styles = {
  dropdown: {
    position: 'absolute',
    top: '40px',
    left: '-220px',
    width: '320px',
    backgroundColor: 'var(--surface-color)',
    border: '1px solid var(--border-color)',
    borderRadius: '12px',
    boxShadow: 'var(--shadow-lg)',
    zIndex: 999,
    overflow: 'hidden',
  },
  dropdownHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '1rem',
    borderBottom: '1px solid var(--border-color)',
    backgroundColor: 'var(--bg-color)',
  },
  markAllBtn: {
    background: 'none',
    color: 'var(--accent-color)',
    fontSize: '0.8rem',
    fontWeight: 'bold',
    display: 'flex',
    alignItems: 'center',
    gap: '0.25rem',
  },
  notifList: {
    maxHeight: '380px',
    overflowY: 'auto',
  },
  notifItem: {
    padding: '0.85rem 1rem',
    cursor: 'pointer',
    borderBottom: '1px solid var(--border-color)',
    transition: 'background-color 0.15s',
  }
};

export default NotificationBell;
