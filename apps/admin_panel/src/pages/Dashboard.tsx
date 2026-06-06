import React, { useEffect, useState } from 'react';
import Sidebar from '../components/Sidebar';
import { supabase } from '../supabaseClient';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';

// Enhanced Interface to include nested items
interface OrderItem {
    id: number;
    quantity: number;
    price: number; // Mapped from price_at_time in query
    product: {
        name: string;
        image_url: string;
    };
}

interface Order {
  id: number;
  status: string;
  total_amount: number;
  delivery_address: string;
  created_at: string;
  order_items: OrderItem[]; // Nested items
  rider_id?: string;
}

const Dashboard: React.FC = () => {
    const [orders, setOrders] = useState<Order[]>([]);
    const [riders, setRiders] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);
    const [activeTab, setActiveTab] = useState<'pending' | 'preparing' | 'on_road' | 'past'>('pending');
    const navigate = useNavigate();

    useEffect(() => {
        const checkUser = async () => {
             const { data: { session } } = await supabase.auth.getSession();
            if (!session) {
                navigate('/');
            }
        };
        checkUser();
        fetchOrders();
        fetchRiders();

        // Realtime Subscription
        const channel = supabase
            .channel('public:orders')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, (payload) => {
                console.log('Change received!', payload);
                fetchOrders(); 
            })
            .subscribe();

        return () => {
            supabase.removeChannel(channel);
        };
    }, [navigate]);

    const fetchOrders = async () => {
        try {
            const { data, error } = await supabase
                .from('orders')
                .select(`
                    *,
                    order_items (
                        id,
                        quantity,
                        price:price_at_time,
                        product:products (
                            name,
                            image_url
                        )
                    )
                `)
                .order('created_at', { ascending: false });

            if (error) throw error;
            setOrders(data || []);
        } catch (error) {
            console.error("Error fetching orders:", error);
        } finally {
            setLoading(false);
        }
    };

    const fetchRiders = async () => {
        const { data } = await supabase.from('profiles').select('*').eq('role', 'rider');
        if (data) setRiders(data);
    };

    const assignRider = async (orderId: number, riderId: string) => {
        try {
            const { error } = await supabase
                .from('orders')
                .update({ rider_id: riderId, status: 'confirmed' }) 
                .eq('id', orderId);

            if (error) throw error;
            // Refetch orders after successful update to ensure UI updates immediately
            await fetchOrders();
        } catch (error) {
            console.error("Error signing rider:", error);
            alert("Failed to assign rider");
        }
    };

    const updateStatus = async (orderId: number, status: string) => {
        try {
            const { error } = await supabase
                .from('orders')
                .update({ status: status })
                .eq('id', orderId);

            if (error) throw error;
            // Refetch orders after successful update to ensure UI updates immediately
            await fetchOrders();
        } catch (error) {
            console.error("Error updating status:", error);
            alert("Failed to update status");
        }
    };

    const getFilteredOrders = () => {
        return orders.filter(order => {
            if (activeTab === 'pending') return order.status === 'pending';
            if (activeTab === 'preparing') return order.status === 'confirmed';
            if (activeTab === 'on_road') return order.status === 'out_for_delivery';
            if (activeTab === 'past') return ['delivered', 'cancelled'].includes(order.status);
            return false;
        });
    };

    const getTabCount = (tab: 'pending' | 'preparing' | 'on_road' | 'past') => {
        return orders.filter(order => {
            if (tab === 'pending') return order.status === 'pending';
            if (tab === 'preparing') return order.status === 'confirmed';
            if (tab === 'on_road') return order.status === 'out_for_delivery';
            if (tab === 'past') return ['delivered', 'cancelled'].includes(order.status);
            return false;
        }).length;
    };


  if (loading) {
    return (
        <div className="layout">
            <Sidebar />
            <div className="content" style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh', color: 'var(--text-primary)' }}>
                <h2>Loading live orders...</h2>
            </div>
        </div>
    );
  }

  const filteredOrders = getFilteredOrders();

  const getStatusColor = (status: string) => {
      switch (status) {
          case 'delivered': return 'var(--success)';
          case 'out_for_delivery': return 'var(--info)';
          case 'confirmed': return 'var(--accent-secondary)';
          case 'cancelled': return 'var(--danger)';
          default: return 'var(--accent-primary)';
      }
  };

  return (
    <div className="layout">
      <Sidebar />
      <div className="content">
        <h1 style={{ marginBottom: '30px', color: 'var(--text-primary)', fontSize: '2rem' }}>Dashboard Overview</h1>
        
        {/* Status Tabs */}
        <div style={{ display: 'flex', gap: '12px', marginBottom: '30px', borderBottom: '1px solid var(--border-color)', paddingBottom: '15px' }}>
            {['pending', 'preparing', 'on_road', 'past'].map((tab) => {
                const isActive = activeTab === tab;
                const count = getTabCount(tab as any);
                return (
                    <button 
                        key={tab}
                        onClick={() => setActiveTab(tab as any)}
                        style={{
                            display: 'flex',
                            alignItems: 'center',
                            gap: '8px',
                            background: isActive ? 'var(--accent-primary)' : 'var(--bg-surface-elevated)',
                            color: isActive ? '#0B0B0B' : 'var(--text-muted)',
                            border: '1px solid var(--border-color)',
                            padding: '8px 16px',
                            borderRadius: '30px',
                            cursor: 'pointer',
                            textTransform: 'capitalize',
                            fontWeight: isActive ? '600' : '500',
                            transition: 'all 0.3s ease',
                            boxShadow: isActive ? '0 4px 10px rgba(212, 175, 55, 0.2)' : 'none'
                        }}
                    >
                        <span>{tab.replace('_', ' ')}</span>
                        <span style={{
                            background: isActive ? 'rgba(0, 0, 0, 0.15)' : 'var(--bg-surface)',
                            color: isActive ? '#0B0B0B' : 'var(--text-primary)',
                            padding: '2px 8px',
                            borderRadius: '12px',
                            fontSize: '0.85em',
                            fontWeight: 'bold',
                            minWidth: '20px',
                            textAlign: 'center'
                        }}>
                            {count}
                        </span>
                    </button>
                );
            })}
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: '20px' }}>
          
          <div className="card">
            <h2 style={{ borderBottom: '1px solid var(--border-color)', paddingBottom: '15px', marginBottom: '20px', color: 'var(--text-primary)' }}>
                {activeTab === 'pending' ? 'New Orders' : 
                 activeTab === 'preparing' ? 'Kitchen (Preparing)' : 
                 activeTab === 'on_road' ? 'Out for Delivery' : 'Past Orders'} 
                ({filteredOrders.length})
            </h2>

            {filteredOrders.length === 0 ? <p style={{ color: 'var(--text-muted)' }}>No orders in this category.</p> : (
                <div style={{ display: 'grid', gap: '20px' }}>
                    {filteredOrders.map((order, idx) => (
                        <motion.div 
                            initial={{ opacity: 0, y: 10 }}
                            animate={{ opacity: 1, y: 0 }}
                            transition={{ delay: idx * 0.05 }}
                            key={order.id} 
                            style={{ 
                                background: 'var(--bg-surface-elevated)', 
                                padding: '24px', 
                                borderRadius: '12px',
                                borderLeft: `4px solid ${getStatusColor(order.status)}`,
                                border: '1px solid var(--border-color)',
                                borderLeftWidth: '4px'
                            }}
                        >
                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '20px' }}>
                                <div>
                                    <h3 style={{ margin: '0 0 8px 0', fontSize: '1.2em', color: 'var(--text-primary)' }}>Order #{order.id}</h3>
                                    <p style={{ margin: 0, color: 'var(--text-muted)', fontSize: '0.9em' }}>{new Date(order.created_at).toLocaleString()}</p>
                                    <p style={{ margin: '8px 0 0 0', color: 'var(--text-muted)', fontWeight: 500 }}>📍 {order.delivery_address}</p>
                                </div>
                                <div style={{ textAlign: 'right' }}>
                                    <div style={{ fontSize: '1.4em', fontWeight: 'bold', color: 'var(--accent-primary)' }}>₹{order.total_amount}</div>
                                    <span style={{ 
                                        display: 'inline-block',
                                        marginTop: '8px',
                                        fontSize: '0.8em', 
                                        padding: '6px 12px', 
                                        borderRadius: '20px', 
                                        background: 'var(--bg-surface)',
                                        color: getStatusColor(order.status),
                                        border: `1px solid ${getStatusColor(order.status)}`,
                                        textTransform: 'capitalize',
                                        fontWeight: 'bold'
                                    }}>
                                        {order.status.replace('_', ' ')}
                                    </span>
                                </div>
                            </div>
                            
                            {/* Order Items Detail */}
                            <div style={{ background: 'var(--bg-surface)', padding: '15px', borderRadius: '8px', marginBottom: '20px', border: '1px solid var(--border-color)' }}>
                                {order.order_items && order.order_items.length > 0 ? (
                                    order.order_items.map((item, idx) => (
                                        <div key={idx} style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.95em', marginBottom: '8px', color: 'var(--text-primary)' }}>
                                            <span>
                                                <span style={{ color: 'var(--accent-primary)', fontWeight: 'bold', marginRight: '5px' }}>{item.quantity}x</span> 
                                                {item.product?.name || 'Unknown Item'}
                                            </span>
                                            <span style={{ fontWeight: 500 }}>₹{item.price}</span>
                                        </div>
                                    ))
                                ) : (
                                    <div style={{ color: 'var(--text-muted)', fontSize: '0.8em' }}>No item details verified</div>
                                )}
                            </div>

                            {/* Actions Area */}
                            <div style={{ marginTop: '15px', borderTop: '1px solid var(--border-color)', paddingTop: '20px' }}>
                                
                                {/* 1. Pending: Assign Rider */}
                                {order.status === 'pending' && (
                                    <div style={{ display: 'flex', gap: '15px', alignItems: 'center' }}>
                                        <select 
                                            style={{ margin: 0, padding: '12px', borderRadius: '8px', background: 'var(--bg-surface)', color: 'var(--text-primary)', border: '1px solid var(--border-color)', flex: 1 }}
                                            onChange={(e) => {
                                                if (e.target.value) assignRider(order.id, e.target.value);
                                            }}
                                            defaultValue=""
                                        >
                                            <option value="" disabled>Select Rider to Assign...</option>
                                            {riders.map(r => (
                                                <option key={r.id} value={r.id}>{r.full_name || 'Rider'}</option>
                                            ))}
                                        </select>
                                    </div>
                                )}

                                {/* 2. Confirmed: Mark Out for Delivery */}
                                {order.status === 'confirmed' && (
                                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                        <span style={{ color: 'var(--accent-secondary)', fontStyle: 'italic', fontSize: '0.95em' }}>
                                            Rider Assigned. Preparing...
                                        </span>
                                        <button 
                                            className="btn btn-primary"
                                            onClick={() => updateStatus(order.id, 'out_for_delivery')}
                                            style={{ background: 'var(--info)', color: 'white' }}
                                        >
                                            Mark Out for Delivery →
                                        </button>
                                    </div>
                                )}

                                {/* 3. Out for Delivery: Mark Delivered */}
                                {order.status === 'out_for_delivery' && (
                                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                        <span style={{ color: 'var(--info)', fontStyle: 'italic', fontSize: '0.95em' }}>
                                            Rider is on the way...
                                        </span>
                                        <button 
                                            className="btn btn-primary"
                                            onClick={() => updateStatus(order.id, 'delivered')}
                                            style={{ background: 'var(--success)', color: 'white' }}
                                        >
                                            Mark Delivered ✓
                                        </button>
                                    </div>
                                )}
                                
                                {order.status === 'delivered' && (
                                    <div style={{ color: 'var(--success)', fontSize: '0.95em', fontStyle: 'italic', textAlign: 'center', fontWeight: 500 }}>
                                        Order Completed Successfully
                                    </div>
                                )}
                            </div>
                        </motion.div>
                    ))}
                </div>
            )}
          </div>

        </div>
      </div>
    </div>
  );
};

export default Dashboard;
