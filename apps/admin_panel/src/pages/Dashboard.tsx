import React, { useEffect, useState } from 'react';
import Sidebar from '../components/Sidebar';
import { supabase } from '../supabaseClient';
import { useNavigate } from 'react-router-dom';

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

  if (loading) {
    return (
        <div className="layout">
            <Sidebar />
            <div className="content" style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh', color: 'white' }}>
                <h2>Loading live orders...</h2>
            </div>
        </div>
    );
  }

  const filteredOrders = getFilteredOrders();

  return (
    <div className="layout">
      <Sidebar />
      <div className="content">
        <h1 style={{ marginBottom: '20px' }}>Dashboard</h1>
        
        {/* Status Tabs */}
        <div style={{ display: 'flex', gap: '10px', marginBottom: '20px', borderBottom: '1px solid #374151', paddingBottom: '10px' }}>
            {['pending', 'preparing', 'on_road', 'past'].map((tab) => (
                <button 
                    key={tab}
                    onClick={() => setActiveTab(tab as any)}
                    style={{
                        background: activeTab === tab ? 'var(--primary)' : 'transparent',
                        color: activeTab === tab ? 'white' : 'var(--text-dim)',
                        border: activeTab === tab ? 'none' : '1px solid #374151',
                        padding: '8px 16px',
                        borderRadius: '20px',
                        cursor: 'pointer',
                        textTransform: 'capitalize',
                        fontWeight: 'bold'
                    }}
                >
                    {tab.replace('_', ' ')}
                </button>
            ))}
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: '20px' }}>
          
          <div className="card">
            <h2 style={{ borderBottom: '1px solid #374151', paddingBottom: '10px', marginBottom: '15px' }}>
                {activeTab === 'pending' ? 'New Orders' : 
                 activeTab === 'preparing' ? 'Kitchen (Preparing)' : 
                 activeTab === 'on_road' ? 'Out for Delivery' : 'Past Orders'} 
                ({filteredOrders.length})
            </h2>

            {filteredOrders.length === 0 ? <p style={{ color: 'var(--text-dim)' }}>No orders in this category.</p> : (
                <div style={{ display: 'grid', gap: '15px' }}>
                    {filteredOrders.map(order => (
                        <div key={order.id} style={{ 
                            background: 'rgba(255,255,255,0.05)', 
                            padding: '20px', 
                            borderRadius: '8px',
                            borderLeft: `4px solid ${
                                order.status === 'delivered' ? 'var(--primary)' : 
                                order.status === 'out_for_delivery' ? '#3B82F6' :
                                order.status === 'confirmed' ? '#F59E0B' : 'var(--danger)'}`,
                        }}>
                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '15px' }}>
                                <div>
                                    <h3 style={{ margin: '0 0 5px 0', fontSize: '1.2em' }}>Order #{order.id}</h3>
                                    <p style={{ margin: 0, color: 'var(--text-dim)', fontSize: '0.9em' }}>{new Date(order.created_at).toLocaleString()}</p>
                                    <p style={{ margin: '5px 0 0 0', color: 'var(--text-dim)' }}>📍 {order.delivery_address}</p>
                                </div>
                                <div style={{ textAlign: 'right' }}>
                                    <div style={{ fontSize: '1.2em', fontWeight: 'bold' }}>₹{order.total_amount}</div>
                                    <span style={{ 
                                        display: 'inline-block',
                                        marginTop: '5px',
                                        fontSize: '0.8em', 
                                        padding: '4px 8px', 
                                        borderRadius: '4px', 
                                        background: '#374151',
                                        textTransform: 'capitalize'
                                    }}>
                                        {order.status.replace('_', ' ')}
                                    </span>
                                </div>
                            </div>
                            
                            {/* Order Items Detail */}
                            <div style={{ background: 'rgba(0,0,0,0.2)', padding: '10px', borderRadius: '6px', marginBottom: '15px' }}>
                                {order.order_items && order.order_items.length > 0 ? (
                                    order.order_items.map((item, idx) => (
                                        <div key={idx} style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.9em', marginBottom: '5px' }}>
                                            <span>
                                                <span style={{ color: 'var(--primary)', fontWeight: 'bold' }}>{item.quantity}x</span> {item.product?.name || 'Unknown Item'}
                                            </span>
                                            <span>₹{item.price}</span>
                                        </div>
                                    ))
                                ) : (
                                    <div style={{ color: 'var(--text-dim)', fontSize: '0.8em' }}>No items details verified</div>
                                )}
                            </div>

                            {/* Actions Area */}
                            <div style={{ marginTop: '15px', borderTop: '1px solid rgba(255,255,255,0.1)', paddingTop: '15px' }}>
                                
                                {/* 1. Pending: Assign Rider */}
                                {order.status === 'pending' && (
                                    <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
                                        <select 
                                            style={{ padding: '8px', borderRadius: '4px', background: '#1F2937', color: 'white', border: '1px solid #374151', flex: 1 }}
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
                                        <span style={{ color: '#F59E0B', fontStyle: 'italic', fontSize: '0.9em' }}>
                                            Rider Assigned. Preparing...
                                        </span>
                                        <button 
                                            onClick={() => updateStatus(order.id, 'out_for_delivery')}
                                            style={{ 
                                                padding: '8px 16px', 
                                                background: '#3B82F6', 
                                                color: 'white', 
                                                border: 'none', 
                                                borderRadius: '4px', 
                                                cursor: 'pointer',
                                                fontWeight: 'bold'
                                            }}
                                        >
                                            Mark Out for Delivery →
                                        </button>
                                    </div>
                                )}

                                {/* 3. Out for Delivery: Mark Delivered */}
                                {order.status === 'out_for_delivery' && (
                                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                        <span style={{ color: '#3B82F6', fontStyle: 'italic', fontSize: '0.9em' }}>
                                            Rider is on the way...
                                        </span>
                                        <button 
                                            onClick={() => updateStatus(order.id, 'delivered')}
                                            style={{ 
                                                padding: '8px 16px', 
                                                background: '#10B981', 
                                                color: 'white', 
                                                border: 'none', 
                                                borderRadius: '4px', 
                                                cursor: 'pointer',
                                                fontWeight: 'bold'
                                            }}
                                        >
                                            Mark Delivered ✓
                                        </button>
                                    </div>
                                )}
                                
                                {order.status === 'delivered' && (
                                    <div style={{ color: 'var(--text-dim)', fontSize: '0.9em', fontStyle: 'italic', textAlign: 'center' }}>
                                        Order Completed Successfully
                                    </div>
                                )}
                            </div>
                        </div>
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
