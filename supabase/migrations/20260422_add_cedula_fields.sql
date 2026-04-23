-- Agregar datos completos extraídos de la cédula al perfil
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS cedula_full_name   TEXT,
  ADD COLUMN IF NOT EXISTS cedula_date_birth  DATE,
  ADD COLUMN IF NOT EXISTS cedula_place_birth TEXT,
  ADD COLUMN IF NOT EXISTS cedula_blood_type  TEXT,
  ADD COLUMN IF NOT EXISTS cedula_sex         CHAR(1),
  ADD COLUMN IF NOT EXISTS cedula_height_cm   SMALLINT;
