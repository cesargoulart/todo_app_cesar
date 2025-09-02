-- Add column to support "show only on due date" feature
-- This script adds a new boolean column to the todo_cesar table

ALTER TABLE todo_cesar 
ADD COLUMN show_only_on_due_date BOOLEAN DEFAULT FALSE;

-- Add a comment to document the column
COMMENT ON COLUMN todo_cesar.show_only_on_due_date IS 'If true, task will only be visible on or after its due date';

-- Optional: Update existing tasks with due dates in the future to use this feature
-- Uncomment the line below if you want to automatically apply this to existing future tasks
-- UPDATE todo_cesar SET show_only_on_due_date = TRUE WHERE due_date > NOW() AND due_date IS NOT NULL;
