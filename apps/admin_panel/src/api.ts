import axios from 'axios';

const api = axios.create({
    // baseURL: 'http://localhost:8000',
    baseURL: 'https://quickcomm-production.up.railway.app',
});

export default api;
