# TRIPLAN AI

This is  a travel application.

## Importing shared trips by code

The app now supports importing shared trips using a 6-character `trip_code` instead of (or in addition to) `.triplan` files.

Requirements for the backend:
- GET `/api/trips/by-code/{trip_code}` — returns the trip payload (same structure as export) for preview/import.
- POST `/api/trips/{id}/code` — generate or return an existing 6-char code for sharing a trip.
- Database: add `trip_code VARCHAR(6)` to the `trips` table and create a unique index on it.

Client notes:
- The import UI accepts a 6-character code and fetches the trip preview from the backend.
- File-based import is still available for backups and manual restores.

Apply the DB migration and restart the backend before using code-based import.
