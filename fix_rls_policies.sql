-- Fix RLS policies for todo_cesar table
-- Run these commands in your Supabase SQL Editor

-- First, let's check if RLS is enabled and what policies exist
-- SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'todo_cesar';

-- Option 1: Disable RLS entirely (for development/testing)
-- WARNING: This removes all security! Only use for testing.
ALTER TABLE todo_cesar DISABLE ROW LEVEL SECURITY;

-- Option 2: Create permissive policies (recommended for development)
-- If you want to keep RLS enabled but allow all operations:

-- Enable RLS (if not already enabled)
-- ALTER TABLE todo_cesar ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
-- DROP POLICY IF EXISTS "Allow all operations on todo_cesar" ON todo_cesar;

-- Create a permissive policy that allows all operations
-- CREATE POLICY "Allow all operations on todo_cesar" ON todo_cesar
--     FOR ALL 
--     USING (true)
--     WITH CHECK (true);

-- Option 3: User-specific policies (for production with authentication)
-- If you plan to add user authentication later, use these instead:

-- CREATE POLICY "Users can view their own todos" ON todo_cesar
--     FOR SELECT USING (auth.uid()::text = user_id);

-- CREATE POLICY "Users can insert their own todos" ON todo_cesar
--     FOR INSERT WITH CHECK (auth.uid()::text = user_id);

-- CREATE POLICY "Users can update their own todos" ON todo_cesar
--     FOR UPDATE USING (auth.uid()::text = user_id);

-- CREATE POLICY "Users can delete their own todos" ON todo_cesar
--     FOR DELETE USING (auth.uid()::text = user_id);

-- Note: For Option 3, you would need to add a user_id column:
-- ALTER TABLE todo_cesar ADD COLUMN user_id UUID REFERENCES auth.users(id);

-- RECOMMENDED FOR NOW: Use Option 1 (disable RLS) for testing
-- Once your app works, you can re-enable RLS with proper policies
