import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { FaStore, FaSearch, FaMapMarkerAlt, FaSlidersH, FaCheck } from 'react-icons/fa';
import { supabase } from '../supabaseClient';
import { toast } from 'react-hot-toast';
import { motion, AnimatePresence } from 'framer-motion';

interface StoreSettingsProps {
    onLocationSelect: (lat: number, lng: number) => void;
    currentLocation: { lat: number; lng: number } | null;
}

const StoreSettings: React.FC<StoreSettingsProps> = ({ onLocationSelect, currentLocation }) => {
    const [query, setQuery] = useState('');
    const [loading, setLoading] = useState(false);
    const [results, setResults] = useState<any[]>([]);
    const debounceRef = React.useRef<any>(null);

    // Extended delivery settings state
    const [showConfig, setShowConfig] = useState(false);
    const [storeName, setStoreName] = useState('QuickComm Store');
    const [deliveryRadius, setDeliveryRadius] = useState('5');
    const [minOrder, setMinOrder] = useState('99');
    const [deliveryFee, setDeliveryFee] = useState('20');
    const [freeDeliveryAbove, setFreeDeliveryAbove] = useState('299');
    const [isOpen, setIsOpen] = useState(true);
    const [savingConfig, setSavingConfig] = useState(false);

    useEffect(() => {
        const loadSettings = async () => {
            const { data } = await supabase.from('store_settings').select('*').eq('id', 1).maybeSingle();
            if (data) {
                if (data.store_name) setStoreName(data.store_name);
                if (data.delivery_radius_km != null) setDeliveryRadius(String(data.delivery_radius_km));
                if (data.min_order_amount != null) setMinOrder(String(data.min_order_amount));
                if (data.delivery_fee_fixed != null) setDeliveryFee(String(data.delivery_fee_fixed));
                if (data.free_delivery_above != null) setFreeDeliveryAbove(String(data.free_delivery_above));
                if (data.is_open != null) setIsOpen(Boolean(data.is_open));
            }
        };
        loadSettings();
    }, []);

    // Escape key closes modal
    useEffect(() => {
        const handleKeyDown = (e: KeyboardEvent) => {
            if (e.key === 'Escape') setShowConfig(false);
        };
        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }, []);

    const searchAddress = async (searchQuery: string) => {
        if (!searchQuery) {
            setResults([]);
            return;
        }
        setLoading(true);
        try {
            const response = await axios.get(`https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(searchQuery)}&accept-language=en&countrycodes=in`);
            setResults(response.data);
        } catch (error) {
            console.error("Search failed", error);
        } finally {
            setLoading(false);
        }
    };

    const handleInput = (e: React.ChangeEvent<HTMLInputElement>) => {
        const val = e.target.value;
        setQuery(val);
        
        if (debounceRef.current) clearTimeout(debounceRef.current);
        
        debounceRef.current = setTimeout(() => {
            searchAddress(val);
        }, 500);
    };

    const handleSelect = (result: any) => {
        const lat = parseFloat(result.lat);
        const lng = parseFloat(result.lon);
        onLocationSelect(lat, lng);
        setResults([]);
        setQuery(result.display_name.split(',')[0]);
    };

    const handleSaveConfig = async () => {
        setSavingConfig(true);
        try {
            const { error } = await supabase.from('store_settings').update({
                store_name: storeName,
                delivery_radius_km: parseFloat(deliveryRadius) || 5,
                min_order_amount: parseFloat(minOrder) || 99,
                delivery_fee_fixed: parseFloat(deliveryFee) || 20,
                free_delivery_above: parseFloat(freeDeliveryAbove) || 299,
                is_open: isOpen
            }).eq('id', 1);
            if (error) throw error;
            toast.success('Store delivery settings updated!');
            setShowConfig(false);
        } catch (e: any) {
            toast.error(e.message || 'Failed to update settings');
        } finally {
            setSavingConfig(false);
        }
    };

    return (
        <div style={{ padding: '16px', background: 'var(--bg-surface)', color: 'var(--text-primary)', borderBottom: '1px solid var(--border)' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '10px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <FaStore style={{ color: 'var(--brand-primary)' }} />
                    <h3 style={{ margin: 0, fontSize: '0.98rem', color: 'var(--text-primary)' }}>Store &amp; Delivery</h3>
                </div>
                <button
                    onClick={() => setShowConfig(true)}
                    className="btn btn-ghost"
                    style={{ padding: '4px 8px', fontSize: '0.78em', display: 'flex', alignItems: 'center', gap: '4px' }}
                    title="Configure Delivery Rules"
                >
                    <FaSlidersH size={11} /> Config
                </button>
            </div>
            
            <div style={{ display: 'flex', gap: '6px' }}>
                <input 
                    type="text" 
                    value={query} 
                    onChange={handleInput}
                    placeholder="Search store area (e.g. Indiranagar)"
                    style={{ 
                        flex: 1, 
                        padding: '8px 12px', 
                        borderRadius: 'var(--radius-sm)', 
                        border: '1px solid var(--border)', 
                        background: 'var(--bg-input)', 
                        color: 'var(--text-primary)' 
                    }}
                />
                <button 
                    onClick={() => searchAddress(query)}
                    disabled={loading}
                    style={{ 
                        padding: '8px 12px', 
                        background: 'var(--brand-primary)', 
                        border: 'none', 
                        borderRadius: 'var(--radius-sm)', 
                        color: 'white',
                        cursor: 'pointer'
                    }}
                >
                    <FaSearch />
                </button>
            </div>

            {results.length > 0 && (
                <ul style={{ 
                    listStyle: 'none', 
                    padding: 0, 
                    margin: '10px 0 0', 
                    background: 'var(--bg-surface-elevated)', 
                    border: '1px solid var(--border)',
                    borderRadius: 'var(--radius-sm)', 
                    maxHeight: '150px', 
                    overflowY: 'auto'
                }}>
                    {results.map((res: any) => (
                        <li 
                            key={res.place_id} 
                            onClick={() => handleSelect(res)}
                            style={{ 
                                padding: '8px 12px', 
                                borderBottom: '1px solid var(--border)', 
                                cursor: 'pointer',
                                fontSize: '0.9em',
                                color: 'var(--text-primary)'
                            }}
                            onMouseEnter={e => (e.currentTarget.style.background = 'var(--brand-light)')}
                            onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
                        >
                            {res.display_name}
                        </li>
                    ))}
                </ul>
            )}

            {currentLocation && (
                <div style={{ marginTop: '10px', fontSize: '0.8em', color: 'var(--text-muted)' }}>
                    <FaMapMarkerAlt style={{ display: 'inline', marginRight: '5px', color: 'var(--brand-primary)' }} />
                    Current: {currentLocation.lat.toFixed(4)}, {currentLocation.lng.toFixed(4)}
                </div>
            )}
            
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: '10px', fontSize: '0.78em', color: 'var(--text-muted)' }}>
                <span>Delivery: <strong>{deliveryRadius} km</strong> &bull; Min: <strong>₹{minOrder}</strong></span>
                <span style={{ color: isOpen ? 'var(--success)' : 'var(--danger)', fontWeight: 600 }}>
                    {isOpen ? '● Open' : '● Closed'}
                </span>
            </div>

            {/* Delivery Config Modal */}
            <AnimatePresence>
                {showConfig && (
                    <div className="modal-overlay" onClick={() => setShowConfig(false)}>
                        <motion.div
                            className="modal-dialog"
                            initial={{ scale: 0.95, opacity: 0 }}
                            animate={{ scale: 1, opacity: 1 }}
                            exit={{ scale: 0.95, opacity: 0 }}
                            transition={{ duration: 0.15 }}
                            onClick={e => e.stopPropagation()}
                            style={{ maxWidth: 440 }}
                        >
                            <div className="drawer-header">
                                <h2>Store Delivery Settings</h2>
                            </div>

                            <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 14 }}>
                                <div className="form-group">
                                    <label className="form-label required">Store Name</label>
                                    <input
                                        value={storeName}
                                        onChange={e => setStoreName(e.target.value)}
                                        placeholder="QuickComm Supermarket"
                                    />
                                </div>

                                <div className="grid-2">
                                    <div className="form-group">
                                        <label className="form-label required">Delivery Radius (km)</label>
                                        <input
                                            type="number"
                                            value={deliveryRadius}
                                            onChange={e => setDeliveryRadius(e.target.value)}
                                            min={1}
                                            max={50}
                                        />
                                    </div>
                                    <div className="form-group">
                                        <label className="form-label required">Min Order (₹)</label>
                                        <input
                                            type="number"
                                            value={minOrder}
                                            onChange={e => setMinOrder(e.target.value)}
                                            min={0}
                                        />
                                    </div>
                                </div>

                                <div className="grid-2">
                                    <div className="form-group">
                                        <label className="form-label required">Standard Delivery Fee (₹)</label>
                                        <input
                                            type="number"
                                            value={deliveryFee}
                                            onChange={e => setDeliveryFee(e.target.value)}
                                            min={0}
                                        />
                                    </div>
                                    <div className="form-group">
                                        <label className="form-label required">Free Delivery Above (₹)</label>
                                        <input
                                            type="number"
                                            value={freeDeliveryAbove}
                                            onChange={e => setFreeDeliveryAbove(e.target.value)}
                                            min={0}
                                        />
                                    </div>
                                </div>

                                {/* Payment Gateway Placeholder (Decision #5) */}
                                <div style={{
                                    background: 'var(--bg-surface-elevated)',
                                    border: '1px solid var(--border)',
                                    borderRadius: 'var(--radius-md)',
                                    padding: '14px 16px',
                                    marginTop: 4
                                }}>
                                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 6 }}>
                                        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                                            <strong style={{ fontSize: 13, color: 'var(--text-primary)' }}>Payment Gateway (Razorpay)</strong>
                                            <span style={{
                                                background: 'rgba(59, 130, 246, 0.15)',
                                                color: '#3b82f6',
                                                borderRadius: 10,
                                                padding: '1px 8px',
                                                fontSize: 10,
                                                fontWeight: 700
                                            }}>
                                                Coming Soon
                                            </span>
                                        </div>
                                        <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>UPI &bull; Cards &bull; Netbanking</span>
                                    </div>
                                    <p style={{ margin: 0, fontSize: 12, color: 'var(--text-secondary)' }}>
                                        Online payments via Razorpay webhook integration will be activated with the Customer App release (Phase 5). Cash on Delivery is currently active for all orders.
                                    </p>
                                </div>

                                <div className="form-group">
                                    <label className="form-label">Store Operational Status</label>
                                    <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 4 }}>
                                        <label className="toggle">
                                            <input
                                                type="checkbox"
                                                checked={isOpen}
                                                onChange={e => setIsOpen(e.target.checked)}
                                            />
                                            <span className="toggle-slider" />
                                        </label>
                                        <span style={{ fontSize: 13, color: isOpen ? 'var(--success)' : 'var(--danger)', fontWeight: 600 }}>
                                            {isOpen ? 'Store is Open for Orders' : 'Store is Temporarily Closed'}
                                        </span>
                                    </div>
                                </div>
                            </div>

                            <div className="drawer-footer">
                                <button className="btn btn-ghost" onClick={() => setShowConfig(false)}>Cancel</button>
                                <button className="btn btn-primary" onClick={handleSaveConfig} disabled={savingConfig}>
                                    <FaCheck size={12} /> {savingConfig ? 'Saving...' : 'Save Settings'}
                                </button>
                            </div>
                        </motion.div>
                    </div>
                )}
            </AnimatePresence>
        </div>
    );
};

export default StoreSettings;
