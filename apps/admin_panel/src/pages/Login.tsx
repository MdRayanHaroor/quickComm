import React, { useState } from 'react';
import { supabase } from '../supabaseClient';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import loginBg from '../assets/login-bg.png';

const Login: React.FC = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      alert(error.message);
    } else {
      navigate('/dashboard');
    }
    setLoading(false);
  };

  return (
    <div style={{ display: 'flex', height: '100vh', width: '100vw', overflow: 'hidden', backgroundColor: 'var(--bg-primary)' }}>
      {/* Left Section - Image & Storytelling */}
      <motion.div 
        initial={{ opacity: 0, x: -50 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ duration: 0.8, ease: "easeOut" }}
        style={{ 
          flex: 1.2, 
          position: 'relative',
          display: 'none' // Hide on small screens
        }}
        className="login-image-section"
      >
        <div style={{
          position: 'absolute',
          top: 0, left: 0, right: 0, bottom: 0,
          backgroundImage: `url(${loginBg})`,
          backgroundSize: 'cover',
          backgroundPosition: 'center',
        }} />
        {/* Gradient Overlay */}
        <div style={{
          position: 'absolute',
          top: 0, left: 0, right: 0, bottom: 0,
          background: 'linear-gradient(to right, rgba(0,0,0,0.8) 0%, rgba(0,0,0,0.2) 50%, rgba(0,0,0,0.8) 100%)',
        }} />
        
        <div style={{
          position: 'absolute',
          bottom: '10%',
          left: '10%',
          color: 'white',
          maxWidth: '500px'
        }}>
          <h1 style={{ fontSize: '3.5rem', marginBottom: '1rem', textShadow: '0 4px 12px rgba(0,0,0,0.5)' }}>Experience the Royalty</h1>
          <p style={{ fontSize: '1.2rem', opacity: 0.9, lineHeight: 1.6, textShadow: '0 2px 4px rgba(0,0,0,0.5)', fontFamily: 'Inter' }}>
            Manage the finest authentic Indian biryani with precision, elegance, and speed.
          </p>
        </div>
      </motion.div>

      {/* Right Section - Login Form */}
      <motion.div 
        initial={{ opacity: 0, x: 50 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ duration: 0.8, ease: "easeOut", delay: 0.2 }}
        style={{ 
          flex: 1, 
          display: 'flex', 
          justifyContent: 'center', 
          alignItems: 'center',
          backgroundColor: 'var(--bg-surface)'
        }}
      >
        <div style={{ width: '100%', maxWidth: '400px', padding: '40px' }}>
          <div style={{ textAlign: 'center', marginBottom: '40px' }}>
            <h2 style={{ fontSize: '2.5rem', color: 'var(--accent-primary)', marginBottom: '10px' }}>Taj Biryani</h2>
            <p style={{ color: 'var(--text-muted)', fontSize: '1rem' }}>Sign in to the Admin Portal</p>
          </div>

          <form onSubmit={handleLogin} style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <div>
              <label style={{ display: 'block', marginBottom: '8px', color: 'var(--text-muted)', fontSize: '0.9rem', fontWeight: 500 }}>Email Address</label>
              <input
                type="email"
                placeholder="admin@tajbiryani.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                style={{ 
                  width: '100%', 
                  padding: '14px 16px', 
                  backgroundColor: 'var(--bg-surface-elevated)', 
                  border: '1px solid var(--border-color)', 
                  borderRadius: '10px',
                  color: 'var(--text-primary)',
                  fontSize: '1rem'
                }}
              />
            </div>
            
            <div>
              <label style={{ display: 'block', marginBottom: '8px', color: 'var(--text-muted)', fontSize: '0.9rem', fontWeight: 500 }}>Password</label>
              <input
                type="password"
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                style={{ 
                  width: '100%', 
                  padding: '14px 16px', 
                  backgroundColor: 'var(--bg-surface-elevated)', 
                  border: '1px solid var(--border-color)', 
                  borderRadius: '10px',
                  color: 'var(--text-primary)',
                  fontSize: '1rem',
                  letterSpacing: '2px'
                }}
              />
            </div>

            <motion.button 
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              type="submit" 
              disabled={loading} 
              className="btn btn-primary"
              style={{ 
                width: '100%', 
                padding: '16px', 
                fontSize: '1.1rem',
                marginTop: '10px',
                borderRadius: '10px',
                fontWeight: 600
              }}
            >
              {loading ? 'Authenticating...' : 'Sign In'}
            </motion.button>
          </form>
          
          <div style={{ marginTop: '30px', textAlign: 'center', color: 'var(--text-muted)', fontSize: '0.85rem' }}>
            Secure Portal • Taj Biryani Internal Use Only
          </div>
        </div>
      </motion.div>

      <style>{`
        @media (min-width: 900px) {
          .login-image-section {
            display: block !important;
          }
        }
      `}</style>
    </div>
  );
};

export default Login;
