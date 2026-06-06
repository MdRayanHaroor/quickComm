
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.VITE_SUPABASE_URL;
const SUPABASE_KEY = process.env.VITE_SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SUPABASE_KEY) {
    console.error('Error: VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY environment variables must be set.');
    process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

const checkTables = async () => {
    // Try to select from a hypothetical 'store_settings' or 'settings' table
    const { data, error } = await supabase.from('store_settings').select('*').limit(1);
    if (error) {
        console.log("Table 'store_settings' error (likely doesn't exist):", error.message);
    } else {
        console.log("Table 'store_settings' exists!", data);
    }

    // List all tables using a trick if possible, but standard client doesn't support schema listing easily without admin API.
    // relying on error message above.
};

checkTables();
