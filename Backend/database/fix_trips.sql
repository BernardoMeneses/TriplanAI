-- Corrigir viagens que estão com city/country incorretos
-- Atualizar a viagem de Portugal
UPDATE trips 
SET 
  title = 'Trip to ' || COALESCE(NULLIF(destination_city, ''), title),
  destination_city = CASE 
    WHEN destination_city = '' OR destination_city IS NULL 
    THEN SPLIT_PART(title, ',', 1)
    ELSE destination_city
  END,
  destination_country = CASE 
    WHEN destination_country = '' OR destination_country IS NULL 
    THEN destination_city
    ELSE destination_country
  END
WHERE title NOT LIKE 'Trip to%' OR destination_country = '' OR destination_country IS NULL;

-- Verificar o resultado
SELECT id, title, destination_city, destination_country, start_date, end_date 
FROM trips 
ORDER BY created_at DESC;
