-- Adds a free-form "notes" field to tasks, editable from the create/edit task dialog.
ALTER TABLE todo_cesar
ADD COLUMN IF NOT EXISTS notes TEXT NULL;

COMMENT ON COLUMN todo_cesar.notes IS 'Free-form notes for a task, set from the create/edit task dialog';
