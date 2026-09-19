import React, { useEffect, useState, useCallback } from 'react';
import Sidebar from '../components/Sidebar';
import { supabase } from '../supabaseClient';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { FaShoppingBag, FaSyncAlt } from 'react-icons/fa';

interface OrderItem {
    id: number;
    quantity: number;
    price: number;
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
  order_items: OrderItem[];
  rider_id?: string;
}

const Orders: React.FC = () => {
    const [orders, setOrders] = useState<Order[]>([]);
    const [riders, setRiders] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);
    const [activeTab, setActiveTab] = useState<'pending' | 'preparing' | 'on_road' | 'past'>('pending');
    const navigate = useNavigate();

    const fetchOrders = useCallback(async () => {
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
    }, []);

    const fetchRiders = async () => {
        const { data } = await supabase.from('profiles').select('*').eq('role', 'rider');
        if (data) setRiders(data);
    };

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
            .channel('public:orders:orders-page')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, (payload) => {
                console.log('Order change received!', payload);
                fetchOrders(); 
            })
            .subscribe();

        return () => {
            supabase.removeChannel(channel);
        };
    }, [navigate, fetchOrders]);

    const assignRider = async (orderId: number, riderId: string) => {
        try {
            const { error } = await supabase
                .from('orders')
                .update({ rider_id: riderId }) 
                .eq('id', orderId);

            if (error) throw error;
            await fetchOrders();
        } catch (error) {
            console.error("Error assigning rider:", error);
        }
    };

    const cancelOrder = async (orderId: number) => {
        const confirmed = window.confirm(`Are you sure you want to cancel Order #${orderId}? This action cannot be undone.`);
        if (!confirmed) return;
        try {
            const { error } = await supabase
                .from('orders')
                .update({ status: 'cancelled' })
                .eq('id', orderId);

            if (error) throw error;
            await fetchOrders();
        } catch (error) {
            console.error("Error cancelling order:", error);
            alert("Failed to cancel order: " + (error as any)?.message);
        }
    };

    const updateStatus = async (orderId: number, newStatus: string) => {
        try {
            const updatePayload: Record<string, any> = { 
                status: newStatus,
                updated_at: new Date().toISOString()
            };
            if (newStatus === 'delivered') {
                updatePayload.delivered_at = new Date().toISOString();
            }

            const { error } = await supabase
                .from('orders')
                .update(updatePayload)
                .eq('id', orderId);

            if (error) throw error;
            await fetchOrders();
        } catch (error) {
            console.error("Error updating status:", error);
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
            <div className="main-content" style={{ display: 'flex', flexDirection: 'column', height: '100vh', overflow: 'hidden' }}>
                {/* Page Header */}
                <div style={{ padding: '24px 32px 16px', flexShrink: 0, borderBottom: '1px solid var(--border-color)', background: 'var(--bg-surface)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
                        <div>
                            <h1 style={{ margin: 0, color: 'var(--text-primary)', fontSize: '1.6rem', display: 'flex', alignItems: 'center', gap: 12 }}>
                                <FaShoppingBag color="var(--brand-primary)" /> Live Orders Pipeline
                            </h1>
                            <p style={{ margin: '4px 0 0', color: 'var(--text-muted)', fontSize: '0.9em' }}>
                                Manage incoming orders, preparation, and rider dispatches
                            </p>
                        </div>
                        <button
                            onClick={fetchOrders}
                            className="btn btn-ghost"
                            style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '0.88em' }}
                        >
                            <FaSyncAlt /> Refresh Orders
                        </button>
                    </div>

                    {/* Status Tabs */}
                    <div style={{ display: 'flex', gap: 10, flexWrap: 'nowrap', overflowX: 'auto' }}>
                        {[
                            { key: 'pending', label: 'New Orders' },
                            { key: 'preparing', label: 'Preparing' },
                            { key: 'on_road', label: 'Out for Delivery' },
                            { key: 'past', label: 'Past Orders' }
                        ].map((t) => {
                            const tabKey = t.key as 'pending' | 'preparing' | 'on_road' | 'past';
                            const isActive = activeTab === tabKey;
                            const count = getTabCount(tabKey);
                            return (
                                <button 
                                    key={tabKey}
                                    onClick={() => setActiveTab(tabKey)}
                                    style={{
                                        display: 'flex',
                                        alignItems: 'center',
                                        gap: 8,
                                        background: isActive ? 'var(--brand-primary)' : 'var(--bg-surface-elevated)',
                                        color: isActive ? '#FFFFFF' : 'var(--text-secondary)',
                                        border: `1px solid ${isActive ? 'var(--brand-primary)' : 'var(--border)'}`,
                                        padding: '7px 16px',
                                        borderRadius: 'var(--radius-full)',
                                        cursor: 'pointer',
                                        fontWeight: isActive ? 700 : 500,
                                        fontSize: '0.85em',
                                        transition: 'all var(--transition-fast)',
                                        boxShadow: isActive ? '0 2px 8px rgba(27, 166, 114, 0.25)' : 'none',
                                        whiteSpace: 'nowrap'
                                    }}
                                >
                                    <span>{t.label}</span>
                                    <span style={{
                                        background: isActive ? 'rgba(255, 255, 255, 0.25)' : 'var(--bg-surface)',
                                        color: isActive ? '#FFFFFF' : 'var(--text-primary)',
                                        padding: '1px 7px',
                                        borderRadius: '12px',
                                        fontSize: '0.82em',
                                        fontWeight: 800,
                                        minWidth: 20,
                                        textAlign: 'center'
                                    }}>
                                        {count}
                                    </span>
                                </button>
                            );
                        })}
                    </div>
                </div>

                {/* Orders Feed */}
                <div style={{ flex: 1, overflowY: 'auto', padding: '24px 32px 32px' }}>
                    {loading ? (
                        <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: 200, color: 'var(--text-muted)' }}>
                            Loading live orders...
                        </div>
                    ) : filteredOrders.length === 0 ? (
                        <div className="empty-state">
                            <FaShoppingBag style={{ fontSize: 40, color: 'var(--text-muted)', marginBottom: 12 }} />
                            <h3>No orders in this status</h3>
                            <p>Orders will automatically appear here when placed</p>
                        </div>
                    ) : (
                        <div style={{ display: 'grid', gap: 16 }}>
                            {filteredOrders.map((order, idx) => (
                                <motion.div 
                                    initial={{ opacity: 0, y: 8 }}
                                    animate={{ opacity: 1, y: 0 }}
                                    transition={{ delay: idx * 0.03 }}
                                    key={order.id} 
                                    style={{ 
                                        background: 'var(--bg-surface)', 
                                        padding: '20px 24px', 
                                        borderRadius: 'var(--radius-lg)',
                                        borderLeft: `4px solid ${getStatusColor(order.status)}`,
                                        border: '1px solid var(--border)',
                                        boxShadow: 'var(--shadow-xs)',
                                        display: 'flex',
                                        flexDirection: 'column',
                                        gap: 14
                                    }}
                                >
                                    {/* Order Top Bar */}
                                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 8 }}>
                                        <div>
                                            <span style={{ fontSize: '1.05rem', fontWeight: 800, color: 'var(--text-primary)' }}>
                                                Order #{order.id}
                                            </span>
                                            <span style={{ marginLeft: 10, fontSize: '0.82em', color: 'var(--text-muted)' }}>
                                                {new Date(order.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', month: 'short', day: 'numeric' })}
                                            </span>
                                        </div>
                                        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                                            <span style={{ fontSize: '1.1rem', fontWeight: 800, color: 'var(--text-primary)' }}>
                                                ₹{order.total_amount}
                                            </span>
                                            <span style={{
                                                padding: '3px 10px',
                                                borderRadius: 'var(--radius-full)',
                                                fontSize: '0.78em',
                                                fontWeight: 700,
                                                textTransform: 'uppercase',
                                                background: `${getStatusColor(order.status)}18`,
                                                color: getStatusColor(order.status)
                                            }}>
                                                {order.status.replaceAll('_', ' ')}
                                            </span>
                                        </div>
                                    </div>

                                    {/* Delivery Address */}
                                    <div style={{ color: 'var(--text-secondary)', fontSize: '0.88em' }}>
                                        📍 {order.delivery_address || 'No address provided'}
                                    </div>

                                    {/* Items Ordered List */}
                                    <div style={{ background: 'var(--bg-surface-elevated)', padding: '12px 16px', borderRadius: 'var(--radius-md)' }}>
                                        <div style={{ fontSize: '0.78em', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', marginBottom: 8 }}>
                                            Items ({order.order_items?.length || 0})
                                        </div>
                                        {order.order_items && order.order_items.length > 0 ? (
                                            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: 8 }}>
                                                {order.order_items.map(item => (
                                                    <div key={item.id} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: '0.85em', color: 'var(--text-primary)' }}>
                                                        <span style={{ fontWeight: 700, minWidth: 20, color: 'var(--brand-primary)' }}>{item.quantity}x</span>
                                                        <span style={{ flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                                                            {item.product?.name || 'Item'}
                                                        </span>
                                                        <span style={{ color: 'var(--text-muted)', fontSize: '0.88em' }}>₹{item.price}</span>
                                                    </div>
                                                ))}
                                            </div>
                                        ) : (
                                            <div style={{ color: 'var(--text-muted)', fontSize: '0.85em' }}>No item details</div>
                                        )}
                                    </div>

                                    {/* Action Bar */}
                                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingTop: 6, borderTop: '1px solid var(--border)', flexWrap: 'wrap', gap: 10 }}>
                                        {order.status === 'pending' && (
                                            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap', width: '100%' }}>
                                                <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                                                    <span style={{ fontSize: '0.85em', color: 'var(--text-muted)', fontWeight: 600 }}>Assign Rider:</span>
                                                    <select 
                                                        style={{ 
                                                            padding: '6px 12px', 
                                                            borderRadius: 'var(--radius-sm)', 
                                                            border: '1px solid var(--border)', 
                                                            background: 'var(--bg-input)', 
                                                            color: 'var(--text-primary)',
                                                            fontSize: '0.85em',
                                                            cursor: 'pointer'
                                                        }}
                                                        value={order.rider_id || ''}
                                                        onChange={(e) => assignRider(order.id, e.target.value)}
                                                    >
                                                        <option value="" disabled>Select available rider...</option>
                                                        {riders.map(r => (
                                                            <option key={r.id} value={r.id}>{r.full_name}</option>
                                                        ))}
                                                    </select>
                                                </div>
                                                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginLeft: 'auto' }}>
                                                    <button
                                                        onClick={() => cancelOrder(order.id)}
                                                        className="btn"
                                                        style={{ 
                                                            padding: '6px 12px', 
                                                            fontSize: '0.85em',
                                                            border: '1px solid var(--border)',
                                                            color: 'var(--danger)',
                                                            background: 'transparent',
                                                            cursor: 'pointer'
                                                        }}
                                                    >
                                                        Cancel
                                                    </button>
                                                    <button
                                                        onClick={() => updateStatus(order.id, 'confirmed')}
                                                        className="btn btn-primary"
                                                        style={{ padding: '6px 14px', fontSize: '0.85em' }}
                                                    >
                                                        Accept &amp; Prepare
                                                    </button>
                                                </div>
                                            </div>
                                        )}

                                        {order.status === 'confirmed' && (
                                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10, flexWrap: 'wrap', width: '100%' }}>
                                                <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                                                    <span style={{ fontSize: '0.85em', color: 'var(--text-muted)', fontWeight: 600 }}>Rider:</span>
                                                    <select 
                                                        style={{ 
                                                            padding: '6px 12px', 
                                                            borderRadius: 'var(--radius-sm)', 
                                                            border: '1px solid var(--border)', 
                                                            background: 'var(--bg-input)', 
                                                            color: 'var(--text-primary)',
                                                            fontSize: '0.85em',
                                                            cursor: 'pointer'
                                                        }}
                                                        value={order.rider_id || ''}
                                                        onChange={(e) => assignRider(order.id, e.target.value)}
                                                    >
                                                        <option value="" disabled>Select rider...</option>
                                                        {riders.map(r => (
                                                            <option key={r.id} value={r.id}>{r.full_name}</option>
                                                        ))}
                                                    </select>
                                                </div>
                                                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginLeft: 'auto' }}>
                                                    <button
                                                        onClick={() => cancelOrder(order.id)}
                                                        className="btn"
                                                        style={{ 
                                                            padding: '6px 12px', 
                                                            fontSize: '0.85em',
                                                            border: '1px solid var(--border)',
                                                            color: 'var(--danger)',
                                                            background: 'transparent',
                                                            cursor: 'pointer'
                                                        }}
                                                    >
                                                        Cancel
                                                    </button>
                                                    <button 
                                                        className="btn btn-primary"
                                                        onClick={() => updateStatus(order.id, 'out_for_delivery')}
                                                        style={{ padding: '6px 14px', fontSize: '0.85em' }}
                                                    >
                                                        Dispatch Order &rarr;
                                                    </button>
                                                </div>
                                            </div>
                                        )}

                                        {order.status === 'out_for_delivery' && (
                                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10, flexWrap: 'wrap', width: '100%' }}>
                                                <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                                                    <span style={{ fontSize: '0.85em', color: 'var(--info)', fontWeight: 600 }}>🛵 Rider:</span>
                                                    <select 
                                                        style={{ 
                                                            padding: '6px 12px', 
                                                            borderRadius: 'var(--radius-sm)', 
                                                            border: '1px solid var(--border)', 
                                                            background: 'var(--bg-input)', 
                                                            color: 'var(--text-primary)',
                                                            fontSize: '0.85em',
                                                            cursor: 'pointer'
                                                        }}
                                                        value={order.rider_id || ''}
                                                        onChange={(e) => assignRider(order.id, e.target.value)}
                                                    >
                                                        <option value="" disabled>Select rider...</option>
                                                        {riders.map(r => (
                                                            <option key={r.id} value={r.id}>{r.full_name}</option>
                                                        ))}
                                                    </select>
                                                </div>
                                                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginLeft: 'auto' }}>
                                                    <button
                                                        onClick={() => cancelOrder(order.id)}
                                                        className="btn"
                                                        style={{ 
                                                            padding: '6px 12px', 
                                                            fontSize: '0.85em',
                                                            border: '1px solid var(--border)',
                                                            color: 'var(--danger)',
                                                            background: 'transparent',
                                                            cursor: 'pointer'
                                                        }}
                                                    >
                                                        Cancel
                                                    </button>
                                                    <button 
                                                        className="btn btn-primary"
                                                        onClick={() => updateStatus(order.id, 'delivered')}
                                                        style={{ background: 'var(--success)', color: 'white', padding: '6px 14px', fontSize: '0.85em' }}
                                                    >
                                                        Mark Delivered ✓
                                                    </button>
                                                </div>
                                            </div>
                                        )}
                                        
                                        {['delivered', 'cancelled'].includes(order.status) && (
                                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%' }}>
                                                <div style={{ color: order.status === 'delivered' ? 'var(--success)' : 'var(--danger)', fontSize: '0.85em', fontWeight: 600 }}>
                                                    {order.status === 'delivered' ? '✓ Order Completed Successfully' : '✕ Order Cancelled'}
                                                </div>
                                                {order.rider_id && (
                                                    <span style={{ fontSize: '0.82em', color: 'var(--text-muted)' }}>
                                                        Delivered by: <strong style={{ color: 'var(--text-primary)' }}>{riders.find(r => r.id === order.rider_id)?.full_name || 'Rider'}</strong>
                                                    </span>
                                                )}
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
    );
};

export default Orders;
