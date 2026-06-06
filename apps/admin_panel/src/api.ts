import axios from 'axios';

const api = axios.create({
    baseURL: import.meta.env.VITE_API_BASE_URL,
});

if (!import.meta.env.VITE_API_BASE_URL) {
    console.error('Missing VITE_API_BASE_URL environment variable');
}

export default api;
