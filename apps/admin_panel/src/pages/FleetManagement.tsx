import React, { useEffect, useState } from 'react';
import Sidebar from '../components/Sidebar';
import { supabase } from '../supabaseClient';
import { FaMotorcycle, FaPlus, FaTrash, FaTimes, FaEdit, FaUsersCog } from 'react-icons/fa';
import { motion, AnimatePresence } from 'framer-motion';
import api from '../api';

interface Rider {
  id: string;
  email?: string;
  full_name: string;
  phone_number?: string;
  must_change_password?: boolean;
  created_at: string;
}

const FleetManagement: React.FC = () => {
    const [riders, setRiders] = useState<Rider[]>([]);
    const [loading, setLoading] = useState(true);

    // Modal States
    const [showAddModal, setShowAddModal] = useState(false);
    const [showEditModal, setShowEditModal] = useState(false);
    const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);

    // Form States
    const [formId, setFormId] = useState('');
    const [formName, setFormName] = useState('');
    const [formEmail, setFormEmail] = useState('');
    const [formPhone, setFormPhone] = useState('');
    const [formPassword, setFormPassword] = useState('');
    
    const [formLoading, setFormLoading] = useState(false);
    const [formError, setFormError] = useState<string | null>(null);
    const [deleteLoading, setDeleteLoading] = useState(false);

    const fetchRiders = async () => {
        setLoading(true);
        try {
            const response = await api.get('/admin/riders/');
            setRiders(response.data);
        } catch (e) {
            console.error("Failed to fetch riders:", e);
        }
        setLoading(false);
    };

    useEffect(() => {
        fetchRiders();

        const handleKeyDown = (e: KeyboardEvent) => {
            if (e.key === 'Escape') {
                setShowAddModal(false);
                setShowEditModal(false);
                setDeleteConfirmId(null);
            }
        };
        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }, []);

    const handleCreateRider = async (e: React.FormEvent) => {
        e.preventDefault();
        setFormLoading(true);
        setFormError(null);
        try {
            await api.post('/admin/riders/', {
                full_name: formName,
                email: formEmail,
                password: formPassword,
                phone_number: formPhone,
            });
            setShowAddModal(false);
            setFormName(''); setFormEmail(''); setFormPassword(''); setFormPhone('');
            fetchRiders();
        } catch (err: any) {
            const detail = err?.response?.data?.detail || err.message || 'Failed to create rider';
            setFormError(typeof detail === 'string' ? detail : JSON.stringify(detail));
        }
        setFormLoading(false);
    };

    const handleUpdateRider = async (e: React.FormEvent) => {
        e.preventDefault();
        setFormLoading(true);
        setFormError(null);
        try {
            await api.put(`/admin/riders/${formId}`, {
                full_name: formName,
                phone_number: formPhone,
            });
            setShowEditModal(false);
            fetchRiders();
        } catch (err: any) {
            const detail = err?.response?.data?.detail || err.message || 'Failed to update rider';
            setFormError(typeof detail === 'string' ? detail : JSON.stringify(detail));
        }
        setFormLoading(false);
    };

    const handleDeleteRider = async (riderId: string) => {
        setDeleteLoading(true);
        try {
            await api.delete(`/admin/riders/${riderId}`);
            setDeleteConfirmId(null);
            fetchRiders();
        } catch (err: any) {
            alert('Failed to delete rider: ' + (err?.response?.data?.detail || err.message));
        }
        setDeleteLoading(false);
    };

    const openEditModal = (rider: Rider) => {
        setFormId(rider.id);
        setFormName(rider.full_name || '');
        setFormPhone(rider.phone_number || '');
        setFormError(null);
        setShowEditModal(true);
    };

    return (
        <div className="layout">
            <Sidebar />
            <div className="content" style={{ flexDirection: 'column', overflow: 'hidden' }}>
                {/* Header */}
                <div style={{ padding: '28px 32px 0', flexShrink: 0, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div>
                        <h1 style={{ margin: '0 0 4px', color: 'var(--text-primary)', fontSize: '1.8rem', display: 'flex', alignItems: 'center', gap: '12px' }}>
                            <FaUsersCog color="var(--accent-primary)" /> Fleet Management
                        </h1>
                        <p style={{ margin: '0 0 20px', color: 'var(--text-muted)', fontSize: '0.9em' }}>Manage your delivery riders</p>
                    </div>
                    <button
                        onClick={() => { 
                            setFormName(''); setFormEmail(''); setFormPassword(''); setFormPhone('');
                            setShowAddModal(true); setFormError(null); 
                        }}
                        style={{
                            display: 'flex', alignItems: 'center', gap: '8px',
                            background: 'var(--accent-primary)', color: '#0B0B0B',
                            border: 'none', borderRadius: '10px', padding: '10px 18px',
                            fontWeight: 700, cursor: 'pointer', fontSize: '0.95em',
                            transition: 'opacity 0.2s'
                        }}
                    >
                        <FaPlus size={14} /> Add New Rider
                    </button>
                </div>

                {/* Table */}
                <div style={{ flex: 1, overflowY: 'auto', padding: '16px 32px 32px' }}>
                    {loading ? (
                        <div style={{ display: 'flex', height: '200px', alignItems: 'center', justifyContent: 'center', color: 'var(--text-muted)' }}>Loading fleet...</div>
                    ) : (
                        <div style={{ background: 'var(--bg-surface)', borderRadius: '12px', border: '1px solid var(--border-color)', overflow: 'hidden' }}>
                            <motion.table
                                initial={{ opacity: 0 }} animate={{ opacity: 1 }}
                                style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.9em' }}
                            >
                                <thead>
                                    <tr>
                                        {['Rider Name', 'Email', 'Phone Number', 'Account Status', 'Joined Date', 'Actions'].map(h => (
                                            <th key={h} style={{ textAlign: 'left', padding: '16px', color: 'var(--text-muted)', fontWeight: 600, whiteSpace: 'nowrap', position: 'sticky', top: 0, background: 'var(--bg-surface-elevated)', zIndex: 1, borderBottom: '1px solid var(--border-color)' }}>{h}</th>
                                        ))}
                                    </tr>
                                </thead>
                                <tbody>
                                    {riders.length === 0 ? (
                                        <tr><td colSpan={5} style={{ textAlign: 'center', padding: '60px', color: 'var(--text-muted)' }}>No riders found.</td></tr>
                                    ) : riders.map((rider, i) => (
                                        <motion.tr
                                            key={rider.id}
                                            initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: Math.min(i * 0.02, 0.3) }}
                                            style={{ borderBottom: '1px solid var(--border-color)', transition: 'background 0.15s' }}
                                            onMouseEnter={e => (e.currentTarget.style.background = 'var(--bg-surface-elevated)')}
                                            onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
                                        >
                                            <td style={{ padding: '16px', color: 'var(--text-primary)', fontWeight: 600 }}>
                                                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                                                    <div style={{ width: '36px', height: '36px', borderRadius: '50%', background: 'var(--bg-surface-elevated)', border: '1px solid var(--border-color)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--accent-primary)', flexShrink: 0 }}>
                                                        <FaMotorcycle size={16} />
                                                    </div>
                                                    {rider.full_name || 'Rider'}
                                                </div>
                                            </td>
                                            <td style={{ padding: '16px', color: 'var(--text-muted)' }}>{rider.email || '—'}</td>
                                            <td style={{ padding: '16px', color: 'var(--text-muted)' }}>{rider.phone_number || '—'}</td>
                                            <td style={{ padding: '16px' }}>
                                                {rider.must_change_password ? (
                                                    <span style={{ fontSize: '0.8em', background: 'rgba(245,158,11,0.2)', color: '#f59e0b', borderRadius: '6px', padding: '4px 8px', fontWeight: 700 }}>Default Password</span>
                                                ) : (
                                                    <span style={{ fontSize: '0.8em', background: 'rgba(16,185,129,0.2)', color: '#10b981', borderRadius: '6px', padding: '4px 8px', fontWeight: 700 }}>Active</span>
                                                )}
                                            </td>
                                            <td style={{ padding: '16px', color: 'var(--text-muted)' }}>
                                                {new Date(rider.created_at).toLocaleDateString('en-IN')}
                                            </td>
                                            <td style={{ padding: '16px' }}>
                                                <div style={{ display: 'flex', gap: '12px' }}>
                                                    <button
                                                        onClick={() => openEditModal(rider)}
                                                        title="Edit Rider"
                                                        style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: 'var(--accent-primary)', padding: '4px', opacity: 0.8 }}
                                                    >
                                                        <FaEdit size={16} />
                                                    </button>
                                                    <button
                                                        onClick={() => setDeleteConfirmId(rider.id)}
                                                        title="Delete Rider"
                                                        style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: 'var(--danger, #ef4444)', padding: '4px', opacity: 0.8 }}
                                                    >
                                                        <FaTrash size={15} />
                                                    </button>
                                                </div>
                                            </td>
                                        </motion.tr>
                                    ))}
                                </tbody>
                            </motion.table>
                        </div>
                    )}
                </div>
            </div>

            {/* ===== Edit Rider Modal ===== */}
            <AnimatePresence>
                {showEditModal && (
                    <motion.div
                        initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
                        style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.75)', zIndex: 9999, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '20px' }}
                        onClick={() => setShowEditModal(false)}
                    >
                        <motion.div
                            initial={{ scale: 0.92, opacity: 0, y: 20 }} animate={{ scale: 1, opacity: 1, y: 0 }} exit={{ scale: 0.92, opacity: 0, y: 20 }}
                            onClick={(e) => e.stopPropagation()}
                            style={{ background: 'var(--bg-surface)', border: '1px solid var(--border-color)', borderRadius: '20px', padding: '36px', width: '460px', maxWidth: '100%', boxShadow: '0 24px 80px rgba(0,0,0,0.6)' }}
                        >
                            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '28px' }}>
                                <h2 style={{ margin: 0, color: 'var(--text-primary)', fontSize: '1.4rem', display: 'flex', alignItems: 'center', gap: '10px' }}>
                                    <FaEdit color="var(--accent-primary)" /> Edit Rider
                                </h2>
                                <button onClick={() => setShowEditModal(false)} style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: 'var(--text-muted)', padding: '4px' }}>
                                    <FaTimes size={18} />
                                </button>
                            </div>

                            <form onSubmit={handleUpdateRider} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                                {([
                                    { label: 'Full Name', value: formName, setter: setFormName, type: 'text', placeholder: 'e.g. Mohammed Ali' },
                                    { label: 'Phone Number', value: formPhone, setter: setFormPhone, type: 'tel', placeholder: '+91 9000000000' },
                                ] as const).map(({ label, value, setter, type, placeholder }) => (
                                    <div key={label}>
                                        <label style={{ display: 'block', fontSize: '0.85em', color: 'var(--text-muted)', marginBottom: '6px', fontWeight: 600 }}>{label}</label>
                                        <input
                                            type={type}
                                            value={value}
                                            onChange={(e) => (setter as any)(e.target.value)}
                                            placeholder={placeholder}
                                            required
                                            style={{ width: '100%', padding: '10px 14px', borderRadius: '8px', border: '1px solid var(--border-color)', background: 'var(--bg-surface-elevated)', color: 'var(--text-primary)', fontSize: '0.95em', boxSizing: 'border-box' }}
                                        />
                                    </div>
                                ))}

                                {formError && (
                                    <div style={{ background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.3)', color: '#ef4444', borderRadius: '8px', padding: '10px 14px', fontSize: '0.85em' }}>
                                        {formError}
                                    </div>
                                )}

                                <button
                                    type="submit"
                                    disabled={formLoading}
                                    style={{ marginTop: '12px', width: '100%', padding: '12px', background: 'var(--accent-primary)', color: '#0B0B0B', border: 'none', borderRadius: '10px', fontWeight: 700, fontSize: '1em', cursor: formLoading ? 'not-allowed' : 'pointer', opacity: formLoading ? 0.7 : 1 }}
                                >
                                    {formLoading ? 'Updating Rider...' : 'Update Rider'}
                                </button>
                            </form>
                        </motion.div>
                    </motion.div>
                )}
            </AnimatePresence>

            {/* ===== Add Rider Modal ===== */}
            <AnimatePresence>
                {showAddModal && (
                    <motion.div
                        initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
                        style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.75)', zIndex: 9999, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '20px' }}
                        onClick={() => setShowAddModal(false)}
                    >
                        <motion.div
                            initial={{ scale: 0.92, opacity: 0, y: 20 }} animate={{ scale: 1, opacity: 1, y: 0 }} exit={{ scale: 0.92, opacity: 0, y: 20 }}
                            onClick={(e) => e.stopPropagation()}
                            style={{ background: 'var(--bg-surface)', border: '1px solid var(--border-color)', borderRadius: '20px', padding: '36px', width: '460px', maxWidth: '100%', boxShadow: '0 24px 80px rgba(0,0,0,0.6)' }}
                        >
                            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '28px' }}>
                                <h2 style={{ margin: 0, color: 'var(--text-primary)', fontSize: '1.4rem', display: 'flex', alignItems: 'center', gap: '10px' }}>
                                    <FaMotorcycle color="var(--accent-primary)" /> Add New Rider
                                </h2>
                                <button onClick={() => setShowAddModal(false)} style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: 'var(--text-muted)', padding: '4px' }}>
                                    <FaTimes size={18} />
                                </button>
                            </div>

                            <form onSubmit={handleCreateRider} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                                {([
                                    { label: 'Full Name', value: formName, setter: setFormName, type: 'text', placeholder: 'e.g. Mohammed Ali' },
                                    { label: 'Email', value: formEmail, setter: setFormEmail, type: 'email', placeholder: 'rider@example.com' },
                                    { label: 'Phone Number', value: formPhone, setter: setFormPhone, type: 'tel', placeholder: '+91 9000000000' },
                                    { label: 'Initial Password', value: formPassword, setter: setFormPassword, type: 'password', placeholder: 'Minimum 8 characters' },
                                ] as const).map(({ label, value, setter, type, placeholder }) => (
                                    <div key={label}>
                                        <label style={{ display: 'block', fontSize: '0.85em', color: 'var(--text-muted)', marginBottom: '6px', fontWeight: 600 }}>{label}</label>
                                        <input
                                            type={type}
                                            value={value}
                                            onChange={(e) => (setter as any)(e.target.value)}
                                            placeholder={placeholder}
                                            required
                                            style={{ width: '100%', padding: '10px 14px', borderRadius: '8px', border: '1px solid var(--border-color)', background: 'var(--bg-surface-elevated)', color: 'var(--text-primary)', fontSize: '0.95em', boxSizing: 'border-box' }}
                                        />
                                    </div>
                                ))}

                                {formError && (
                                    <div style={{ background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.3)', color: '#ef4444', borderRadius: '8px', padding: '10px 14px', fontSize: '0.85em' }}>
                                        {formError}
                                    </div>
                                )}

                                <p style={{ margin: '0', fontSize: '0.8em', color: 'var(--text-muted)' }}>⚠️ The rider will be prompted to change their password on first login.</p>

                                <button
                                    type="submit"
                                    disabled={formLoading}
                                    style={{ marginTop: '4px', width: '100%', padding: '12px', background: 'var(--accent-primary)', color: '#0B0B0B', border: 'none', borderRadius: '10px', fontWeight: 700, fontSize: '1em', cursor: formLoading ? 'not-allowed' : 'pointer', opacity: formLoading ? 0.7 : 1 }}
                                >
                                    {formLoading ? 'Creating Rider...' : 'Create Rider Account'}
                                </button>
                            </form>
                        </motion.div>
                    </motion.div>
                )}
            </AnimatePresence>

            {/* ===== Delete Confirmation Dialog ===== */}
            <AnimatePresence>
                {deleteConfirmId && (
                    <motion.div
                        initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
                        style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', zIndex: 9998, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                        onClick={() => setDeleteConfirmId(null)}
                    >
                        <motion.div
                            initial={{ scale: 0.9, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.9, opacity: 0 }}
                            onClick={(e) => e.stopPropagation()}
                            style={{ background: 'var(--bg-surface)', border: '1px solid var(--border-color)', borderRadius: '16px', padding: '32px', width: '360px', textAlign: 'center', boxShadow: '0 20px 60px rgba(0,0,0,0.5)' }}
                        >
                            <div style={{ fontSize: '2.5rem', marginBottom: '16px' }}>⚠️</div>
                            <h3 style={{ color: 'var(--text-primary)', margin: '0 0 8px' }}>Delete Rider?</h3>
                            <p style={{ color: 'var(--text-muted)', fontSize: '0.9em', margin: '0 0 24px' }}>This will permanently delete the rider's account and all associated data. This cannot be undone.</p>
                            <div style={{ display: 'flex', gap: '12px', justifyContent: 'center' }}>
                                <button onClick={() => setDeleteConfirmId(null)} style={{ padding: '10px 24px', borderRadius: '8px', border: '1px solid var(--border-color)', background: 'transparent', color: 'var(--text-primary)', cursor: 'pointer', fontWeight: 600 }}>Cancel</button>
                                <button onClick={() => handleDeleteRider(deleteConfirmId)} disabled={deleteLoading} style={{ padding: '10px 24px', borderRadius: '8px', border: 'none', background: 'var(--danger, #ef4444)', color: 'white', cursor: 'pointer', fontWeight: 700 }}>
                                    {deleteLoading ? 'Deleting...' : 'Yes, Delete'}
                                </button>
                            </div>
                        </motion.div>
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    );
};

export default FleetManagement;
