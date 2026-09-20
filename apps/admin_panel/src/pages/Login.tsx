import React, { useState, useEffect } from 'react';
import { supabase } from '../supabaseClient';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { toast } from 'react-hot-toast';
import loginBg from '../assets/login-bg.png';

const Login: React.FC = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');
  const navigate = useNavigate();

  useEffect(() => {
    // Check if an existing session is already an admin
    supabase.auth.getSession().then(async ({ data: { session } }) => {
      if (session?.user) {
        const { data: profile } = await supabase
          .from('profiles')
          .select('role')
          .eq('id', session.user.id)
          .maybeSingle();

        if (profile?.role === 'admin') {
          navigate('/dashboard');
        } else {
          await supabase.auth.signOut();
        }
      }
    });
  }, [navigate]);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage('');
    setLoading(true);

    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (error) {
        setErrorMessage(error.message);
        toast.error(error.message);
        setLoading(false);
        return;
      }

      if (!data?.user) {
        const msg = 'Failed to obtain user session.';
        setErrorMessage(msg);
        toast.error(msg);
        setLoading(false);
        return;
      }

      // Check role in profiles
      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', data.user.id)
        .maybeSingle();

      if (profileError) {
        console.error('Error fetching profile:', profileError);
        await supabase.auth.signOut();
        const msg = 'Failed to verify account permissions. Please try again.';
        setErrorMessage(msg);
        toast.error(msg);
        setLoading(false);
        return;
      }

      if (profile?.role !== 'admin') {
        await supabase.auth.signOut();
        // const roleName = profile?.role || 'user';
        const msg = `Access denied: Only administrators can access this portal.`;
        setErrorMessage(msg);
        toast.error(msg);
        setLoading(false);
        return;
      }

      toast.success('Welcome back, Admin!');
      navigate('/dashboard');
    } catch (err: any) {
      console.error('Login error:', err);
      const msg = err?.message || 'An unexpected error occurred.';
      setErrorMessage(msg);
      toast.error(msg);
    } finally {
      setLoading(false);
    }
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
          color: '#FFFFFF',
          maxWidth: '500px'
        }}>
          <h1 style={{ fontSize: '3.5rem', marginBottom: '1rem', color: '#FFFFFF', textShadow: '0 4px 12px rgba(0,0,0,0.5)' }}>Quick Commerce</h1>
          <p style={{ fontSize: '1.2rem', color: '#FFFFFF', opacity: 0.9, lineHeight: 1.6, textShadow: '0 2px 4px rgba(0,0,0,0.5)', fontFamily: 'Inter' }}>
            Manage orders, inventory, and fleet operations with precision and speed.
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
          <div style={{ textAlign: 'center', marginBottom: '32px' }}>
            <h2 style={{ fontSize: '2.5rem', color: 'var(--accent-primary)', marginBottom: '10px' }}>Quick Comm</h2>
            <p style={{ color: 'var(--text-muted)', fontSize: '1rem' }}>Sign in to the Admin Portal</p>
          </div>

          {errorMessage && (
            <motion.div
              initial={{ opacity: 0, y: -6 }}
              animate={{ opacity: 1, y: 0 }}
              style={{
                marginBottom: '20px',
                padding: '12px 16px',
                backgroundColor: 'rgba(239, 68, 68, 0.12)',
                border: '1px solid rgba(239, 68, 68, 0.35)',
                borderRadius: '10px',
                color: '#f87171',
                fontSize: '0.875rem',
                lineHeight: 1.5,
              }}
            >
              <strong>Error:</strong> {errorMessage}
            </motion.div>
          )}

          <form onSubmit={handleLogin} style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <div>
              <label style={{ display: 'block', marginBottom: '8px', color: 'var(--text-muted)', fontSize: '0.9rem', fontWeight: 500 }}>Email Address</label>
              <input
                type="email"
                placeholder="admin@quickcomm.com"
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
            Secure Portal • Quick Comm Internal Use Only
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
