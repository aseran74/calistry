-- ============================================
-- Teachers, teacher-student links, messaging and live classes
-- ============================================

ALTER TYPE public.role_enum ADD VALUE IF NOT EXISTS 'teacher';

CREATE OR REPLACE FUNCTION public.current_app_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select coalesce((select u.role::text from public.users u where u.id = auth.uid()), 'user');
$function$;

CREATE TABLE IF NOT EXISTS public.teacher_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
  display_name text NOT NULL,
  specialty text,
  bio text,
  motivation text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  review_notes text,
  reviewed_by_user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.teacher_student_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  student_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  requested_by_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  review_notes text,
  approved_at timestamptz,
  created_at timestamptz DEFAULT now(),
  UNIQUE(teacher_user_id, student_user_id)
);

CREATE TABLE IF NOT EXISTS public.conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  student_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(teacher_user_id, student_user_id)
);

CREATE TABLE IF NOT EXISTS public.conversation_participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  participant_role text NOT NULL CHECK (participant_role IN ('teacher', 'student')),
  created_at timestamptz DEFAULT now(),
  UNIQUE(conversation_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  body text NOT NULL,
  read_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.live_classes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'live'
    CHECK (status IN ('scheduled', 'live', 'ended')),
  started_at timestamptz DEFAULT now(),
  ended_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.live_class_participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  live_class_id uuid NOT NULL REFERENCES public.live_classes(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  participant_role text NOT NULL CHECK (participant_role IN ('teacher', 'student')),
  is_connected boolean NOT NULL DEFAULT false,
  joined_at timestamptz DEFAULT now(),
  last_seen_at timestamptz DEFAULT now(),
  UNIQUE(live_class_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.live_class_chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  live_class_id uuid NOT NULL REFERENCES public.live_classes(id) ON DELETE CASCADE,
  sender_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.has_approved_teacher_student_link(
  user_a uuid,
  user_b uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select exists(
    select 1
    from public.teacher_student_links l
    where l.status = 'approved'
      and (
        (l.teacher_user_id = user_a and l.student_user_id = user_b) or
        (l.teacher_user_id = user_b and l.student_user_id = user_a)
      )
  );
$function$;

CREATE OR REPLACE FUNCTION public.has_teacher_student_link(
  user_a uuid,
  user_b uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select exists(
    select 1
    from public.teacher_student_links l
    where
      (l.teacher_user_id = user_a and l.student_user_id = user_b) or
      (l.teacher_user_id = user_b and l.student_user_id = user_a)
  );
$function$;

CREATE OR REPLACE FUNCTION public.is_teacher_user(target_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select exists(
    select 1
    from public.users u
    where u.id = target_user_id
      and u.role::text = 'teacher'
  );
$function$;

CREATE OR REPLACE FUNCTION public.can_access_live_class(target_live_class_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select exists(
    select 1
    from public.live_classes lc
    where lc.id = target_live_class_id
      and (
        lc.teacher_user_id = auth.uid()
        or exists (
          select 1
          from public.teacher_student_links l
          where l.teacher_user_id = lc.teacher_user_id
            and l.student_user_id = auth.uid()
            and l.status = 'approved'
        )
      )
  );
$function$;

CREATE OR REPLACE FUNCTION public.can_access_conversation(target_conversation_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select exists(
    select 1
    from public.conversation_participants cp
    where cp.conversation_id = target_conversation_id
      and cp.user_id = auth.uid()
  );
$function$;

CREATE INDEX IF NOT EXISTS idx_teacher_applications_status
  ON public.teacher_applications(status);
CREATE INDEX IF NOT EXISTS idx_teacher_student_links_teacher
  ON public.teacher_student_links(teacher_user_id);
CREATE INDEX IF NOT EXISTS idx_teacher_student_links_student
  ON public.teacher_student_links(student_user_id);
CREATE INDEX IF NOT EXISTS idx_teacher_student_links_status
  ON public.teacher_student_links(status);
CREATE INDEX IF NOT EXISTS idx_conversations_teacher
  ON public.conversations(teacher_user_id);
CREATE INDEX IF NOT EXISTS idx_conversations_student
  ON public.conversations(student_user_id);
CREATE INDEX IF NOT EXISTS idx_conversation_participants_user
  ON public.conversation_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_conversation
  ON public.messages(conversation_id, created_at desc);
CREATE INDEX IF NOT EXISTS idx_live_classes_teacher
  ON public.live_classes(teacher_user_id, created_at desc);
CREATE INDEX IF NOT EXISTS idx_live_classes_status
  ON public.live_classes(status);
CREATE INDEX IF NOT EXISTS idx_live_class_participants_live_class
  ON public.live_class_participants(live_class_id);
CREATE INDEX IF NOT EXISTS idx_live_class_chat_messages_live_class
  ON public.live_class_chat_messages(live_class_id, created_at desc);

ALTER TABLE public.teacher_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_student_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_class_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_class_chat_messages ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'users'
      AND policyname = 'users_select_teacher_profiles'
  ) THEN
    CREATE POLICY "users_select_teacher_profiles"
      ON public.users
      FOR SELECT
      USING (role::text = 'teacher');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'users'
      AND policyname = 'users_select_teacher_links'
  ) THEN
    CREATE POLICY "users_select_teacher_links"
      ON public.users
      FOR SELECT
      USING (public.has_teacher_student_link(id, auth.uid()));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'teacher_applications'
      AND policyname = 'teacher_applications_select_own'
  ) THEN
    CREATE POLICY "teacher_applications_select_own"
      ON public.teacher_applications
      FOR SELECT
      USING (user_id = auth.uid());
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'teacher_applications'
      AND policyname = 'teacher_applications_select_approved'
  ) THEN
    CREATE POLICY "teacher_applications_select_approved"
      ON public.teacher_applications
      FOR SELECT
      USING (status = 'approved');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'teacher_applications'
      AND policyname = 'teacher_applications_insert_own'
  ) THEN
    CREATE POLICY "teacher_applications_insert_own"
      ON public.teacher_applications
      FOR INSERT
      WITH CHECK (user_id = auth.uid() AND current_app_role() = 'user');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'teacher_applications'
      AND policyname = 'teacher_applications_update_own_pending'
  ) THEN
    CREATE POLICY "teacher_applications_update_own_pending"
      ON public.teacher_applications
      FOR UPDATE
      USING (user_id = auth.uid() AND status IN ('pending', 'rejected'))
      WITH CHECK (user_id = auth.uid() AND status IN ('pending', 'rejected'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'teacher_applications'
      AND policyname = 'teacher_applications_admin_all'
  ) THEN
    CREATE POLICY "teacher_applications_admin_all"
      ON public.teacher_applications
      FOR ALL
      USING (current_app_role() = ANY (ARRAY['admin'::text, 'moderator'::text]))
      WITH CHECK (current_app_role() = ANY (ARRAY['admin'::text, 'moderator'::text]));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'teacher_student_links'
      AND policyname = 'teacher_student_links_select_related'
  ) THEN
    CREATE POLICY "teacher_student_links_select_related"
      ON public.teacher_student_links
      FOR SELECT
      USING (teacher_user_id = auth.uid() OR student_user_id = auth.uid());
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'teacher_student_links'
      AND policyname = 'teacher_student_links_insert_student'
  ) THEN
    CREATE POLICY "teacher_student_links_insert_student"
      ON public.teacher_student_links
      FOR INSERT
      WITH CHECK (
        student_user_id = auth.uid()
        AND requested_by_user_id = auth.uid()
        AND teacher_user_id <> auth.uid()
        AND public.is_teacher_user(teacher_user_id)
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'teacher_student_links'
      AND policyname = 'teacher_student_links_update_teacher'
  ) THEN
    CREATE POLICY "teacher_student_links_update_teacher"
      ON public.teacher_student_links
      FOR UPDATE
      USING (teacher_user_id = auth.uid() AND status = 'pending')
      WITH CHECK (teacher_user_id = auth.uid() AND status IN ('approved', 'rejected'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'teacher_student_links'
      AND policyname = 'teacher_student_links_delete_pending_student'
  ) THEN
    CREATE POLICY "teacher_student_links_delete_pending_student"
      ON public.teacher_student_links
      FOR DELETE
      USING (student_user_id = auth.uid() AND status = 'pending');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'teacher_student_links'
      AND policyname = 'teacher_student_links_admin_all'
  ) THEN
    CREATE POLICY "teacher_student_links_admin_all"
      ON public.teacher_student_links
      FOR ALL
      USING (current_app_role() = ANY (ARRAY['admin'::text, 'moderator'::text]))
      WITH CHECK (current_app_role() = ANY (ARRAY['admin'::text, 'moderator'::text]));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'conversations'
      AND policyname = 'conversations_select_related'
  ) THEN
    CREATE POLICY "conversations_select_related"
      ON public.conversations
      FOR SELECT
      USING (teacher_user_id = auth.uid() OR student_user_id = auth.uid());
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'conversations'
      AND policyname = 'conversations_insert_related'
  ) THEN
    CREATE POLICY "conversations_insert_related"
      ON public.conversations
      FOR INSERT
      WITH CHECK (
        (teacher_user_id = auth.uid() OR student_user_id = auth.uid())
        AND public.has_approved_teacher_student_link(teacher_user_id, student_user_id)
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'conversation_participants'
      AND policyname = 'conversation_participants_select_related'
  ) THEN
    CREATE POLICY "conversation_participants_select_related"
      ON public.conversation_participants
      FOR SELECT
      USING (user_id = auth.uid() OR public.can_access_conversation(conversation_id));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'conversation_participants'
      AND policyname = 'conversation_participants_insert_related'
  ) THEN
    CREATE POLICY "conversation_participants_insert_related"
      ON public.conversation_participants
      FOR INSERT
      WITH CHECK (
        EXISTS (
          SELECT 1
          FROM public.conversations c
          WHERE c.id = conversation_id
            AND (c.teacher_user_id = auth.uid() OR c.student_user_id = auth.uid())
        )
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'messages'
      AND policyname = 'messages_select_related'
  ) THEN
    CREATE POLICY "messages_select_related"
      ON public.messages
      FOR SELECT
      USING (public.can_access_conversation(conversation_id));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'messages'
      AND policyname = 'messages_insert_sender'
  ) THEN
    CREATE POLICY "messages_insert_sender"
      ON public.messages
      FOR INSERT
      WITH CHECK (
        sender_user_id = auth.uid()
        AND public.can_access_conversation(conversation_id)
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'live_classes'
      AND policyname = 'live_classes_select_accessible'
  ) THEN
    CREATE POLICY "live_classes_select_accessible"
      ON public.live_classes
      FOR SELECT
      USING (
        teacher_user_id = auth.uid()
        OR EXISTS (
          SELECT 1
          FROM public.teacher_student_links l
          WHERE l.teacher_user_id = live_classes.teacher_user_id
            AND l.student_user_id = auth.uid()
            AND l.status = 'approved'
        )
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'live_classes'
      AND policyname = 'live_classes_insert_teacher'
  ) THEN
    CREATE POLICY "live_classes_insert_teacher"
      ON public.live_classes
      FOR INSERT
      WITH CHECK (
        teacher_user_id = auth.uid()
        AND current_app_role() = 'teacher'
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'live_classes'
      AND policyname = 'live_classes_update_teacher'
  ) THEN
    CREATE POLICY "live_classes_update_teacher"
      ON public.live_classes
      FOR UPDATE
      USING (teacher_user_id = auth.uid())
      WITH CHECK (teacher_user_id = auth.uid());
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'live_class_participants'
      AND policyname = 'live_class_participants_select_accessible'
  ) THEN
    CREATE POLICY "live_class_participants_select_accessible"
      ON public.live_class_participants
      FOR SELECT
      USING (public.can_access_live_class(live_class_id));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'live_class_participants'
      AND policyname = 'live_class_participants_insert_accessible'
  ) THEN
    CREATE POLICY "live_class_participants_insert_accessible"
      ON public.live_class_participants
      FOR INSERT
      WITH CHECK (
        user_id = auth.uid()
        AND public.can_access_live_class(live_class_id)
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'live_class_participants'
      AND policyname = 'live_class_participants_update_self'
  ) THEN
    CREATE POLICY "live_class_participants_update_self"
      ON public.live_class_participants
      FOR UPDATE
      USING (user_id = auth.uid() OR public.can_access_live_class(live_class_id))
      WITH CHECK (user_id = auth.uid() OR public.can_access_live_class(live_class_id));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'live_class_chat_messages'
      AND policyname = 'live_class_chat_messages_select_accessible'
  ) THEN
    CREATE POLICY "live_class_chat_messages_select_accessible"
      ON public.live_class_chat_messages
      FOR SELECT
      USING (public.can_access_live_class(live_class_id));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'live_class_chat_messages'
      AND policyname = 'live_class_chat_messages_insert_accessible'
  ) THEN
    CREATE POLICY "live_class_chat_messages_insert_accessible"
      ON public.live_class_chat_messages
      FOR INSERT
      WITH CHECK (
        sender_user_id = auth.uid()
        AND public.can_access_live_class(live_class_id)
      );
  END IF;
END $$;
