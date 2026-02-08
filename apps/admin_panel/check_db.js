
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://iyylimmyuqlgrmsclvqp.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml5eWxpbW15dXFsZ3Jtc2NsdnFwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcxNTc4NDAsImV4cCI6MjA4MjczMzg0MH0.5Fo43YPkOrxbrSUBCfQwqj8AE7FaLgGFDzAf9S8QBrY';

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
