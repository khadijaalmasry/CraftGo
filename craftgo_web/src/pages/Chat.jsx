import React, { useState, useEffect, useRef, useCallback } from 'react';
import { FaPaperPlane, FaComments, FaUser, FaCircle } from 'react-icons/fa';
import { useAuth } from '../context/AuthContext';
import api from '../services/api';

const Chat = () => {
  const { user } = useAuth();
  const [chats, setChats] = useState([]);
  const [selectedChat, setSelectedChat] = useState(null);
  const [messages, setMessages] = useState([]);
  const [newMessage, setNewMessage] = useState('');
  const [loadingChats, setLoadingChats] = useState(true);
  const [loadingMessages, setLoadingMessages] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');
  const messagesEndRef = useRef(null);
  const pollingRef = useRef(null);

  const fetchChats = useCallback(async () => {
    try {
      const res = await api.get('/chats');
      const data = res.data;
      setChats(Array.isArray(data) ? data : (data.chats || []));
    } catch {
      setError('تعذّر تحميل المحادثات');
    } finally {
      setLoadingChats(false);
    }
  }, []);

  useEffect(() => { fetchChats(); }, [fetchChats]);

  const fetchMessages = useCallback(async (chatId) => {
    try {
      const res = await api.get(`/chats/${chatId}/messages`);
      const data = res.data;
      setMessages(Array.isArray(data) ? data : (data.messages || []));
    } catch {}
  }, []);

  const selectChat = useCallback(async (chat) => {
    setSelectedChat(chat);
    setMessages([]);
    setLoadingMessages(true);
    setError('');
    if (pollingRef.current) clearInterval(pollingRef.current);
    try { await api.patch(`/chats/${chat.id}/read`); } catch {}
    try {
      const res = await api.get(`/chats/${chat.id}/messages`);
      const data = res.data;
      setMessages(Array.isArray(data) ? data : (data.messages || []));
    } catch { setError('تعذّر تحميل الرسائل'); }
    finally { setLoadingMessages(false); }
    pollingRef.current = setInterval(() => fetchMessages(chat.id), 5000);
  }, [fetchMessages]);

  useEffect(() => () => { if (pollingRef.current) clearInterval(pollingRef.current); }, []);

  useEffect(() => {
    if (messagesEndRef.current) {
      messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [messages]);

  const sendMessage = async (e) => {
    e.preventDefault();
    if (!newMessage.trim() || !selectedChat || sending) return;
    const content = newMessage.trim();
    setNewMessage('');
    setSending(true);
    try {
      await api.post(`/chats/${selectedChat.id}/messages`, { content });
      await fetchMessages(selectedChat.id);
      await fetchChats();
    } catch { setError('تعذّر إرسال الرسالة'); }
    finally { setSending(false); }
  };

  const getOtherPerson = (chat) => {
    if (!user) return null;
    return chat.customer?.id === user.id ? chat.craftsman : chat.customer;
  };

  const getLastMessage = (chat) => {
    if (!chat.messages?.length) return 'لا توجد رسائل';
    const last = chat.messages[chat.messages.length - 1];
    return last.content?.length > 35 ? last.content.slice(0, 35) + '...' : last.content;
  };

  const formatTime = (dateStr) => {
    try { return new Date(dateStr).toLocaleTimeString('ar', { hour: '2-digit', minute: '2-digit' }); }
    catch { return ''; }
  };

  const isSender = (msg) => msg.senderId === user?.id;

  return (
    <div className="container" style={{ padding: '1.5rem' }}>
      <h1 style={{ marginBottom: '1.5rem' }}>الدردشة</h1>
      <div className="fade-in" style={{
        display: 'flex', height: '75vh', borderRadius: '16px', overflow: 'hidden',
        boxShadow: 'var(--shadow-lg)', border: '1px solid var(--border-color)',
      }}>
        {/* SIDEBAR */}
        <aside style={{ width: '38%', background: '#1C2431', display: 'flex', flexDirection: 'column', borderLeft: '1px solid rgba(255,255,255,0.08)' }}>
          <div style={{ padding: '1.25rem', background: '#151e2d', borderBottom: '1px solid rgba(255,255,255,0.08)', display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <FaComments style={{ color: 'var(--accent-color)', fontSize: '1.2rem' }} />
            <h3 style={{ margin: 0, color: '#fff', fontFamily: 'var(--font-heading)' }}>المحادثات</h3>
          </div>
          <div style={{ flex: 1, overflowY: 'auto' }}>
            {loadingChats ? (
              <div style={{ padding: '2.5rem', textAlign: 'center', color: 'rgba(255,255,255,0.4)' }}>جاري التحميل...</div>
            ) : chats.length === 0 ? (
              <div style={{ padding: '3rem 1rem', textAlign: 'center', color: 'rgba(255,255,255,0.4)' }}>
                <FaComments style={{ fontSize: '3rem', marginBottom: '1rem', opacity: 0.3 }} />
                <p style={{ margin: 0 }}>لا توجد محادثات حالياً</p>
              </div>
            ) : chats.map((chat) => {
              const other = getOtherPerson(chat);
              const isSelected = selectedChat?.id === chat.id;
              return (
                <button key={chat.id} onClick={() => selectChat(chat)} style={{
                  width: '100%', background: isSelected ? 'rgba(212,175,55,0.15)' : 'transparent',
                  border: 'none', borderBottom: '1px solid rgba(255,255,255,0.05)',
                  padding: '1rem 1.25rem', cursor: 'pointer', display: 'flex', alignItems: 'center',
                  gap: '0.85rem', textAlign: 'right', transition: 'background 0.2s',
                }}>
                  <div style={{ width: '44px', height: '44px', borderRadius: '50%', flexShrink: 0, background: isSelected ? 'var(--accent-color)' : 'rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <FaUser style={{ color: isSelected ? '#1a1a2e' : 'rgba(255,255,255,0.5)', fontSize: '1rem' }} />
                  </div>
                  <div style={{ flex: 1, minWidth: 0, textAlign: 'right' }}>
                    <div style={{ color: '#fff', fontWeight: isSelected ? 700 : 500, fontSize: '0.9rem', marginBottom: '0.25rem', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {other?.name || 'مجهول'}
                    </div>
                    <div style={{ color: 'rgba(255,255,255,0.4)', fontSize: '0.78rem', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {getLastMessage(chat)}
                    </div>
                  </div>
                  {isSelected && <FaCircle style={{ color: 'var(--accent-color)', fontSize: '0.5rem', flexShrink: 0 }} />}
                </button>
              );
            })}
          </div>
        </aside>

        {/* MAIN PANEL */}
        <main style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'var(--bg-color)' }}>
          {!selectedChat ? (
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', color: 'var(--text-dim)', gap: '1rem' }}>
              <FaComments style={{ fontSize: '4rem', opacity: 0.2 }} />
              <p style={{ margin: 0 }}>اختر محادثة للبدء</p>
            </div>
          ) : (
            <>
              {/* Chat Header */}
              <div style={{ padding: '1rem 1.5rem', background: 'var(--surface-color)', borderBottom: '1px solid var(--border-color)', display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                <div style={{ width: '40px', height: '40px', borderRadius: '50%', background: 'var(--accent-color)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <FaUser style={{ color: '#fff', fontSize: '0.9rem' }} />
                </div>
                <div>
                  <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontFamily: 'var(--font-heading)' }}>
                    {getOtherPerson(selectedChat)?.name || 'مجهول'}
                  </div>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-dim)' }}>يتحدّث الآن</div>
                </div>
              </div>

              {/* Messages */}
              <div style={{ flex: 1, overflowY: 'auto', padding: '1.25rem 1.5rem', display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
                {loadingMessages ? (
                  <div style={{ textAlign: 'center', color: 'var(--text-dim)', padding: '2rem 0' }}>جاري التحميل...</div>
                ) : messages.length === 0 ? (
                  <div style={{ textAlign: 'center', color: 'var(--text-dim)', padding: '2rem 0' }}>لا توجد رسائل. ابدأ المحادثة!</div>
                ) : messages.map((msg) => {
                  const sender = isSender(msg);
                  return (
                    <div key={msg.id} style={{ display: 'flex', justifyContent: sender ? 'flex-start' : 'flex-end' }}>
                      <div style={{ maxWidth: '65%', display: 'flex', flexDirection: 'column', alignItems: sender ? 'flex-start' : 'flex-end', gap: '0.25rem' }}>
                        <div style={{
                          padding: '0.65rem 1rem',
                          borderRadius: sender ? '4px 16px 16px 16px' : '16px 4px 16px 16px',
                          background: sender ? 'var(--accent-color)' : 'var(--surface-color)',
                          color: sender ? '#1a1a2e' : 'var(--text-primary)',
                          fontSize: '0.9rem', lineHeight: 1.6,
                          boxShadow: 'var(--shadow-sm)',
                          border: sender ? 'none' : '1px solid var(--border-color)',
                          wordBreak: 'break-word',
                        }}>
                          {msg.content}
                        </div>
                        <span style={{ fontSize: '0.7rem', color: 'var(--text-dim)', padding: '0 0.25rem' }}>
                          {formatTime(msg.createdAt)}
                        </span>
                      </div>
                    </div>
                  );
                })}
                {error && <div style={{ textAlign: 'center', color: 'var(--danger-color)', fontSize: '0.85rem' }}>{error}</div>}
                <div ref={messagesEndRef} />
              </div>

              {/* Input Area */}
              <form onSubmit={sendMessage} style={{ padding: '1rem 1.5rem', background: 'var(--surface-color)', borderTop: '1px solid var(--border-color)', display: 'flex', gap: '0.75rem', alignItems: 'center' }}>
                <input
                  type="text"
                  className="input-field"
                  value={newMessage}
                  onChange={(e) => setNewMessage(e.target.value)}
                  placeholder="اكتب رسالتك هنا..."
                  disabled={sending}
                  style={{ flex: 1, margin: 0 }}
                />
                <button type="submit" disabled={!newMessage.trim() || sending} style={{
                  width: '44px', height: '44px', borderRadius: '50%', flexShrink: 0,
                  background: newMessage.trim() && !sending ? 'var(--accent-color)' : 'var(--border-color)',
                  border: 'none', cursor: newMessage.trim() && !sending ? 'pointer' : 'not-allowed',
                  display: 'flex', alignItems: 'center', justifyContent: 'center', transition: 'background 0.2s',
                }}>
                  <FaPaperPlane style={{ color: newMessage.trim() && !sending ? '#1a1a2e' : 'var(--text-dim)', fontSize: '1rem', transform: 'scaleX(-1)' }} />
                </button>
              </form>
            </>
          )}
        </main>
      </div>
    </div>
  );
};

export default Chat;
