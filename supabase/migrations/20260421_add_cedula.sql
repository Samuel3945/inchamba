-- Agregar campo cédula de ciudadanía a la tabla profiles
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS cedula TEXT;

-- Índice para búsqueda por cédula
CREATE UNIQUE INDEX IF NOT EXISTS profiles_cedula_unique
  ON profiles (cedula)
  WHERE cedula IS NOT NULL;

-- Comentario descriptivo
COMMENT ON COLUMN profiles.cedula IS 'Cédula de Ciudadanía colombiana del usuario';
