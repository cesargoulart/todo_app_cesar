-- SQL commands to set up your todo_cesar table in Supabase
-- Run these commands in the Supabase SQL Editor if you haven't created the table yet
-- Or use this to verify your table structure

-- Create the todo_cesar table (if it doesn't exist)
CREATE TABLE IF NOT EXISTS todo_cesar (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    is_done BOOLEAN DEFAULT FALSE,
    due_date TIMESTAMPTZ NULL,
    parent_id UUID NULL REFERENCES todo_cesar(id) ON DELETE CASCADE,
    subtasks JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_todo_cesar_parent_id ON todo_cesar(parent_id);
CREATE INDEX IF NOT EXISTS idx_todo_cesar_due_date ON todo_cesar(due_date);
CREATE INDEX IF NOT EXISTS idx_todo_cesar_is_done ON todo_cesar(is_done);

-- Enable Row Level Security (RLS)
ALTER TABLE todo_cesar ENABLE ROW LEVEL SECURITY;

-- Create policy to allow all operations for now
DROP POLICY IF EXISTS "Allow all operations on todo_cesar" ON todo_cesar;
CREATE POLICY "Allow all operations on todo_cesar" ON todo_cesar
    FOR ALL USING (true);

-- Create a function to automatically update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_todo_cesar_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at on every update
DROP TRIGGER IF EXISTS update_todo_cesar_updated_at_trigger ON todo_cesar;
CREATE TRIGGER update_todo_cesar_updated_at_trigger
    BEFORE UPDATE ON todo_cesar
    FOR EACH ROW
    EXECUTE FUNCTION update_todo_cesar_updated_at();

-- Insert some sample data to test (optional)
-- INSERT INTO todo_cesar (title, is_done, due_date) VALUES
-- ('Sample Task 1', false, NOW() + INTERVAL '1 day'),
-- ('Sample Task 2', true, NOW() + INTERVAL '2 days'),
-- ('Sample Task 3', false, NOW() + INTERVAL '7 days');
