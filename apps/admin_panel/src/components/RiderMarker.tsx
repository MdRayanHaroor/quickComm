import React, { useEffect, useRef, useState } from 'react';
import { Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import { FaMotorcycle } from 'react-icons/fa';
import { renderToStaticMarkup } from 'react-dom/server';

interface RiderMarkerProps {
    id: string;
    position: { lat: number; lng: number };
    previousPosition?: { lat: number; lng: number };
}

const RiderMarker: React.FC<RiderMarkerProps> = ({ id, position, previousPosition }) => {
    const [currentPos, setCurrentPos] = useState(position);
    const [bearing, setBearing] = useState(0);
    const requestRef = useRef<number>(0);
    const startTimeRef = useRef<number>(0);
    const startPosRef = useRef(position);
    const targetPosRef = useRef(position);

    // Calculate bearing between two points
    const calculateBearing = (startLat: number, startLng: number, destLat: number, destLng: number) => {
        const startLatRad = (startLat * Math.PI) / 180;
        const startLngRad = (startLng * Math.PI) / 180;
        const destLatRad = (destLat * Math.PI) / 180;
        const destLngRad = (destLng * Math.PI) / 180;

        const y = Math.sin(destLngRad - startLngRad) * Math.cos(destLatRad);
        const x = Math.cos(startLatRad) * Math.sin(destLatRad) -
            Math.sin(startLatRad) * Math.cos(destLatRad) * Math.cos(destLngRad - startLngRad);
        
        const brng = (Math.atan2(y, x) * 180) / Math.PI;
        return (brng + 360) % 360;
    };

    useEffect(() => {
        // If we have a previous position and it's different, start animation
        if (previousPosition && (previousPosition.lat !== position.lat || previousPosition.lng !== position.lng)) {
            startPosRef.current = currentPos; // Start from where we currently are (in case of mid-animation updates)
            targetPosRef.current = position;
            startTimeRef.current = performance.now();
            
            // Calculate new heading
            const newBearing = calculateBearing(
                startPosRef.current.lat, 
                startPosRef.current.lng, 
                position.lat, 
                position.lng
            );
            setBearing(newBearing);

            cancelAnimationFrame(requestRef.current!);
            requestRef.current = requestAnimationFrame(animate);
        } else {
            // Initial render or no change
            setCurrentPos(position);
        }

        return () => cancelAnimationFrame(requestRef.current!);
    }, [position]);

    const animate = (time: number) => {
        if (!startTimeRef.current) return;
        
        const duration = 3000; // 3 seconds
        const elapsed = time - startTimeRef.current;
        const progress = Math.min(elapsed / duration, 1);

        // Ease function (optional, using linear for now for constant speed, or ease-out)
        // const ease = 1 - Math.pow(1 - progress, 3); // Cubic ease out
        const ease = progress;

        const newLat = startPosRef.current.lat + (targetPosRef.current.lat - startPosRef.current.lat) * ease;
        const newLng = startPosRef.current.lng + (targetPosRef.current.lng - startPosRef.current.lng) * ease;

        setCurrentPos({ lat: newLat, lng: newLng });

        if (progress < 1) {
            requestRef.current = requestAnimationFrame(animate);
        }
    };

    // Create custom icon with rotation
    const iconHtml = renderToStaticMarkup(
        <div className="rider-marker-container" style={{ transform: `rotate(${bearing}deg)` }}>
            <div className="rider-halo"></div>
            <div className="rider-icon-inner">
                <FaMotorcycle size={24} color="#10B981" /> 
            </div>
            <div className="rider-pointer"></div>
        </div>
    );

    const customIcon = L.divIcon({
        html: iconHtml,
        className: 'custom-rider-icon',
        iconSize: [40, 40],
        iconAnchor: [20, 20], // Center it
    });

    return (
        <Marker position={[currentPos.lat, currentPos.lng]} icon={customIcon}>
             <Popup>
                <div style={{ color: 'black' }}>
                    <strong>Rider:</strong> {id}<br/>
                    <span style={{fontSize: '0.8em'}}>Bearing: {Math.round(bearing)}°</span>
                    <hr style={{margin: '5px 0', borderColor: '#eee'}} />
                    <a 
                        href={`https://www.google.com/maps/search/?api=1&query=${currentPos.lat},${currentPos.lng}`} 
                        target="_blank" 
                        rel="noopener noreferrer"
                        style={{fontSize: '0.8em', color: '#3b82f6', textDecoration: 'none'}}
                    >
                        Open in Google Maps ↗
                    </a>
                </div>
            </Popup>
        </Marker>
    );
};

export default RiderMarker;
