import React, { useState } from 'react';
import axios from 'axios';
import { FaStore, FaSearch, FaMapMarkerAlt } from 'react-icons/fa';

interface StoreSettingsProps {
    onLocationSelect: (lat: number, lng: number) => void;
    currentLocation: { lat: number; lng: number } | null;
}

const StoreSettings: React.FC<StoreSettingsProps> = ({ onLocationSelect, currentLocation }) => {
    const [query, setQuery] = useState('');
    const [loading, setLoading] = useState(false);
    const [results, setResults] = useState<any[]>([]);
    const debounceRef = React.useRef<any>(null);

    const searchAddress = async (searchQuery: string) => {
        if (!searchQuery) {
            setResults([]);
            return;
        }
        setLoading(true);
        try {
            // Added accept-language=en to force English results, restricted to India (in)
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
        }, 500); // 500ms debounce
    };

    const handleSelect = (result: any) => {
        const lat = parseFloat(result.lat);
        const lng = parseFloat(result.lon);
        onLocationSelect(lat, lng);
        setResults([]); // Clear results
        setQuery(result.display_name.split(',')[0]); // Sane display text
    };

    return (
        <div style={{ padding: '15px', background: '#1f2937', color: 'white', borderBottom: '1px solid #374151' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '10px' }}>
                <FaStore className="text-blue-400" />
                <h3 style={{ margin: 0, fontSize: '1rem' }}>Store Location</h3>
            </div>
            
            <div style={{ display: 'flex', gap: '5px' }}>
                <input 
                    type="text" 
                    value={query} 
                    onChange={handleInput}
                    placeholder="Search area (e.g. Kammanhalli)"
                    style={{ 
                        flex: 1, 
                        padding: '8px', 
                        borderRadius: '4px', 
                        border: '1px solid #4b5563', 
                        background: '#374151', 
                        color: 'white' 
                    }}
                />
                <button 
                    onClick={() => searchAddress(query)}
                    disabled={loading}
                    style={{ 
                        padding: '8px 12px', 
                        background: '#3b82f6', 
                        border: 'none', 
                        borderRadius: '4px', 
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
                    background: '#374151', 
                    borderRadius: '4px', 
                    maxHeight: '150px', 
                    overflowY: 'auto'
                }}>
                    {results.map((res: any) => (
                        <li 
                            key={res.place_id} 
                            onClick={() => handleSelect(res)}
                            style={{ 
                                padding: '8px', 
                                borderBottom: '1px solid #4b5563', 
                                cursor: 'pointer',
                                fontSize: '0.9em'
                            }}
                            className="hover:bg-gray-600"
                        >
                            {res.display_name}
                        </li>
                    ))}
                </ul>
            )}

            {currentLocation && (
                <div style={{ marginTop: '10px', fontSize: '0.8em', color: '#9ca3af' }}>
                    <FaMapMarkerAlt style={{ display: 'inline', marginRight: '5px' }} />
                    Current: {currentLocation.lat.toFixed(4)}, {currentLocation.lng.toFixed(4)}
                </div>
            )}
            
            <p style={{ fontSize: '0.75em', color: '#6b7280', marginTop: '5px' }}>
                * Tip: You can also drag the store marker on the map.
            </p>
        </div>
    );
};

export default StoreSettings;
