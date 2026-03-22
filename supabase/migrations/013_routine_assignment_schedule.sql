-- Horario sugerido por el profesor al asignar rutina (días + hora local).
-- schedule_days: 1 = lunes … 7 = domingo (igual que planning_slots / DateTime.weekday).

ALTER TABLE public.routine_assignments
  ADD COLUMN IF NOT EXISTS schedule_days smallint[] NULL,
  ADD COLUMN IF NOT EXISTS schedule_hour smallint NULL,
  ADD COLUMN IF NOT EXISTS schedule_minute smallint NOT NULL DEFAULT 0;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'routine_assignments_schedule_hour_ck'
  ) THEN
    ALTER TABLE public.routine_assignments
      ADD CONSTRAINT routine_assignments_schedule_hour_ck
      CHECK (schedule_hour IS NULL OR (schedule_hour >= 0 AND schedule_hour <= 23));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'routine_assignments_schedule_minute_ck'
  ) THEN
    ALTER TABLE public.routine_assignments
      ADD CONSTRAINT routine_assignments_schedule_minute_ck
      CHECK (schedule_minute >= 0 AND schedule_minute <= 59);
  END IF;
END $$;

COMMENT ON COLUMN public.routine_assignments.schedule_days IS 'Días 1=lun..7=dom; NULL o vacío = sin días fijos';
COMMENT ON COLUMN public.routine_assignments.schedule_hour IS 'Hora local sugerida (0-23); NULL si no se indica hora';
COMMENT ON COLUMN public.routine_assignments.schedule_minute IS 'Minutos (0-59), con schedule_hour';
