import React, { useEffect, useState } from 'react';
import Sidebar from '../components/Sidebar';
import LiveMap from '../components/LiveMap';
import StoreSettings from '../components/StoreSettings';
import { supabase } from '../supabaseClient';
import { FaMotorcycle, FaCircle } from 'react-icons/fa';

interface Rider {
  id: string;
  full_name: string;
}

const Riders: React.FC = () => {
    const [riders, setRiders] = useState<Rider[]>([]);
    const [riderLastUpdates, setRiderLastUpdates] = useState<Record<string, string>>({}); // Store ISO timestamps
    const [currentTime, setCurrentTime] = useState(new Date().getTime()); // Trigger re-render for time checks
    const [selectedRiderId, setSelectedRiderId] = useState<string | null>(null);
    
    // Store Location State (persisted in local storage for now)
    const [storeLocation, setStoreLocation] = useState<{lat: number, lng: number} | undefined>(() => {
        const saved = localStorage.getItem('store_location');
        return saved ? JSON.parse(saved) : undefined;
    });

    useEffect(() => {
        fetchRiders();
        
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

        // 3. Periodic "Offline" Check (every minute)
        const interval = setInterval(() => {
            setCurrentTime(new Date().getTime());
        }, 60000);

        return () => {
            supabase.removeChannel(locationChannel);
            supabase.removeChannel(profilesChannel);
            clearInterval(interval);
        }
    }, []);

    const fetchRiders = async () => {
        const { data: profiles } = await supabase.from('profiles').select('*').eq('role', 'rider');
        const { data: locations } = await supabase.from('rider_locations').select('rider_id, last_updated');
        
        if (profiles) setRiders(profiles);
        
        // Build initial timestamp map
        const updates: Record<string, string> = {};
        if (locations) {
            locations.forEach((loc: any) => {
                updates[loc.rider_id] = loc.last_updated;
            });
        }
        setRiderLastUpdates(updates);
    };

    const handleStoreUpdate = (lat: number, lng: number) => {
        const newLoc = { lat, lng };
        setStoreLocation(newLoc);
        localStorage.setItem('store_location', JSON.stringify(newLoc));
    };

    return (
        <div className="layout">
            <Sidebar />
            <div className="content" style={{ padding: 0, display: 'flex' }}>
                
                {/* Rider List Sidebar */}
                <div style={{ width: '300px', borderRight: '1px solid #374151', padding: '0', backgroundColor: 'var(--bg-card)', display: 'flex', flexDirection: 'column' }}>
                    
                    {/* Store Settings Section */}
                    <StoreSettings 
                        onLocationSelect={handleStoreUpdate}
                        currentLocation={storeLocation || null}
                    />

                    <div style={{ padding: '20px', flex: 1, overflowY: 'auto' }}>
                        <h2 style={{ marginBottom: '20px', display: 'flex', alignItems: 'center', gap: '10px' }}>
                            <FaMotorcycle /> Fleet
                        </h2>
                        <div style={{ overflowY: 'auto' }}>
                            <button 
                                onClick={() => setSelectedRiderId(null)}
                                style={{
                                    width: '100%', padding: '10px', marginBottom: '10px', 
                                    background: selectedRiderId === null ? 'var(--primary)' : 'transparent',
                                    border: '1px solid #374151', color: 'white', cursor: 'pointer', borderRadius: '4px'
                                }}
                            >
                                Show All Riders
                            </button>

                            {riders.map(rider => {
                                const lastUpdate = riderLastUpdates[rider.id];
                                let isOnline = false;
                                if (lastUpdate) {
                                    const diff = (currentTime - new Date(lastUpdate).getTime()) / 60000; // minutes
                                    isOnline = diff < 10;
                                }

                                return (
                                <div 
                                    key={rider.id} 
                                    onClick={() => setSelectedRiderId(rider.id)}
                                    className="card" 
                                    style={{ 
                                        marginBottom: '10px', padding: '15px', border: selectedRiderId === rider.id ? '2px solid var(--primary)' : '1px solid #374151',
                                        cursor: 'pointer', opacity: isOnline ? 1 : 0.6
                                    }}
                                >
                                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '5px' }}>
                                        <div style={{ width: '40px', height: '40px', borderRadius: '50%', background: '#374151', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                                            <FaMotorcycle />
                                        </div>
                                        <div>
                                            <div style={{ fontWeight: 'bold' }}>{rider.full_name || 'Rider'}</div>
                                            <div style={{ fontSize: '0.8em', color: 'var(--text-dim)' }}>ID: {rider.id.split('-')[0]}...</div>
                                        </div>
                                    </div>
                                    <div style={{ display: 'flex', alignItems: 'center', gap: '5px', fontSize: '0.8em', marginTop: '5px' }}>
                                        <FaCircle color={isOnline ? "var(--primary)" : "grey"} size={10} /> 
                                        {isOnline ? "Online" : "Offline"}
                                        {lastUpdate && !isOnline && <span style={{color:'grey'}}> (Last seen: {new Date(lastUpdate).toLocaleTimeString()})</span>}
                                    </div>
                                </div>
                            )})}
                        </div>
                    </div>
                </div>

                {/* Map Area */}
                <div style={{ flex: 1, position: 'relative' }}>
                    <LiveMap 
                        storeLocation={storeLocation}
                        onStoreLocationUpdate={handleStoreUpdate}
                        selectedRiderId={selectedRiderId} // Pass selection
                    />
                    <div style={{ 
                        position: 'absolute', 
                        top: 20, 
                        right: 20, 
                        background: 'rgba(0,0,0,0.8)', 
                        padding: '10px 15px', 
                        borderRadius: '8px',
                        zIndex: 1000,
                        border: '1px solid #374151'
                    }}>
                        <h3 style={{ margin: 0, fontSize: '1em' }}>Live Tracking</h3>
                        <p style={{ margin: '5px 0 0', fontSize: '0.8em', color: 'var(--text-dim)' }}>Real-time updates via Supabase</p>
                    </div>
                </div>

            </div>
        </div>
    );
};

export default Riders;
