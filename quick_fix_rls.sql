-- Quick fix for RLS policy error
-- Run this single command in your Supabase SQL Editor

-- Disable Row Level Security for testing
ALTER TABLE todo_cesar DISABLE ROW LEVEL SECURITY;
