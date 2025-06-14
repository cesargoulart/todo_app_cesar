-- SQL commands to set up your todo database in Supabase
-- Run these commands in the Supabase SQL Editor

-- Create the todos table
CREATE TABLE todos (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    is_done BOOLEAN DEFAULT FALSE,
    due_date TIMESTAMPTZ NULL,
    parent_id UUID NULL REFERENCES todos(id) ON DELETE CASCADE,
    subtasks JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create an index for better query performance
CREATE INDEX idx_todos_parent_id ON todos(parent_id);
CREATE INDEX idx_todos_due_date ON todos(due_date);
CREATE INDEX idx_todos_is_done ON todos(is_done);

-- Enable Row Level Security (RLS)
ALTER TABLE todos ENABLE ROW LEVEL SECURITY;

-- Create policy to allow all operations for now (you can make this more restrictive later)
CREATE POLICY "Allow all operations on todos" ON todos
    FOR ALL USING (true);

-- If you want to add user authentication later, you can use this policy instead:
-- CREATE POLICY "Users can only access their own todos" ON todos
--     FOR ALL USING (auth.uid() = user_id);
-- (But you'd need to add a user_id column first)

-- Create a function to automatically update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at on every update
CREATE TRIGGER update_todos_updated_at
    BEFORE UPDATE ON todos
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
