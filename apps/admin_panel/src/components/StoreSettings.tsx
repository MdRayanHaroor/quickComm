import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Link } from 'react-router-dom';
import { FaStore, FaSearch, FaMapMarkerAlt, FaCog } from 'react-icons/fa';
import { supabase } from '../supabaseClient';

interface StoreSettingsProps {
    onLocationSelect: (lat: number, lng: number) => void;
    currentLocation: { lat: number; lng: number } | null;
}

const StoreSettings: React.FC<StoreSettingsProps> = ({ onLocationSelect, currentLocation }) => {
    const [query, setQuery] = useState('');
    const [loading, setLoading] = useState(false);
    const [results, setResults] = useState<any[]>([]);
    const debounceRef = React.useRef<any>(null);

    // Live display values
    const [deliveryRadius, setDeliveryRadius] = useState('5');
    const [minOrder, setMinOrder] = useState('99');
    const [isOpen, setIsOpen] = useState(true);

    useEffect(() => {
        const loadSettings = async () => {
            const { data } = await supabase.from('store_settings').select('*').eq('id', 1).maybeSingle();
            if (data) {
                if (data.delivery_radius_km != null) setDeliveryRadius(String(data.delivery_radius_km));
                if (data.min_order_amount != null) setMinOrder(String(data.min_order_amount));
                if (data.is_open != null) setIsOpen(Boolean(data.is_open));
            }
        };
        loadSettings();
    }, []);

    const searchAddress = async (searchQuery: string) => {
        if (!searchQuery) {
            setResults([]);
            return;
        }
        setLoading(true);
        try {
            const response = await axios.get(
                `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(searchQuery)}&accept-language=en&countrycodes=in`
            );
            setResults(response.data || []);
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

    return (
        <div style={{ padding: '16px', background: 'var(--bg-surface)', color: 'var(--text-primary)', borderBottom: '1px solid var(--border)' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '10px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <FaStore style={{ color: 'var(--brand-primary)' }} />
                    <h3 style={{ margin: 0, fontSize: '0.98rem', color: 'var(--text-primary)' }}>Store &amp; Delivery</h3>
                </div>
                <Link
                    to="/settings"
                    className="btn btn-ghost"
                    style={{ padding: '4px 8px', fontSize: '0.78em', display: 'flex', alignItems: 'center', gap: '5px', textDecoration: 'none' }}
                    title="Open Full Store Settings & Payment Gateway"
                >
                    <FaCog size={11} /> Settings &rarr;
                </Link>
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
        </div>
    );
};

export default StoreSettings;
