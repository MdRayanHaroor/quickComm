import axios from 'axios';
import { supabase } from './supabaseClient';

const api = axios.create({
    baseURL: import.meta.env.VITE_API_BASE_URL,
});

if (!import.meta.env.VITE_API_BASE_URL) {
    console.error('Missing VITE_API_BASE_URL environment variable');
}

// Attach Supabase access token to every outgoing request
api.interceptors.request.use(async (config) => {
    try {
        const { data: { session } } = await supabase.auth.getSession();
        if (session?.access_token) {
            config.headers.Authorization = `Bearer ${session.access_token}`;
        }
    } catch (err) {
        console.error('Failed to get Supabase session for API request:', err);
    }
    return config;
});

export default api;
