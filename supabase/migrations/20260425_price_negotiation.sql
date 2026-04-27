-- Nivel de dificultad del trabajo (1-5 estrellas)
ALTER TABLE job_posts
  ADD COLUMN IF NOT EXISTS difficulty_stars INT DEFAULT 3
    CHECK (difficulty_stars BETWEEN 1 AND 5);

-- Precio propuesto por el trabajador al postularse
ALTER TABLE job_applications
  ADD COLUMN IF NOT EXISTS proposed_pay NUMERIC;

-- Límite de estrellas de dificultad que el trabajador puede acumular por día
-- (para evitar sobrecarga — ej: si el límite es 15 y acepta dos trabajos de 5★ ya lleva 10)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS daily_star_limit INT DEFAULT 15;
