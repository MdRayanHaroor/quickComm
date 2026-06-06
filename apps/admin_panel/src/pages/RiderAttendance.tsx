import React, { useEffect, useState } from 'react';
import Sidebar from '../components/Sidebar';
import { supabase } from '../supabaseClient';
import { FaCalendarAlt, FaDownload } from 'react-icons/fa';
import { motion } from 'framer-motion';

interface Rider {
    id: string;
    full_name: string;
    phone_number?: string;
}

interface DailyStatRow {
    rider_id: string;
    date: string;
    online_minutes: number;
}

const formatDuration = (minutes: number) => {
    if (!minutes) return '—';
    const h = Math.floor(minutes / 60);
    const m = minutes % 60;
    return `${h}h ${m}m`;
};

const getDaysArray = (numDays: number) => {
    const days: string[] = [];
    for (let i = 0; i < numDays; i++) {
        const d = new Date();
        d.setDate(d.getDate() - i);
        days.push(d.toISOString().split('T')[0]);
    }
    return days;
};

const RiderAttendance: React.FC = () => {
    const [riders, setRiders] = useState<Rider[]>([]);
    const [stats, setStats] = useState<DailyStatRow[]>([]);
    const [loading, setLoading] = useState(true);
    const [range, setRange] = useState<number>(7);
    const [days, setDays] = useState<string[]>([]);

    useEffect(() => {
        const newDays = getDaysArray(range);
        setDays(newDays);
        
        const fetchData = async () => {
            setLoading(true);
            const [{ data: riderData }, { data: statsData }] = await Promise.all([
                supabase.from('profiles').select('id, full_name, phone_number').eq('role', 'rider'),
                supabase.from('rider_daily_stats').select('rider_id, date, online_minutes').in('date', newDays),
            ]);
            if (riderData) setRiders(riderData);
            if (statsData) setStats(statsData);
            setLoading(false);
        };
        fetchData();
    }, [range]);

    const getMinutes = (riderId: string, date: string) => {
        const row = stats.find(s => s.rider_id === riderId && s.date === date);
        return row ? row.online_minutes : 0;
    };

    const handleDownloadCSV = () => {
        const header = ['Rider Name', 'Phone', ...days].join(',');
        const rows = riders.map(r =>
            [r.full_name, r.phone_number || '', ...days.map(d => getMinutes(r.id, d))].join(',')
        );
        const csv = [header, ...rows].join('\n');
        const blob = new Blob([csv], { type: 'text/csv' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `rider-attendance-${new Date().toISOString().split('T')[0]}.csv`;
        a.click();
        URL.revokeObjectURL(url);
    };

    return (
        <div className="layout">
            <Sidebar />
            <div className="content" style={{ flexDirection: 'column', overflow: 'hidden' }}>
                {/* Header */}
                <div style={{ padding: '28px 32px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexShrink: 0 }}>
                    <div>
                        <h1 style={{ margin: 0, color: 'var(--text-primary)', fontSize: '1.8rem', display: 'flex', alignItems: 'center', gap: '12px' }}>
                            <FaCalendarAlt color="var(--accent-primary)" /> Rider Attendance
                        </h1>
                        <p style={{ margin: '6px 0 0', color: 'var(--text-muted)', fontSize: '0.9em' }}>Online hours per rider for the selected period</p>
                    </div>
                    <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
                        <select
                            value={range}
                            onChange={(e) => setRange(Number(e.target.value))}
                            style={{ padding: '8px 12px', borderRadius: '10px', border: '1px solid var(--border-color)', background: 'var(--bg-surface-elevated)', color: 'var(--text-primary)', fontSize: '0.9em', cursor: 'pointer', fontWeight: 600 }}
                        >
                            <option value={1}>Today</option>
                            <option value={7}>Last 7 Days</option>
                            <option value={14}>Last 14 Days</option>
                            <option value={30}>Last 30 Days</option>
                        </select>
                        <button
                            onClick={handleDownloadCSV}
                            style={{ display: 'flex', alignItems: 'center', whiteSpace: 'nowrap', gap: '8px', padding: '8px 12px', background: 'var(--accent-primary)', color: '#0B0B0B', border: 'none', borderRadius: '10px', fontWeight: 700, cursor: 'pointer', fontSize: '0.9em' }}
                        >
                            <FaDownload size={14} /> Export CSV
                        </button>
                    </div>
                </div>

                {/* Table */}
                <div style={{ flex: 1, padding: '24px 32px 32px', display: 'flex', flexDirection: 'column', minHeight: 0 }}>
                    {loading ? (
                        <div style={{ display: 'flex', height: '200px', alignItems: 'center', justifyContent: 'center', color: 'var(--text-muted)' }}>Loading attendance data...</div>
                    ) : (
                        <div style={{ flex: 1, overflow: 'auto', background: 'var(--bg-surface)', borderRadius: '12px', border: '1px solid var(--border-color)' }}>
                            <motion.table
                                initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }}
                                style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.85em', minWidth: '900px' }}
                            >
                                <thead>
                                    <tr>
                                        <th style={{ textAlign: 'left', padding: '12px 16px', background: 'var(--bg-surface-elevated)', color: 'var(--text-muted)', fontWeight: 600, borderBottom: '1px solid var(--border-color)', position: 'sticky', left: 0, top: 0, zIndex: 3, minWidth: '160px' }}>Rider</th>
                                        {days.map(d => (
                                            <th key={d} style={{ padding: '12px 10px', background: 'var(--bg-surface-elevated)', color: 'var(--text-muted)', fontWeight: 600, borderBottom: '1px solid var(--border-color)', whiteSpace: 'nowrap', textAlign: 'center', position: 'sticky', top: 0, zIndex: 2, minWidth: '80px' }}>
                                                {new Date(d + 'T00:00:00').toLocaleDateString('en-IN', { day: '2-digit', month: 'short' })}
                                            </th>
                                        ))}
                                    </tr>
                                </thead>
                                <tbody>
                                    {riders.length === 0 ? (
                                        <tr><td colSpan={days.length + 1} style={{ textAlign: 'center', padding: '40px', color: 'var(--text-muted)' }}>No riders found.</td></tr>
                                    ) : riders.map((rider, i) => (
                                        <motion.tr
                                            key={rider.id}
                                            initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: i * 0.04 }}
                                            style={{ borderBottom: '1px solid var(--border-color)' }}
                                        >
                                            <td style={{ padding: '12px 16px', position: 'sticky', left: 0, background: 'var(--bg-surface)', zIndex: 1 }}>
                                                <div style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{rider.full_name}</div>
                                                {rider.phone_number && <div style={{ fontSize: '0.85em', color: 'var(--text-muted)' }}>{rider.phone_number}</div>}
                                            </td>
                                            {days.map(d => {
                                                const mins = getMinutes(rider.id, d);
                                                return (
                                                    <td key={d} style={{ padding: '12px 10px', textAlign: 'center', color: mins > 0 ? 'var(--success, #10b981)' : 'var(--text-muted)', fontWeight: mins > 0 ? 600 : 400 }}>
                                                        {formatDuration(mins)}
                                                    </td>
                                                );
                                            })}
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

export default RiderAttendance;
