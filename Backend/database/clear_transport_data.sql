-- Clear transport data to force recalculation with new algorithm
-- This will clear the old transport times so they get recalculated with the correct mode

UPDATE itinerary_items 
SET 
  distance_from_previous_meters = NULL,
  distance_from_previous_text = NULL,
  travel_time_from_previous_seconds = NULL,
  travel_time_from_previous_text = NULL,
  transport_mode = NULL
WHERE is_starting_point = false;

-- Note: After running this, you need to trigger a recalculation
-- You can do this by:
-- 1. Moving/reordering any item in the trip
-- 2. Adding a new item to the trip
-- 3. Or calling the recalculateDistances endpoint for each itinerary
