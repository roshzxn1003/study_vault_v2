-- ============================================================
-- STUDY VAULT — PHASE 8 SUPABASE MIGRATION
-- Offline-First Cloud Synchronization & Storage Schema
-- ============================================================

-- 1. Workspaces Table
CREATE TABLE IF NOT EXISTS public.workspaces (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    purpose TEXT NOT NULL DEFAULT 'college',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_workspaces_user_updated ON public.workspaces(user_id, updated_at);

-- 2. Academic Years Table
CREATE TABLE IF NOT EXISTS public.academic_years (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    year_name TEXT NOT NULL,
    is_current BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_academic_years_user_updated ON public.academic_years(user_id, updated_at);

-- 3. Academic Periods Table (Semesters / Classes)
CREATE TABLE IF NOT EXISTS public.academic_periods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
    academic_year_id UUID NOT NULL REFERENCES public.academic_years(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    period_type TEXT NOT NULL,
    is_current BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_academic_periods_user_updated ON public.academic_periods(user_id, updated_at);

-- 4. Academic Subjects Table
CREATE TABLE IF NOT EXISTS public.academic_subjects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    academic_structure_id UUID,
    academic_period_id UUID REFERENCES public.academic_periods(id) ON DELETE SET NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    code TEXT,
    description TEXT,
    order_index INTEGER DEFAULT 0,
    is_archived BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_academic_subjects_user_updated ON public.academic_subjects(user_id, updated_at);

-- 5. Folders Table
CREATE TABLE IF NOT EXISTS public.folders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    workspace_id UUID REFERENCES public.workspaces(id) ON DELETE CASCADE,
    academic_period_id UUID REFERENCES public.academic_periods(id) ON DELETE SET NULL,
    subject_id UUID REFERENCES public.academic_subjects(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES public.folders(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    order_index INTEGER DEFAULT 0,
    is_archived BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_folders_user_updated ON public.folders(user_id, updated_at);

-- 6. Materials Table (Universal Library)
CREATE TABLE IF NOT EXISTS public.materials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    workspace_id UUID REFERENCES public.workspaces(id) ON DELETE SET NULL,
    academic_period_id UUID REFERENCES public.academic_periods(id) ON DELETE SET NULL,
    subject_id UUID REFERENCES public.academic_subjects(id) ON DELETE SET NULL,
    folder_id UUID REFERENCES public.folders(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    original_file_name TEXT,
    type TEXT NOT NULL, -- PDF, IMAGE, NOTE, DOCUMENT, LINK
    content TEXT,
    file_path TEXT,
    storage_path TEXT,
    mime_type TEXT,
    file_size BIGINT DEFAULT 0,
    remote_url TEXT,
    is_favorite BOOLEAN DEFAULT false,
    is_archived BOOLEAN DEFAULT false,
    is_inbox BOOLEAN DEFAULT false,
    source TEXT DEFAULT 'Manual',
    import_status TEXT DEFAULT 'imported',
    content_hash TEXT,
    last_opened_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_materials_user_updated ON public.materials(user_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_materials_user_inbox ON public.materials(user_id, is_inbox);
CREATE INDEX IF NOT EXISTS idx_materials_content_hash ON public.materials(content_hash);

-- 7. Labels Table
CREATE TABLE IF NOT EXISTS public.labels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    workspace_id UUID REFERENCES public.workspaces(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    color_hex TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_labels_user_updated ON public.labels(user_id, updated_at);

-- 8. Material Labels Association Table
CREATE TABLE IF NOT EXISTS public.material_labels (
    material_id UUID NOT NULL REFERENCES public.materials(id) ON DELETE CASCADE,
    label_id UUID NOT NULL REFERENCES public.labels(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    PRIMARY KEY (material_id, label_id)
);

-- 9. Personal Topics Table
CREATE TABLE IF NOT EXISTS public.personal_topics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    order_index INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_personal_topics_user_updated ON public.personal_topics(user_id, updated_at);

-- ============================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- Strict User Isolation: users can only access their own records
-- ============================================================

ALTER TABLE public.workspaces ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own workspaces" ON public.workspaces
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

ALTER TABLE public.academic_years ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own academic years" ON public.academic_years
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

ALTER TABLE public.academic_periods ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own academic periods" ON public.academic_periods
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

ALTER TABLE public.academic_subjects ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own subjects" ON public.academic_subjects
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

ALTER TABLE public.folders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own folders" ON public.folders
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

ALTER TABLE public.materials ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own materials" ON public.materials
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

ALTER TABLE public.labels ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own labels" ON public.labels
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

ALTER TABLE public.material_labels ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own material labels" ON public.material_labels
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.materials m 
            WHERE m.id = material_labels.material_id AND m.user_id = auth.uid()
        )
    );

ALTER TABLE public.personal_topics ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own personal topics" ON public.personal_topics
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- STORAGE BUCKET: study_materials
-- ============================================================
INSERT INTO storage.buckets (id, name, public) 
VALUES ('study_materials', 'study_materials', false)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Users can upload study materials" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'study_materials' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can read own study materials" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'study_materials' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can update own study materials" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'study_materials' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can delete own study materials" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'study_materials' AND (storage.foldername(name))[1] = auth.uid()::text);
