import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
// Note: Vite's dev server already serves index.html for all unknown paths by
// default (appType: 'spa'), so React Router can handle client-side routes on
// page refresh without any extra server config.
export default defineConfig({
  plugins: [react()],
})
