-- SQL commands to add label support to the todo_cesar table
-- Run these commands in the Supabase SQL Editor

-- Create labels table
CREATE TABLE IF NOT EXISTS todo_labels (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    color TEXT NOT NULL DEFAULT '#2196F3', -- Default blue color
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create task_labels junction table for many-to-many relationship
CREATE TABLE IF NOT EXISTS todo_task_labels (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    task_id UUID NOT NULL REFERENCES todo_cesar(id) ON DELETE CASCADE,
    label_id UUID NOT NULL REFERENCES todo_labels(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(task_id, label_id) -- Prevent duplicate label assignments
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_todo_task_labels_task_id ON todo_task_labels(task_id);
CREATE INDEX IF NOT EXISTS idx_todo_task_labels_label_id ON todo_task_labels(label_id);

-- Insert some default labels
INSERT INTO todo_labels (name, color) VALUES
    ('Work', '#FF5722'),
    ('Personal', '#4CAF50'),
    ('Urgent', '#F44336'),
    ('Shopping', '#9C27B0'),
    ('Health', '#00BCD4'),
    ('Study', '#FF9800')
ON CONFLICT (name) DO NOTHING;

-- Function to get tasks with their labels
CREATE OR REPLACE VIEW todo_with_labels AS
SELECT 
    t.*,
    COALESCE(
        JSON_AGG(
            JSON_BUILD_OBJECT(
                'id', l.id,
                'name', l.name,
                'color', l.color
            )
        ) FILTER (WHERE l.id IS NOT NULL),
        '[]'::json
    ) as labels
FROM todo_cesar t
LEFT JOIN todo_task_labels tl ON t.id = tl.task_id
LEFT JOIN todo_labels l ON tl.label_id = l.id
GROUP BY t.id;

-- Function to add label to task
CREATE OR REPLACE FUNCTION add_label_to_task(task_uuid UUID, label_uuid UUID)
RETURNS void AS $$
BEGIN
    INSERT INTO todo_task_labels (task_id, label_id)
    VALUES (task_uuid, label_uuid)
    ON CONFLICT (task_id, label_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- Function to remove label from task
CREATE OR REPLACE FUNCTION remove_label_from_task(task_uuid UUID, label_uuid UUID)
RETURNS void AS $$
BEGIN
    DELETE FROM todo_task_labels 
    WHERE task_id = task_uuid AND label_id = label_uuid;
END;
$$ LANGUAGE plpgsql;

-- Function to create new label
CREATE OR REPLACE FUNCTION create_label(label_name TEXT, label_color TEXT DEFAULT '#2196F3')
RETURNS UUID AS $$
DECLARE
    new_label_id UUID;
BEGIN
    INSERT INTO todo_labels (name, color)
    VALUES (label_name, label_color)
    RETURNING id INTO new_label_id;
    
    RETURN new_label_id;
END;
$$ LANGUAGE plpgsql;
