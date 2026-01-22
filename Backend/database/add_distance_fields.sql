-- Migration: Add distance tracking fields to itinerary_items
-- This allows tracking distances from the starting point and between consecutive items

-- Add distance fields
ALTER TABLE itinerary_items 
ADD COLUMN IF NOT EXISTS distance_from_previous_meters INT,
ADD COLUMN IF NOT EXISTS distance_from_previous_text VARCHAR(50),
ADD COLUMN IF NOT EXISTS travel_time_from_previous_seconds INT,
ADD COLUMN IF NOT EXISTS travel_time_from_previous_text VARCHAR(50),
ADD COLUMN IF NOT EXISTS is_starting_point BOOLEAN DEFAULT FALSE;

-- Add comment explaining the fields
COMMENT ON COLUMN itinerary_items.distance_from_previous_meters IS 'Distance in meters from the previous item in the itinerary';
COMMENT ON COLUMN itinerary_items.distance_from_previous_text IS 'Human-readable distance text (e.g., "2.5 km")';
COMMENT ON COLUMN itinerary_items.travel_time_from_previous_seconds IS 'Travel time in seconds from the previous item';
COMMENT ON COLUMN itinerary_items.travel_time_from_previous_text IS 'Human-readable travel time (e.g., "15 min")';
COMMENT ON COLUMN itinerary_items.is_starting_point IS 'Indicates if this is the starting point of the day (first item)';

-- Update existing records to mark first items as starting points
UPDATE itinerary_items ii
SET is_starting_point = TRUE
WHERE order_index = 0
  OR order_index = (
    SELECT MIN(order_index) 
    FROM itinerary_items 
    WHERE itinerary_id = ii.itinerary_id
  );
