import React, { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import toast from 'react-hot-toast';
import { supabase } from '../supabaseClient';
import { playOrderAlertSound } from '../utils/orderSound';
import { FaBell, FaArrowRight } from 'react-icons/fa';

export const OrderNotificationListener: React.FC = () => {
  const navigate = useNavigate();

  useEffect(() => {
    // Listen for new orders inserted in realtime
    const channel = supabase
      .channel('global-order-alerts-channel')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'orders' },
        async (payload) => {
          const newOrder = payload.new as any;
          console.log('🔔 [OrderNotificationListener] New incoming order:', newOrder);

          // Play alert sound
          playOrderAlertSound();

          // Show interactive toast
          const orderId = newOrder?.id ?? '';
          const total = newOrder?.total_amount ? `₹${newOrder.total_amount}` : '';

          toast.custom(
            (t) => (
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '12px',
                  background: 'var(--card-bg, #1e293b)',
                  color: 'var(--text-primary, #ffffff)',
                  border: '1px solid var(--accent-primary, #10b981)',
                  boxShadow: '0 10px 25px -5px rgba(0, 0, 0, 0.4), 0 0 15px rgba(16, 185, 129, 0.3)',
                  borderRadius: '12px',
                  padding: '12px 16px',
                  maxWidth: '380px',
                  animation: t.visible ? 'scaleIn 0.25s ease-out' : 'scaleOut 0.2s ease-in',
                }}
              >
                <div
                  style={{
                    width: '38px',
                    height: '38px',
                    borderRadius: '50%',
                    background: 'rgba(16, 185, 129, 0.2)',
                    color: '#10b981',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: '18px',
                    flexShrink: 0,
                  }}
                >
                  <FaBell />
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 800, fontSize: '14px', color: '#10b981' }}>
                    New Order Received!
                  </div>
                  <div style={{ fontSize: '12.5px', color: 'var(--text-muted, #94a3b8)', marginTop: '2px' }}>
                    Order #{orderId} {total && `• ${total}`}
                  </div>
                </div>
                <button
                  onClick={() => {
                    toast.dismiss(t.id);
                    navigate('/orders');
                  }}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                    background: 'var(--accent-primary, #10b981)',
                    color: '#ffffff',
                    border: 'none',
                    borderRadius: '8px',
                    padding: '6px 10px',
                    fontSize: '12px',
                    fontWeight: 700,
                    cursor: 'pointer',
                    whiteSpace: 'nowrap',
                  }}
                >
                  View <FaArrowRight size={10} />
                </button>
              </div>
            ),
            { duration: 6000 }
          );
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [navigate]);

  return null;
};

export default OrderNotificationListener;
