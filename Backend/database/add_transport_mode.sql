-- Add transport_mode field to itinerary_items table
ALTER TABLE itinerary_items 
ADD COLUMN IF NOT EXISTS transport_mode VARCHAR(20);

-- Add comment to explain the field
COMMENT ON COLUMN itinerary_items.transport_mode IS 'Transport mode between previous item and this one: walking, driving, transit';
