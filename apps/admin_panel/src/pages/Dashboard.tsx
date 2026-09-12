import React, { useEffect, useState, useCallback, useMemo } from 'react';
import Sidebar from '../components/Sidebar';
import { supabase } from '../supabaseClient';
import api from '../api';
import { useNavigate } from 'react-router-dom';
import {
  ResponsiveContainer,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid
} from 'recharts';
import {
  FaShoppingBag, FaBoxes, FaExclamationTriangle, FaTimesCircle,
  FaRupeeSign, FaSyncAlt, FaArrowRight, FaClock, FaCheckCircle,
  FaMotorcycle, FaPlus, FaWarehouse
} from 'react-icons/fa';

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

interface InventorySummary {
  total_variants: number;
  out_of_stock: number;
  low_stock: number;
  healthy_stock: number;
}

const Dashboard: React.FC = () => {
    const [orders, setOrders] = useState<Order[]>([]);
    const [invSummary, setInvSummary] = useState<InventorySummary | null>(null);
    const [activeRidersCount, setActiveRidersCount] = useState<number>(0);
    const [loading, setLoading] = useState(true);
    const navigate = useNavigate();

    const fetchDashboardData = useCallback(async () => {
        setLoading(true);
        try {
            const [ordersRes, invRes, ridersRes] = await Promise.all([
                supabase
                    .from('orders')
                    .select(`
                        id, status, total_amount, delivery_address, created_at,
                        order_items ( id, quantity, price:price_at_time, product:products ( name ) )
                    `)
                    .order('created_at', { ascending: false })
                    .limit(20),
                api.get('/inventory/summary').catch(() => null),
                supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('role', 'rider')
            ]);

            if (ordersRes.data) setOrders(ordersRes.data as any);
            if (invRes?.data) setInvSummary(invRes.data);
            if (ridersRes && ridersRes.count != null) setActiveRidersCount(ridersRes.count);
        } catch (error) {
            console.error("Error fetching dashboard data:", error);
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => {
        const checkUser = async () => {
            const { data: { session } } = await supabase.auth.getSession();
            if (!session) {
                navigate('/');
            }
        };
        checkUser();
        fetchDashboardData();

        // Realtime Subscription on orders
        const channel = supabase
            .channel('public:orders:dashboard')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, () => {
                fetchDashboardData(); 
            })
            .subscribe();

        return () => {
            supabase.removeChannel(channel);
        };
    }, [navigate, fetchDashboardData]);

    const totalGMV = orders
        .filter(o => o.status !== 'cancelled')
        .reduce((sum, o) => sum + (Number(o.total_amount) || 0), 0);

    const pendingCount = orders.filter(o => o.status === 'pending').length;
    const preparingCount = orders.filter(o => o.status === 'confirmed').length;
    const onRoadCount = orders.filter(o => o.status === 'out_for_delivery').length;
    const deliveredCount = orders.filter(o => o.status === 'delivered').length;

    // Last 7 days trend chart data
    const chartData = useMemo(() => {
        const daysMap: Record<string, { date: string; sales: number; orders: number }> = {};
        const now = new Date();
        for (let i = 6; i >= 0; i--) {
            const d = new Date(now);
            d.setDate(d.getDate() - i);
            const key = d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
            daysMap[key] = { date: key, sales: 0, orders: 0 };
        }
        orders.forEach(o => {
            if (o.created_at) {
                const d = new Date(o.created_at);
                const key = d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
                if (daysMap[key]) {
                    if (o.status !== 'cancelled') {
                        daysMap[key].sales += Number(o.total_amount || 0);
                    }
                    daysMap[key].orders += 1;
                }
            }
        });
        return Object.values(daysMap);
    }, [orders]);

    const getStatusBadge = (status: string) => {
        switch (status) {
            case 'delivered':
                return <span className="badge badge-success">Delivered</span>;
            case 'out_for_delivery':
                return <span className="badge badge-info">On the way</span>;
            case 'confirmed':
                return <span className="badge badge-warning">Preparing</span>;
            case 'cancelled':
                return <span className="badge badge-danger">Cancelled</span>;
            default:
                return <span className="badge badge-primary">New Order</span>;
        }
    };

    return (
        <div className="layout">
            <Sidebar />
            <div className="main-content" style={{ display: 'flex', flexDirection: 'column', height: '100vh', overflow: 'hidden' }}>
                {/* Page Header */}
                <div className="page-header" style={{ flexShrink: 0 }}>
                    <div>
                        <h1 className="page-title">Supermarket Dashboard</h1>
                        <p style={{ color: 'var(--text-muted)', fontSize: 13, marginTop: 2 }}>
                            Key performance indicators, catalog inventory health, and recent operations
                        </p>
                    </div>
                    <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
                        <button
                            onClick={() => navigate('/orders')}
                            className="btn btn-primary"
                            style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '0.88em' }}
                        >
                            <FaShoppingBag /> Live Orders ({pendingCount + preparingCount + onRoadCount})
                        </button>
                        <button
                            onClick={fetchDashboardData}
                            className="btn btn-ghost"
                            style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '0.88em' }}
                            title="Refresh Dashboard"
                        >
                            <FaSyncAlt className={loading ? 'animate-spin' : ''} />
                        </button>
                    </div>
                </div>

                <div className="page-body" style={{ flex: 1, overflowY: 'auto', padding: '24px 32px 32px' }}>
                    {/* Primary KPI Metrics Grid - Vertically Stacked Cards */}
                    <div style={{
                        display: 'grid',
                        gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
                        gap: 16,
                        marginBottom: 24
                    }}>
                        {/* 1. Total Sales / GMV */}
                        <div style={{
                            background: 'var(--bg-surface)',
                            border: '1px solid var(--border)',
                            borderRadius: 'var(--radius-lg)',
                            padding: '18px 20px',
                            display: 'flex',
                            flexDirection: 'column',
                            justifyContent: 'space-between',
                            minHeight: 125,
                            boxShadow: 'var(--shadow-sm)'
                        }}>
                            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
                                <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-secondary)' }}>Total Sales / GMV</span>
                                <div style={{ width: 34, height: 34, borderRadius: 8, display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--brand-light)', color: 'var(--brand-primary)', fontSize: 15, flexShrink: 0 }}>
                                    <FaRupeeSign />
                                </div>
                            </div>
                            <div>
                                <div style={{ fontSize: 26, fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.15 }}>
                                    ₹{totalGMV.toLocaleString('en-IN')}
                                </div>
                                <div style={{ fontSize: 12, color: 'var(--text-muted)', marginTop: 6 }}>
                                    from active orders
                                </div>
                            </div>
                        </div>

                        {/* 2. Total Orders */}
                        <div
                            onClick={() => navigate('/orders')}
                            className="card-hover"
                            style={{
                                background: 'var(--bg-surface)',
                                border: '1px solid var(--border)',
                                borderRadius: 'var(--radius-lg)',
                                padding: '18px 20px',
                                display: 'flex',
                                flexDirection: 'column',
                                justifyContent: 'space-between',
                                minHeight: 125,
                                boxShadow: 'var(--shadow-sm)',
                                cursor: 'pointer'
                            }}
                        >
                            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
                                <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-secondary)' }}>Total Orders</span>
                                <div style={{ width: 34, height: 34, borderRadius: 8, display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'rgba(59, 130, 246, 0.15)', color: '#3b82f6', fontSize: 15, flexShrink: 0 }}>
                                    <FaShoppingBag />
                                </div>
                            </div>
                            <div>
                                <div style={{ fontSize: 26, fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.15 }}>
                                    {orders.length}
                                </div>
                                <div style={{ fontSize: 12, color: 'var(--brand-primary)', marginTop: 6, fontWeight: 600 }}>
                                    View order pipeline &rarr;
                                </div>
                            </div>
                        </div>

                        {/* 3. Active Catalog SKUs */}
                        <div
                            onClick={() => navigate('/inventory')}
                            className="card-hover"
                            style={{
                                background: 'var(--bg-surface)',
                                border: '1px solid var(--border)',
                                borderRadius: 'var(--radius-lg)',
                                padding: '18px 20px',
                                display: 'flex',
                                flexDirection: 'column',
                                justifyContent: 'space-between',
                                minHeight: 125,
                                boxShadow: 'var(--shadow-sm)',
                                cursor: 'pointer'
                            }}
                        >
                            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
                                <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-secondary)' }}>Active Catalog SKUs</span>
                                <div style={{ width: 34, height: 34, borderRadius: 8, display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'rgba(168, 85, 247, 0.15)', color: '#a855f7', fontSize: 15, flexShrink: 0 }}>
                                    <FaBoxes />
                                </div>
                            </div>
                            <div>
                                <div style={{ fontSize: 26, fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.15 }}>
                                    {invSummary?.total_variants ?? '—'}
                                </div>
                                <div style={{ fontSize: 12, color: 'var(--brand-primary)', marginTop: 6, fontWeight: 600 }}>
                                    Manage inventory &rarr;
                                </div>
                            </div>
                        </div>

                        {/* 4. Low Stock SKUs */}
                        <div
                            onClick={() => navigate('/inventory')}
                            className="card-hover"
                            style={{
                                background: 'var(--bg-surface)',
                                border: '1px solid var(--border)',
                                borderRadius: 'var(--radius-lg)',
                                padding: '18px 20px',
                                display: 'flex',
                                flexDirection: 'column',
                                justifyContent: 'space-between',
                                minHeight: 125,
                                boxShadow: 'var(--shadow-sm)',
                                cursor: 'pointer'
                            }}
                        >
                            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
                                <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-secondary)' }}>Low Stock SKUs</span>
                                <div style={{ width: 34, height: 34, borderRadius: 8, display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'rgba(234, 179, 8, 0.15)', color: '#eab308', fontSize: 15, flexShrink: 0 }}>
                                    <FaExclamationTriangle />
                                </div>
                            </div>
                            <div>
                                <div style={{ fontSize: 26, fontWeight: 800, color: (invSummary?.low_stock ?? 0) > 0 ? '#eab308' : 'var(--text-primary)', lineHeight: 1.15 }}>
                                    {invSummary?.low_stock ?? 0}
                                </div>
                                <div style={{ fontSize: 12, color: 'var(--text-muted)', marginTop: 6 }}>
                                    near alert threshold
                                </div>
                            </div>
                        </div>

                        {/* 5. Out of Stock */}
                        <div
                            onClick={() => navigate('/inventory')}
                            className="card-hover"
                            style={{
                                background: 'var(--bg-surface)',
                                border: '1px solid var(--border)',
                                borderRadius: 'var(--radius-lg)',
                                padding: '18px 20px',
                                display: 'flex',
                                flexDirection: 'column',
                                justifyContent: 'space-between',
                                minHeight: 125,
                                boxShadow: 'var(--shadow-sm)',
                                cursor: 'pointer'
                            }}
                        >
                            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
                                <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-secondary)' }}>Out of Stock</span>
                                <div style={{ width: 34, height: 34, borderRadius: 8, display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'rgba(239, 68, 68, 0.15)', color: 'var(--danger)', fontSize: 15, flexShrink: 0 }}>
                                    <FaTimesCircle />
                                </div>
                            </div>
                            <div>
                                <div style={{ fontSize: 26, fontWeight: 800, color: (invSummary?.out_of_stock ?? 0) > 0 ? 'var(--danger)' : 'var(--text-primary)', lineHeight: 1.15 }}>
                                    {invSummary?.out_of_stock ?? 0}
                                </div>
                                <div style={{ fontSize: 12, color: 'var(--text-muted)', marginTop: 6 }}>
                                    needs reordering
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Sales & Orders Activity Trend Chart */}
                    <div style={{
                        background: 'var(--bg-surface)',
                        border: '1px solid var(--border)',
                        borderRadius: 'var(--radius-lg)',
                        padding: '20px 24px',
                        marginBottom: 24,
                        boxShadow: 'var(--shadow-sm)'
                    }}>
                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16, flexWrap: 'wrap', gap: 10 }}>
                            <div>
                                <h3 style={{ margin: 0, fontSize: 15, fontWeight: 700, color: 'var(--text-primary)' }}>Sales Activity Trend</h3>
                                <p style={{ margin: '2px 0 0', fontSize: 12, color: 'var(--text-muted)' }}>Daily Gross Merchandise Value over the last 7 days</p>
                            </div>
                            <div style={{ display: 'flex', gap: 16, fontSize: 12 }}>
                                <span style={{ display: 'flex', alignItems: 'center', gap: 6, color: 'var(--brand-primary)', fontWeight: 600 }}>
                                    <span style={{ width: 10, height: 10, borderRadius: 2, background: 'var(--brand-primary)' }} /> Sales (₹)
                                </span>
                            </div>
                        </div>

                        <div style={{ width: '100%', height: 210 }}>
                            <ResponsiveContainer width="100%" height="100%">
                                <AreaChart data={chartData} margin={{ top: 10, right: 10, left: -15, bottom: 0 }}>
                                    <defs>
                                        <linearGradient id="salesTrendGrad" x1="0" y1="0" x2="0" y2="1">
                                            <stop offset="5%" stopColor="var(--brand-primary)" stopOpacity={0.35}/>
                                            <stop offset="95%" stopColor="var(--brand-primary)" stopOpacity={0}/>
                                        </linearGradient>
                                    </defs>
                                    <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" vertical={false} />
                                    <XAxis dataKey="date" stroke="var(--text-muted)" fontSize={11} tickLine={false} />
                                    <YAxis stroke="var(--text-muted)" fontSize={11} tickLine={false} />
                                    <Tooltip
                                        contentStyle={{
                                            background: 'var(--bg-surface)',
                                            border: '1px solid var(--border)',
                                            borderRadius: 8,
                                            fontSize: 12,
                                            boxShadow: '0 4px 12px rgba(0,0,0,0.1)'
                                        }}
                                        formatter={(val: any) => [`₹${Number(val).toLocaleString('en-IN')}`, 'Sales']}
                                    />
                                    <Area
                                        type="monotone"
                                        dataKey="sales"
                                        stroke="var(--brand-primary)"
                                        strokeWidth={2.5}
                                        fillOpacity={1}
                                        fill="url(#salesTrendGrad)"
                                    />
                                </AreaChart>
                            </ResponsiveContainer>
                        </div>
                    </div>

                    {/* Quick Live Orders Banner */}
                    <div style={{
                        background: 'linear-gradient(135deg, rgba(27, 166, 114, 0.1) 0%, rgba(59, 130, 246, 0.08) 100%)',
                        border: '1px solid var(--border)',
                        borderRadius: 'var(--radius-lg)',
                        padding: '18px 24px',
                        marginBottom: 24,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        flexWrap: 'wrap',
                        gap: 16
                    }}>
                        <div>
                            <div style={{ fontWeight: 800, color: 'var(--text-primary)', fontSize: '1.05rem', display: 'flex', alignItems: 'center', gap: 8 }}>
                                <FaClock color="var(--brand-primary)" /> Live Orders Status
                            </div>
                            <div style={{ fontSize: '0.88em', color: 'var(--text-secondary)', marginTop: 4, display: 'flex', gap: 16, flexWrap: 'wrap' }}>
                                <span>New Orders: <strong style={{ color: 'var(--brand-primary)' }}>{pendingCount}</strong></span>
                                <span>Preparing: <strong style={{ color: '#ca8a04' }}>{preparingCount}</strong></span>
                                <span>Out for Delivery: <strong style={{ color: 'var(--info)' }}>{onRoadCount}</strong></span>
                                <span>Completed Today: <strong style={{ color: 'var(--success)' }}>{deliveredCount}</strong></span>
                            </div>
                        </div>
                        <button
                            onClick={() => navigate('/orders')}
                            className="btn btn-primary"
                            style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 18px' }}
                        >
                            Open Orders Page <FaArrowRight size={12} />
                        </button>
                    </div>

                    {/* Two-Column Grid: Recent Orders & Quick Shortcuts */}
                    <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 20 }}>
                        {/* Recent Orders List */}
                        <div className="card" style={{ padding: '20px 24px' }}>
                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
                                <h3 style={{ margin: 0, fontSize: '1.05rem', color: 'var(--text-primary)' }}>
                                    Recent Orders
                                </h3>
                                <button
                                    onClick={() => navigate('/orders')}
                                    className="btn btn-ghost"
                                    style={{ padding: '4px 8px', fontSize: '0.82em', color: 'var(--brand-primary)' }}
                                >
                                    View All &rarr;
                                </button>
                            </div>

                            {orders.length === 0 ? (
                                <div style={{ color: 'var(--text-muted)', fontSize: '0.88em', textAlign: 'center', padding: '30px 0' }}>
                                    No recent orders
                                </div>
                            ) : (
                                <div style={{ overflowX: 'auto' }}>
                                    <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.85em' }}>
                                        <thead>
                                            <tr style={{ borderBottom: '1px solid var(--border)', color: 'var(--text-muted)' }}>
                                                <th style={{ textAlign: 'left', padding: '8px 12px' }}>Order</th>
                                                <th style={{ textAlign: 'left', padding: '8px 12px' }}>Customer Address</th>
                                                <th style={{ textAlign: 'right', padding: '8px 12px' }}>Amount</th>
                                                <th style={{ textAlign: 'center', padding: '8px 12px' }}>Status</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            {orders.slice(0, 7).map(order => (
                                                <tr
                                                    key={order.id}
                                                    onClick={() => navigate('/orders')}
                                                    style={{ borderBottom: '1px solid var(--border)', cursor: 'pointer' }}
                                                    className="table-row-hover"
                                                >
                                                    <td style={{ padding: '10px 12px', fontWeight: 700, color: 'var(--text-primary)' }}>
                                                        #{order.id}
                                                    </td>
                                                    <td style={{ padding: '10px 12px', color: 'var(--text-secondary)', maxWidth: 220, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                                                        {order.delivery_address || '—'}
                                                    </td>
                                                    <td style={{ padding: '10px 12px', textAlign: 'right', fontWeight: 700, color: 'var(--text-primary)' }}>
                                                        ₹{order.total_amount}
                                                    </td>
                                                    <td style={{ padding: '10px 12px', textAlign: 'center' }}>
                                                        {getStatusBadge(order.status)}
                                                    </td>
                                                </tr>
                                            ))}
                                        </tbody>
                                    </table>
                                </div>
                            )}
                        </div>

                        {/* Quick Shortcuts & Fleet Status */}
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                            {/* Inventory Health Widget */}
                            <div className="card" style={{ padding: '20px 24px' }}>
                                <h3 style={{ margin: '0 0 14px', fontSize: '1.05rem', color: 'var(--text-primary)' }}>
                                    Inventory Health
                                </h3>
                                <div style={{ display: 'flex', flexDirection: 'column', gap: 10, fontSize: '0.88em' }}>
                                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                        <span style={{ color: 'var(--text-secondary)', display: 'flex', alignItems: 'center', gap: 6 }}>
                                            <FaCheckCircle color="var(--success)" size={12} /> Healthy Stock
                                        </span>
                                        <strong style={{ color: 'var(--text-primary)' }}>{invSummary?.healthy_stock ?? 0} SKUs</strong>
                                    </div>
                                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                        <span style={{ color: 'var(--text-secondary)', display: 'flex', alignItems: 'center', gap: 6 }}>
                                            <FaExclamationTriangle color="#ca8a04" size={12} /> Low Stock Alert
                                        </span>
                                        <strong style={{ color: '#ca8a04' }}>{invSummary?.low_stock ?? 0} SKUs</strong>
                                    </div>
                                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                        <span style={{ color: 'var(--text-secondary)', display: 'flex', alignItems: 'center', gap: 6 }}>
                                            <FaTimesCircle color="var(--danger)" size={12} /> Out of Stock
                                        </span>
                                        <strong style={{ color: 'var(--danger)' }}>{invSummary?.out_of_stock ?? 0} SKUs</strong>
                                    </div>
                                </div>
                                <button
                                    onClick={() => navigate('/inventory')}
                                    className="btn btn-ghost"
                                    style={{ width: '100%', marginTop: 14, fontSize: '0.85em', justifyContent: 'center' }}
                                >
                                    <FaWarehouse /> Manage Stock
                                </button>
                            </div>

                            {/* Quick Action Shortcuts */}
                            <div className="card" style={{ padding: '20px 24px' }}>
                                <h3 style={{ margin: '0 0 14px', fontSize: '1.05rem', color: 'var(--text-primary)' }}>
                                    Quick Shortcuts
                                </h3>
                                <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                                    <button
                                        onClick={() => navigate('/products')}
                                        className="btn btn-ghost"
                                        style={{ justifyContent: 'flex-start', fontSize: '0.85em', gap: 8 }}
                                    >
                                        <FaPlus size={11} /> Add / Edit Products
                                    </button>
                                    <button
                                        onClick={() => navigate('/riders')}
                                        className="btn btn-ghost"
                                        style={{ justifyContent: 'flex-start', fontSize: '0.85em', gap: 8 }}
                                    >
                                        <FaMotorcycle size={12} /> Live Delivery Map ({activeRidersCount} Riders)
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default Dashboard;
