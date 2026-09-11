import React from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

const AdminGuard = ({ children }) => {
  const { user, loading } = useAuth();
  if (loading) return <div className="container" style={{ padding: '4rem', textAlign: 'center' }}>جاري التحقق من الصلاحيات...</div>;
  if (!user || !(user.role === 'admin' || user.roles?.includes('admin'))) {
    return <Navigate to="/" replace />;
  }
  return children;
};

export default AdminGuard;
