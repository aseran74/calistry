-- Grupos de alumnos (profesor) + chat de grupo (Insforge/Supabase)

CREATE TABLE IF NOT EXISTS public.teacher_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(teacher_user_id, name)
);

CREATE TABLE IF NOT EXISTS public.teacher_group_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES public.teacher_groups(id) ON DELETE CASCADE,
  student_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(group_id, student_user_id)
);

CREATE TABLE IF NOT EXISTS public.group_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL UNIQUE REFERENCES public.teacher_groups(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.group_conversation_participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_conversation_id uuid NOT NULL REFERENCES public.group_conversations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(group_conversation_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.group_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_conversation_id uuid NOT NULL REFERENCES public.group_conversations(id) ON DELETE CASCADE,
  sender_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_teacher_groups_teacher
  ON public.teacher_groups(teacher_user_id, created_at desc);
CREATE INDEX IF NOT EXISTS idx_teacher_group_members_group
  ON public.teacher_group_members(group_id, created_at desc);
CREATE INDEX IF NOT EXISTS idx_teacher_group_members_student
  ON public.teacher_group_members(student_user_id);
CREATE INDEX IF NOT EXISTS idx_group_messages_conversation
  ON public.group_messages(group_conversation_id, created_at desc);

ALTER TABLE public.teacher_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_messages ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.can_access_group_conversation(target_group_conversation_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select exists(
    select 1
    from public.group_conversation_participants gp
    where gp.group_conversation_id = target_group_conversation_id
      and gp.user_id = auth.uid()
  );
$function$;

-- teacher_groups policies
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'teacher_groups'
      AND policyname = 'teacher_groups_select_owner'
  ) THEN
    CREATE POLICY "teacher_groups_select_owner"
      ON public.teacher_groups FOR SELECT
      USING (teacher_user_id = auth.uid());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'teacher_groups'
      AND policyname = 'teacher_groups_insert_owner'
  ) THEN
    CREATE POLICY "teacher_groups_insert_owner"
      ON public.teacher_groups FOR INSERT
      WITH CHECK (teacher_user_id = auth.uid() AND current_app_role() = 'teacher');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'teacher_groups'
      AND policyname = 'teacher_groups_update_owner'
  ) THEN
    CREATE POLICY "teacher_groups_update_owner"
      ON public.teacher_groups FOR UPDATE
      USING (teacher_user_id = auth.uid())
      WITH CHECK (teacher_user_id = auth.uid());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'teacher_groups'
      AND policyname = 'teacher_groups_delete_owner'
  ) THEN
    CREATE POLICY "teacher_groups_delete_owner"
      ON public.teacher_groups FOR DELETE
      USING (teacher_user_id = auth.uid());
  END IF;
END $$;

-- teacher_group_members policies
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'teacher_group_members'
      AND policyname = 'teacher_group_members_select_related'
  ) THEN
    CREATE POLICY "teacher_group_members_select_related"
      ON public.teacher_group_members FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM public.teacher_groups g
          WHERE g.id = teacher_group_members.group_id
            AND (g.teacher_user_id = auth.uid() OR teacher_group_members.student_user_id = auth.uid())
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'teacher_group_members'
      AND policyname = 'teacher_group_members_insert_teacher'
  ) THEN
    CREATE POLICY "teacher_group_members_insert_teacher"
      ON public.teacher_group_members FOR INSERT
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM public.teacher_groups g
          WHERE g.id = teacher_group_members.group_id
            AND g.teacher_user_id = auth.uid()
        )
        AND EXISTS (
          SELECT 1 FROM public.teacher_student_links l
          WHERE l.teacher_user_id = auth.uid()
            AND l.student_user_id = teacher_group_members.student_user_id
            AND l.status = 'approved'
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'teacher_group_members'
      AND policyname = 'teacher_group_members_delete_teacher'
  ) THEN
    CREATE POLICY "teacher_group_members_delete_teacher"
      ON public.teacher_group_members FOR DELETE
      USING (
        EXISTS (
          SELECT 1 FROM public.teacher_groups g
          WHERE g.id = teacher_group_members.group_id
            AND g.teacher_user_id = auth.uid()
        )
      );
  END IF;
END $$;

-- group_conversations policies
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'group_conversations'
      AND policyname = 'group_conversations_select_related'
  ) THEN
    CREATE POLICY "group_conversations_select_related"
      ON public.group_conversations FOR SELECT
      USING (
        EXISTS (
          SELECT 1
          FROM public.teacher_groups g
          JOIN public.teacher_group_members m ON m.group_id = g.id
          WHERE g.id = group_conversations.group_id
            AND (g.teacher_user_id = auth.uid() OR m.student_user_id = auth.uid())
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'group_conversations'
      AND policyname = 'group_conversations_insert_teacher'
  ) THEN
    CREATE POLICY "group_conversations_insert_teacher"
      ON public.group_conversations FOR INSERT
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM public.teacher_groups g
          WHERE g.id = group_conversations.group_id
            AND g.teacher_user_id = auth.uid()
        )
      );
  END IF;
END $$;

-- group_conversation_participants policies
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'group_conversation_participants'
      AND policyname = 'group_conversation_participants_select_related'
  ) THEN
    CREATE POLICY "group_conversation_participants_select_related"
      ON public.group_conversation_participants FOR SELECT
      USING (user_id = auth.uid() OR public.can_access_group_conversation(group_conversation_id));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'group_conversation_participants'
      AND policyname = 'group_conversation_participants_insert_teacher'
  ) THEN
    CREATE POLICY "group_conversation_participants_insert_teacher"
      ON public.group_conversation_participants FOR INSERT
      WITH CHECK (
        EXISTS (
          SELECT 1
          FROM public.group_conversations gc
          JOIN public.teacher_groups g ON g.id = gc.group_id
          WHERE gc.id = group_conversation_participants.group_conversation_id
            AND g.teacher_user_id = auth.uid()
        )
      );
  END IF;
END $$;

-- group_messages policies
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'group_messages'
      AND policyname = 'group_messages_select_related'
  ) THEN
    CREATE POLICY "group_messages_select_related"
      ON public.group_messages FOR SELECT
      USING (public.can_access_group_conversation(group_conversation_id));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'group_messages'
      AND policyname = 'group_messages_insert_sender'
  ) THEN
    CREATE POLICY "group_messages_insert_sender"
      ON public.group_messages FOR INSERT
      WITH CHECK (
        sender_user_id = auth.uid()
        AND public.can_access_group_conversation(group_conversation_id)
      );
  END IF;
END $$;

