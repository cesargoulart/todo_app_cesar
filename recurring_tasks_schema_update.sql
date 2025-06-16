-- SQL commands to add recurring task support to the todo_cesar table
-- Run these commands in the Supabase SQL Editor

-- Add columns for recurring tasks
ALTER TABLE todo_cesar ADD COLUMN IF NOT EXISTS is_recurring BOOLEAN DEFAULT FALSE;
ALTER TABLE todo_cesar ADD COLUMN IF NOT EXISTS recurrence_interval VARCHAR(20) NULL; -- 'daily', 'weekly', 'monthly', 'yearly'
ALTER TABLE todo_cesar ADD COLUMN IF NOT EXISTS recurrence_end_date TIMESTAMPTZ NULL;
ALTER TABLE todo_cesar ADD COLUMN IF NOT EXISTS original_recurring_task_id UUID NULL; -- For instances generated from recurring tasks
ALTER TABLE todo_cesar ADD COLUMN IF NOT EXISTS next_occurrence_date TIMESTAMPTZ NULL; -- When the next instance should be created

-- Create indexes for better query performance on recurring tasks
CREATE INDEX IF NOT EXISTS idx_todo_cesar_is_recurring ON todo_cesar(is_recurring);
CREATE INDEX IF NOT EXISTS idx_todo_cesar_next_occurrence ON todo_cesar(next_occurrence_date);
CREATE INDEX IF NOT EXISTS idx_todo_cesar_original_recurring_task_id ON todo_cesar(original_recurring_task_id);

-- Add a foreign key constraint for original_recurring_task_id
ALTER TABLE todo_cesar ADD CONSTRAINT fk_original_recurring_task 
    FOREIGN KEY (original_recurring_task_id) REFERENCES todo_cesar(id) ON DELETE CASCADE;

-- Function to calculate next occurrence date based on recurrence interval
CREATE OR REPLACE FUNCTION calculate_next_occurrence(
    current_date TIMESTAMPTZ,
    interval_type VARCHAR(20)
) RETURNS TIMESTAMPTZ AS $$
BEGIN
    CASE interval_type
        WHEN 'daily' THEN
            RETURN current_date + INTERVAL '1 day';
        WHEN 'weekly' THEN
            RETURN current_date + INTERVAL '1 week';
        WHEN 'monthly' THEN
            RETURN current_date + INTERVAL '1 month';
        WHEN 'yearly' THEN
            RETURN current_date + INTERVAL '1 year';
        ELSE
            RETURN NULL;
    END CASE;
END;
$$ LANGUAGE plpgsql;

-- Function to automatically update next_occurrence_date when a recurring task is created or updated
CREATE OR REPLACE FUNCTION update_next_occurrence()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_recurring = true AND NEW.recurrence_interval IS NOT NULL AND NEW.due_date IS NOT NULL THEN
        NEW.next_occurrence_date = calculate_next_occurrence(NEW.due_date, NEW.recurrence_interval);
    ELSE
        NEW.next_occurrence_date = NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically calculate next occurrence date
DROP TRIGGER IF EXISTS update_next_occurrence_trigger ON todo_cesar;
CREATE TRIGGER update_next_occurrence_trigger
    BEFORE INSERT OR UPDATE ON todo_cesar
    FOR EACH ROW
    EXECUTE FUNCTION update_next_occurrence();

-- Function to generate recurring task instances
CREATE OR REPLACE FUNCTION generate_recurring_task_instances()
RETURNS TABLE(
    new_task_id UUID,
    original_task_id UUID,
    new_due_date TIMESTAMPTZ
) AS $$
DECLARE
    recurring_task RECORD;
    new_task_uuid UUID;
BEGIN
    -- Find all recurring tasks that need new instances
    FOR recurring_task IN 
        SELECT * FROM todo_cesar 
        WHERE is_recurring = true 
        AND next_occurrence_date IS NOT NULL 
        AND next_occurrence_date <= NOW()
        AND (recurrence_end_date IS NULL OR next_occurrence_date <= recurrence_end_date)
    LOOP
        -- Generate a new UUID for the new task instance
        new_task_uuid := gen_random_uuid();
        
        -- Create a new task instance
        INSERT INTO todo_cesar (
            id,
            title,
            is_done,
            due_date,
            parent_id,
            subtasks,
            is_recurring,
            original_recurring_task_id
        ) VALUES (
            new_task_uuid,
            recurring_task.title,
            false, -- New instances start as not done
            recurring_task.next_occurrence_date,
            recurring_task.parent_id,
            recurring_task.subtasks,
            false, -- Instances are not recurring themselves
            recurring_task.id
        );
        
        -- Update the original recurring task's next occurrence date
        UPDATE todo_cesar 
        SET next_occurrence_date = calculate_next_occurrence(
            recurring_task.next_occurrence_date, 
            recurring_task.recurrence_interval
        )
        WHERE id = recurring_task.id;
        
        -- Return the created task info
        new_task_id := new_task_uuid;
        original_task_id := recurring_task.id;
        new_due_date := recurring_task.next_occurrence_date;
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Create a view to easily see all recurring task instances
CREATE OR REPLACE VIEW recurring_task_instances AS
SELECT 
    t.id,
    t.title,
    t.is_done,
    t.due_date,
    t.created_at,
    rt.id as original_task_id,
    rt.title as original_task_title,
    rt.recurrence_interval
FROM todo_cesar t
JOIN todo_cesar rt ON t.original_recurring_task_id = rt.id
WHERE t.original_recurring_task_id IS NOT NULL;
