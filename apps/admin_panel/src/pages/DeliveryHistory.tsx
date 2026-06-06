import React, { useEffect, useState } from 'react';
import Sidebar from '../components/Sidebar';
import { supabase } from '../supabaseClient';
import { FaClipboardList, FaFilter } from 'react-icons/fa';
import { motion } from 'framer-motion';

interface Order {
    id: number;
    user_id: string;
    rider_id: string | null;
    status: string;
    total_amount: number;
    delivery_address: string;
    created_at: string;
    updated_at: string;
    rider_name?: string;
}

interface Rider {
    id: string;
    full_name: string;
}

const STATUS_COLORS: Record<string, string> = {
    delivered: '#10b981',
    cancelled: '#ef4444',
    out_for_delivery: '#3b82f6',
    preparing: '#f59e0b',
    confirmed: '#8b5cf6',
    pending: '#6b7280',
};

const DeliveryHistory: React.FC = () => {
    const [orders, setOrders] = useState<Order[]>([]);
    const [riders, setRiders] = useState<Rider[]>([]);
    const [loading, setLoading] = useState(true);
    const [filterRider, setFilterRider] = useState<string>('all');
    const [filterStatus, setFilterStatus] = useState<string>('all');
    const [filterStartDate, setFilterStartDate] = useState<string>('');
    const [filterEndDate, setFilterEndDate] = useState<string>('');

    const fetchData = async () => {
        setLoading(true);
        const [{ data: riderData }, { data: orderData }] = await Promise.all([
            supabase.from('profiles').select('id, full_name').eq('role', 'rider'),
            supabase.from('orders')
                .select('*')
                .order('created_at', { ascending: false })
                .limit(200),
        ]);

        if (riderData) setRiders(riderData);

        if (orderData && riderData) {
            const riderMap = Object.fromEntries(riderData.map((r: Rider) => [r.id, r.full_name]));
            setOrders(orderData.map((o: Order) => ({
                ...o,
                rider_name: o.rider_id ? (riderMap[o.rider_id] || 'Unknown') : '—',
            })));
        }
        setLoading(false);
    };

    useEffect(() => { fetchData(); }, []);

    const filteredOrders = orders.filter(o => {
        if (filterRider !== 'all' && o.rider_id !== filterRider) return false;
        if (filterStatus !== 'all' && o.status !== filterStatus) return false;
        
        const orderDate = o.created_at.split('T')[0];
        
        if (filterStartDate && filterEndDate) {
            // Range selected
            if (orderDate < filterStartDate || orderDate > filterEndDate) return false;
        } else if (filterStartDate && !filterEndDate) {
            // Only start selected -> show only that day
            if (orderDate !== filterStartDate) return false;
        } else if (!filterStartDate && filterEndDate) {
            // Only end selected -> show up to that day
            if (orderDate > filterEndDate) return false;
        }
        
        return true;
    });

    return (
        <div className="layout">
            <Sidebar />
            <div className="content" style={{ flexDirection: 'column', overflow: 'hidden' }}>
                {/* Header */}
                <div style={{ padding: '28px 32px 0', flexShrink: 0 }}>
                    <h1 style={{ margin: '0 0 4px', color: 'var(--text-primary)', fontSize: '1.8rem', display: 'flex', alignItems: 'center', gap: '12px' }}>
                        <FaClipboardList color="var(--accent-primary)" /> Delivery History
                    </h1>
                    <p style={{ margin: '0 0 20px', color: 'var(--text-muted)', fontSize: '0.9em' }}>All orders across all riders</p>

                    {/* Filters */}
                    <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap', alignItems: 'center', marginBottom: '4px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: 'var(--text-muted)', fontSize: '0.85em' }}>
                            <FaFilter size={12} /> Filters:
                        </div>
                        <select
                            value={filterRider}
                            onChange={e => setFilterRider(e.target.value)}
                            style={{ padding: '8px 12px', borderRadius: '8px', border: '1px solid var(--border-color)', background: 'var(--bg-surface-elevated)', color: 'var(--text-primary)', fontSize: '0.85em', cursor: 'pointer' }}
                        >
                            <option value="all">All Riders</option>
                            {riders.map(r => <option key={r.id} value={r.id}>{r.full_name}</option>)}
                        </select>
                        <select
                            value={filterStatus}
                            onChange={e => setFilterStatus(e.target.value)}
                            style={{ padding: '8px 12px', borderRadius: '8px', border: '1px solid var(--border-color)', background: 'var(--bg-surface-elevated)', color: 'var(--text-primary)', fontSize: '0.85em', cursor: 'pointer' }}
                        >
                            <option value="all">All Statuses</option>
                            {['pending', 'confirmed', 'preparing', 'out_for_delivery', 'delivered', 'cancelled'].map(s => (
                                <option key={s} value={s}>{s.replace(/_/g, ' ')}</option>
                            ))}
                        </select>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                            <input
                                type="date"
                                value={filterStartDate}
                                onChange={e => setFilterStartDate(e.target.value)}
                                style={{ padding: '7px 12px', borderRadius: '8px', border: '1px solid var(--border-color)', background: 'var(--bg-surface-elevated)', color: 'var(--text-primary)', fontSize: '0.85em', cursor: 'pointer' }}
                            />
                            <span style={{ color: 'var(--text-muted)' }}>-</span>
                            <input
                                type="date"
                                value={filterEndDate}
                                onChange={e => setFilterEndDate(e.target.value)}
                                style={{ padding: '7px 12px', borderRadius: '8px', border: '1px solid var(--border-color)', background: 'var(--bg-surface-elevated)', color: 'var(--text-primary)', fontSize: '0.85em', cursor: 'pointer' }}
                            />
                        </div>
                        {(filterRider !== 'all' || filterStatus !== 'all' || filterStartDate || filterEndDate) && (
                            <button onClick={() => { setFilterRider('all'); setFilterStatus('all'); setFilterStartDate(''); setFilterEndDate(''); }} style={{ padding: '7px 14px', borderRadius: '8px', border: '1px solid var(--border-color)', background: 'transparent', color: 'var(--text-muted)', fontSize: '0.85em', cursor: 'pointer' }}>Clear</button>
                        )}
                        <span style={{ marginLeft: 'auto', color: 'var(--text-muted)', fontSize: '0.85em' }}>{filteredOrders.length} orders</span>
                    </div>
                </div>

                {/* Table */}
                <div style={{ flex: 1, overflowY: 'auto', padding: '0 32px 32px' }}>
                    {loading ? (
                        <div style={{ display: 'flex', height: '200px', alignItems: 'center', justifyContent: 'center', color: 'var(--text-muted)' }}>Loading orders...</div>
                    ) : (
                        <div style={{ background: 'var(--bg-surface)', borderRadius: '12px', border: '1px solid var(--border-color)', overflow: 'hidden' }}>
                            <motion.table
                                initial={{ opacity: 0 }} animate={{ opacity: 1 }}
                                style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.88em' }}
                            >
                                <thead>
                                    <tr>
                                        {['Order ID', 'Rider', 'Delivery Address', 'Amount', 'Status', 'Date'].map(h => (
                                            <th key={h} style={{ textAlign: 'left', padding: '12px 14px', color: 'var(--text-muted)', fontWeight: 600, whiteSpace: 'nowrap', position: 'sticky', top: 0, background: 'var(--bg-surface-elevated)', zIndex: 1, borderBottom: '1px solid var(--border-color)' }}>{h}</th>
                                        ))}
                                    </tr>
                                </thead>
                            <tbody>
                                {filteredOrders.length === 0 ? (
                                    <tr><td colSpan={6} style={{ textAlign: 'center', padding: '60px', color: 'var(--text-muted)' }}>No orders match the current filters.</td></tr>
                                ) : filteredOrders.map((order, i) => (
                                    <motion.tr
                                        key={order.id}
                                        initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: Math.min(i * 0.02, 0.3) }}
                                        style={{ borderBottom: '1px solid var(--border-color)', transition: 'background 0.15s' }}
                                        onMouseEnter={e => (e.currentTarget.style.background = 'var(--bg-surface-elevated)')}
                                        onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
                                    >
                                        <td style={{ padding: '12px 14px', fontWeight: 600, color: 'var(--accent-primary)' }}>#{order.id}</td>
                                        <td style={{ padding: '12px 14px', color: 'var(--text-primary)' }}>{order.rider_name}</td>
                                        <td style={{ padding: '12px 14px', color: 'var(--text-muted)', maxWidth: '220px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }} title={order.delivery_address}>{order.delivery_address}</td>
                                        <td style={{ padding: '12px 14px', color: 'var(--text-primary)', fontWeight: 600 }}>₹{order.total_amount}</td>
                                        <td style={{ padding: '12px 14px' }}>
                                            <span style={{
                                                display: 'inline-block', padding: '3px 10px', borderRadius: '20px',
                                                background: `${STATUS_COLORS[order.status] || '#6b7280'}22`,
                                                color: STATUS_COLORS[order.status] || '#6b7280',
                                                fontWeight: 600, fontSize: '0.8em', textTransform: 'capitalize'
                                            }}>
                                                {order.status.replace(/_/g, ' ')}
                                            </span>
                                        </td>
                                        <td style={{ padding: '12px 14px', color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>
                                            {new Date(order.created_at).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })}
                                            <span style={{ marginLeft: '6px', fontSize: '0.85em' }}>{new Date(order.created_at).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })}</span>
                                        </td>
                                    </motion.tr>
                                ))}
                                </tbody>
                            </motion.table>
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
};

export default DeliveryHistory;
