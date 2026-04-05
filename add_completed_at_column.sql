-- Add completed_at column to todos table
-- Records the timestamp when a task is marked as done

ALTER TABLE todos
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;
