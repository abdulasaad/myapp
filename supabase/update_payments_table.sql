-- Update payments table to support bonus payments
-- Run this in your Supabase SQL Editor

-- Add new columns to payments table for bonus tracking
ALTER TABLE payments 
ADD COLUMN IF NOT EXISTS payment_amount INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS bonus_amount INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'manual',
ADD COLUMN IF NOT EXISTS notes TEXT;

-- Update existing records to set payment_amount = amount for backwards compatibility
UPDATE payments 
SET payment_amount = amount, bonus_amount = 0 
WHERE payment_amount IS NULL OR payment_amount = 0;

-- Verify the table structure
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_name = 'payments' 
ORDER BY ordinal_position;