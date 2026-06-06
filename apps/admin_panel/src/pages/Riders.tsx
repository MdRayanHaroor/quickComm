import React, { useEffect, useState } from 'react';
import Sidebar from '../components/Sidebar';
import LiveMap from '../components/LiveMap';
import StoreSettings from '../components/StoreSettings';
import { supabase } from '../supabaseClient';
import { FaMotorcycle, FaCircle } from 'react-icons/fa';
import { motion } from 'framer-motion';

interface Rider {
  id: string;
  full_name: string;
  phone_number?: string;
  must_change_password?: boolean;
}

const Riders: React.FC = () => {
    const [riders, setRiders] = useState<Rider[]>([]);
    const [riderLastUpdates, setRiderLastUpdates] = useState<Record<string, string>>({}); // Store ISO timestamps
    const [currentTime, setCurrentTime] = useState(new Date().getTime()); // Trigger re-render for time checks
    const [selectedRiderId, setSelectedRiderId] = useState<string | null>(null);
    const [riderStats, setRiderStats] = useState<Record<string, number>>({});
    
    // Store Location State (persisted in Supabase)
    const [storeLocation, setStoreLocation] = useState<{lat: number, lng: number} | undefined>(undefined);

    useEffect(() => {
        fetchRiders();
        fetchStoreLocation();
        
        // 1. Subscribe to LOCATION updates
        const locationChannel = supabase
            .channel('public:rider_locations:list') // Unique channel name
            .on('postgres_changes', { event: '*', schema: 'public', table: 'rider_locations' }, (payload: any) => {
                console.log("Rider Status Update:", payload);
                if (payload.new && payload.new.rider_id) {
                   setRiderLastUpdates(prev => ({
                       ...prev,
                       [payload.new.rider_id]: payload.new.last_updated || new Date().toISOString()
                   }));
                }
            })
            .subscribe();

        // 2. Subscribe to PROFILE updates (New Riders)
        const profilesChannel = supabase
            .channel('public:profiles')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles', filter: 'role=eq.rider' }, () => {
                fetchRiders(); // Reload list
            })
            .subscribe();
            
        // 3. Subscribe to STATS updates
        const statsChannel = supabase
            .channel('public:rider_daily_stats')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'rider_daily_stats' }, (payload: any) => {
                if (payload.new && payload.new.rider_id) {
                    setRiderStats(prev => ({
                        ...prev,
                        [payload.new.rider_id]: payload.new.online_minutes
                    }));
                }
            })
            .subscribe();

        // 4. Periodic "Offline" Check (every minute)
        const interval = setInterval(() => {
            setCurrentTime(new Date().getTime());
        }, 60000);

        return () => {
            supabase.removeChannel(locationChannel);
            supabase.removeChannel(profilesChannel);
            supabase.removeChannel(statsChannel);
            clearInterval(interval);
        }
    }, []);

    const fetchRiders = async () => {
        const today = new Date().toISOString().split('T')[0];
        
        const { data: profiles } = await supabase.from('profiles').select('*').eq('role', 'rider');
        const { data: locations } = await supabase.from('rider_locations').select('rider_id, last_updated');
        const { data: stats } = await supabase.from('rider_daily_stats').select('rider_id, online_minutes').eq('date', today);
        
        if (profiles) setRiders(profiles);
        
        // Build initial timestamp map
        const updates: Record<string, string> = {};
        if (locations) {
            locations.forEach((loc: any) => {
                updates[loc.rider_id] = loc.last_updated;
            });
        }
        setRiderLastUpdates(updates);
        
        // Build stats map
        const statsMap: Record<string, number> = {};
        if (stats) {
            stats.forEach((stat: any) => {
               statsMap[stat.rider_id] = stat.online_minutes;
            });
        }
        setRiderStats(statsMap);
    };

    const fetchStoreLocation = async () => {
        const { data, error } = await supabase.from('store_settings').select('lat, lng').eq('id', 1).single();
        if (data && !error) {
            setStoreLocation({ lat: data.lat, lng: data.lng });
        }
    };

    const handleStoreUpdate = async (lat: number, lng: number) => {
        const newLoc = { lat, lng };
        setStoreLocation(newLoc);
        // Upsert the location into Supabase
        await supabase.from('store_settings').upsert({ id: 1, lat, lng, updated_at: new Date().toISOString() });
    };
    
    const formatDuration = (minutes: number) => {
        const h = Math.floor(minutes / 60);
        const m = minutes % 60;
        return `${h}h ${m}m`;
    };

    return (
        <div className="layout">
            <Sidebar />
            <div className="content" style={{ padding: 0, display: 'flex' }}>
                
                {/* Rider List Sidebar */}
                <div style={{ width: '350px', borderRight: '1px solid var(--border-color)', padding: '0', backgroundColor: 'var(--bg-surface)', display: 'flex', flexDirection: 'column', zIndex: 5 }}>
                    
                    {/* Store Settings Section */}
                    <div style={{ borderBottom: '1px solid var(--border-color)' }}>
                      <StoreSettings 
                          onLocationSelect={handleStoreUpdate}
                          currentLocation={storeLocation || null}
                      />
                    </div>

                    <div style={{ padding: '24px', flex: 1, overflowY: 'auto' }}>
                        <div style={{ marginBottom: '20px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                            <h2 style={{ display: 'flex', alignItems: 'center', gap: '10px', color: 'var(--text-primary)', fontSize: '1.3rem', margin: 0 }}>
                                <FaMotorcycle color="var(--accent-primary)" /> Fleet
                            </h2>
                        </div>
                        
                        <button 
                            onClick={() => setSelectedRiderId(null)}
                            style={{
                                width: '100%', padding: '12px', marginBottom: '20px', 
                                background: selectedRiderId === null ? 'var(--accent-primary)' : 'var(--bg-surface-elevated)',
                                border: `1px solid ${selectedRiderId === null ? 'var(--accent-primary)' : 'var(--border-color)'}`,
                                color: selectedRiderId === null ? '#0B0B0B' : 'var(--text-primary)', 
                                cursor: 'pointer', borderRadius: '8px',
                                fontWeight: 600,
                                transition: 'all 0.3s ease'
                            }}
                        >
                            Show All Riders
                        </button>

                        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                            {riders.map((rider, idx) => {
                                const lastUpdate = riderLastUpdates[rider.id];
                                const minutes = riderStats[rider.id] || 0;
                                
                                let isOnline = false;
                                if (lastUpdate) {
                                    const diff = (currentTime - new Date(lastUpdate).getTime()) / 60000; // minutes
                                    isOnline = diff < 2;
                                }

                                return (
                                <motion.div 
                                    initial={{ opacity: 0, x: -10 }}
                                    animate={{ opacity: 1, x: 0 }}
                                    transition={{ delay: idx * 0.05 }}
                                    key={rider.id} 
                                    onClick={() => setSelectedRiderId(rider.id)}
                                    className="card" 
                                    style={{ 
                                        padding: '16px', 
                                        border: selectedRiderId === rider.id ? '2px solid var(--accent-primary)' : '1px solid var(--border-color)',
                                        cursor: 'pointer', 
                                        opacity: isOnline ? 1 : 0.6,
                                        boxShadow: selectedRiderId === rider.id ? '0 4px 12px rgba(212,175,55,0.15)' : 'none',
                                        transition: 'all 0.2s ease',
                                        marginBottom: 0
                                    }}
                                >
                                    <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '8px' }}>
                                        <div style={{ width: '45px', height: '45px', borderRadius: '50%', background: 'var(--bg-surface-elevated)', border: '1px solid var(--border-color)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--accent-primary)', flexShrink: 0 }}>
                                            <FaMotorcycle size={20} />
                                        </div>
                                        <div style={{ flex: 1, minWidth: 0 }}>
                                            <div style={{ fontWeight: '600', color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: '6px' }}>
                                                {rider.full_name || 'Rider'}
                                                {rider.must_change_password && <span style={{ fontSize: '0.7em', background: 'var(--warning, #f59e0b)', color: '#000', borderRadius: '4px', padding: '1px 5px', fontWeight: 700 }}>Default Pwd</span>}
                                            </div>
                                            <div style={{ fontSize: '0.8em', color: 'var(--text-muted)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{rider.phone_number || `ID: ${rider.id.split('-')[0]}...`}</div>
                                        </div>
                                    </div>
                                    
                                    <div style={{ marginTop: '12px', fontSize: '0.85em', color: 'var(--accent-primary)', fontWeight: '600' }}>
                                        Time Online: {formatDuration(minutes)}
                                    </div>

                                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '0.8em', marginTop: '6px', color: 'var(--text-primary)' }}>
                                        <FaCircle color={isOnline ? "var(--success)" : "var(--text-muted)"} size={10} /> 
                                        {isOnline ? "Online" : "Offline"}
                                        {lastUpdate && !isOnline && <span style={{color:'var(--text-muted)'}}> (Last seen: {new Date(lastUpdate).toLocaleTimeString()})</span>}
                                    </div>
                                </motion.div>
                                )})}
                        </div>
                    </div>
                </div>

                {/* Map Area */}
                <div style={{ flex: 1, position: 'relative' }}>
                    {storeLocation ? (
                        <LiveMap 
                            storeLocation={storeLocation}
                            onStoreLocationUpdate={handleStoreUpdate}
                            selectedRiderId={selectedRiderId} // Pass selection
                            onMapClick={() => setSelectedRiderId(null)} // Deselect rider on map click
                        />
                    ) : (
                        <div style={{ 
                            display: 'flex', 
                            height: '100%', 
                            alignItems: 'center', 
                            justifyContent: 'center', 
                            color: 'var(--text-muted)',
                            background: 'var(--bg-surface)' 
                        }}>
                            Loading map...
                        </div>
                    )}
                    <div style={{ 
                        position: 'absolute', 
                        top: 20, 
                        right: 20, 
                        background: 'var(--bg-surface)', 
                        padding: '12px 20px', 
                        borderRadius: '12px',
                        zIndex: 1000,
                        border: '1px solid var(--border-color)',
                        boxShadow: 'var(--shadow-md)',
                        backdropFilter: 'blur(10px)'
                    }}>
                        <h3 style={{ margin: 0, fontSize: '1.1em', color: 'var(--accent-primary)' }}>Live Tracking</h3>
                        <p style={{ margin: '5px 0 0', fontSize: '0.85em', color: 'var(--text-muted)' }}>Real-time updates via Supabase</p>
                    </div>
                </div>

            </div>
        </div>
    );
};

export default Riders;
