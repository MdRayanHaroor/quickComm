
import { createClient } from '@supabase/supabase-js';
import axios from 'axios';

const SUPABASE_URL = 'https://iyylimmyuqlgrmsclvqp.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml5eWxpbW15dXFsZ3Jtc2NsdnFwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcxNTc4NDAsImV4cCI6MjA4MjczMzg0MH0.5Fo43YPkOrxbrSUBCfQwqj8AE7FaLgGFDzAf9S8QBrY';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);
const RIDER_ID = 'simulated-rider-01';

// Start: use the store location
const startLat = localStorage.getItem('storeLat');
const startLng = localStorage.getItem('storeLng');

// End: Nearby destination
const endLat = 13.020965012517026;
const endLng = 77.64319256724274;

async function getRoute(start, end) {
    try {
        console.log('Fetching route from OSRM...');
        // OSRM requires "lng,lat", not "lat,lng" for URL
        const url = `http://router.project-osrm.org/route/v1/driving/${start.lng},${start.lat};${end.lng},${end.lat}?overview=full&geometries=geojson`;
        
        const response = await axios.get(url);
        
        if (response.data.routes && response.data.routes.length > 0) {
            // Returns [lng, lat] arrays
            return response.data.routes[0].geometry.coordinates.map(coord => ({
                lat: coord[1],
                lng: coord[0]
            }));
        }
        return [];
    } catch (error) {
        console.error('Error fetching route:', error.message);
        return [];
    }
}

// Simple linear interpolation between two points to smooth out the steps
function interpolatePoints(points, stepsPerSegment) {
    const smoothPoints = [];
    for (let i = 0; i < points.length - 1; i++) {
        const p1 = points[i];
        const p2 = points[i+1];
        
        for (let j = 0; j < stepsPerSegment; j++) {
            const t = j / stepsPerSegment;
            smoothPoints.push({
                lat: p1.lat + (p2.lat - p1.lat) * t,
                lng: p1.lng + (p2.lng - p1.lng) * t
            });
        }
    }
    smoothPoints.push(points[points.length - 1]);
    return smoothPoints;
}

const main = async () => {
    const rawRoute = await getRoute({lat: startLat, lng: startLng}, {lat: endLat, lng: endLng});
    
    if (rawRoute.length === 0) {
        console.error('No route found. Exiting.');
        return;
    }

    // Interpolate to make it 20x smoother (OSRM returns sparse waypoints)
    const route = interpolatePoints(rawRoute, 20);
    console.log(`Route loaded: ${route.length} simulated steps.`);

    const channel = supabase.channel('riders');

    channel.subscribe(async (status) => {
        if (status === 'SUBSCRIBED') {
            console.log('Connected to Supabase! Starting playback...');
            
            let i = 0;
            const interval = setInterval(async () => {
                if (i >= route.length) {
                    console.log('Destination reached! Stopping simulation.');
                    clearInterval(interval);
                    return;
                }

                const point = route[i];
                const payload = {
                    rider_id: RIDER_ID,
                    lat: point.lat,
                    lng: point.lng
                };

                // Only log every 10th step to avoid spam
                if (i % 10 === 0) console.log(`Step ${i}/${route.length}`, payload);
                
                await channel.send({
                    type: 'broadcast',
                    event: 'location',
                    payload: payload
                });

                i++;
            }, 1000); // Send update every 1 second (1000ms)
        }
    });
};

main();
