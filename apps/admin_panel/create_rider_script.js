
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://iyylimmyuqlgrmsclvqp.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml5eWxpbW15dXFsZ3Jtc2NsdnFwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcxNTc4NDAsImV4cCI6MjA4MjczMzg0MH0.5Fo43YPkOrxbrSUBCfQwqj8AE7FaLgGFDzAf9S8QBrY';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

const createRider = async () => {
    const email = 'rider@quickcomm.com';
    const password = 'password123';

    console.log(`Attempting to sign up ${email}...`);

    // 1. Sign Up
    const { data: authData, error: authError } = await supabase.auth.signUp({
        email,
        password,
        options: {
            data: {
                full_name: 'Super Rider',
                role: 'rider' // We hope the trigger picks this up, but the trigger in schema.sql hardcodes 'user'
            }
        }
    });

    if (authError) {
        console.log("Auth Error (User might exist):", authError.message);
        // If user exists, try to sign in to get the ID
        const { data: signInData, error: signInError } = await supabase.auth.signInWithPassword({
            email,
            password
        });
        
        if (signInError) {
            console.error("Critical: Could not sign in existing rider:", signInError.message);
            return;
        }
        console.log("Signed in existing rider:", signInData.user.id);
        await updateProfile(signInData.user.id);
    } else {
        console.log("Rider created:", authData.user?.id);
        if (authData.user) {
            // Wait a moment for trigger
            setTimeout(() => updateProfile(authData.user.id), 2000);
        }
    }
};

const updateProfile = async (userId) => {
    console.log(`Updating profile for ${userId}...`);
    
    // 2. Update Profile (Role, Address, Active Status)
    // We try to update 'role' directly. RLS usually allows users to update their own profile.
    // However, 'role' might be protected in a real app, but schema.sql says "Users can update own profile".
    
    const updates = {
        role: 'rider',
        full_name: 'Super Rider',
        // These cols might not exist yet:
        address: 'Rider Hub, Bangalore', 
        // is_rider_active: true // Commented out to test existence first? No, let's try.
    };

    const { error } = await supabase
        .from('profiles')
        .update(updates)
        .eq('id', userId);

    if (error) {
        console.error("Profile Update Error:", error.message);
        console.log("Likely 'address' column missing or RLS issue.");
    } else {
        console.log("Profile updated successfully! (Schema seems correct)");
    }
};

createRider();
