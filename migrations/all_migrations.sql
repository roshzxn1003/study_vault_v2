-- ============================================================
-- STUDY VAULT — COMPLETE SUPABASE DATABASE SETUP
-- Single migration script for Auth, RAG Vector Search, Storage & Collaboration
-- ============================================================

-- 0. Enable pgvector extension for AI semantic search & RAG
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================
-- 1. USER PROFILES & AUTH TRIGGERS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    username TEXT UNIQUE,
    avatar_url TEXT,
    institution TEXT,
    degree TEXT,
    branch TEXT,
    semester TEXT,
    is_searchable BOOLEAN DEFAULT true,
    allow_group_invites TEXT DEFAULT 'anyone',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);
CREATE INDEX IF NOT EXISTS idx_profiles_searchable ON public.profiles(is_searchable);

DROP POLICY IF EXISTS "Users can view searchable profiles" ON public.profiles;
CREATE POLICY "Users can view searchable profiles" ON public.profiles
    FOR SELECT TO authenticated
    USING (is_searchable = true OR id = auth.uid());

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile" ON public.profiles
    FOR INSERT TO authenticated
    WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- Automatically create profile entry when a user registers via Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, username)
    VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data->>'full_name', ''),
        LOWER(SPLIT_PART(new.email, '@', 1)) || '_' || SUBSTRING(new.id::text, 1, 4)
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- User Preferences Table
CREATE TABLE IF NOT EXISTS public.user_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    preferred_language TEXT DEFAULT 'en',
    explanation_level TEXT DEFAULT 'Intermediate',
    voice_enabled BOOLEAN DEFAULT true,
    auto_read BOOLEAN DEFAULT false,
    speech_rate FLOAT DEFAULT 1.0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own preferences" ON public.user_preferences;
CREATE POLICY "Users can manage their own preferences" 
ON public.user_preferences FOR ALL 
USING (auth.uid() = user_id) 
WITH CHECK (auth.uid() = user_id);


-- ============================================================
-- 2. ACADEMIC VAULT (WORKSPACES, SUBJECTS, FOLDERS, MATERIALS, NOTES)
-- ============================================================

-- Workspaces
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

-- Academic Years
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

-- Semesters
CREATE TABLE IF NOT EXISTS public.semesters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    academic_year_id UUID NOT NULL REFERENCES public.academic_years(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    semester_name TEXT NOT NULL,
    is_current BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_semesters_user_updated ON public.semesters(user_id, updated_at);

-- Subjects
CREATE TABLE IF NOT EXISTS public.subjects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    semester_id UUID NOT NULL REFERENCES public.semesters(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    subject_name TEXT NOT NULL,
    subject_code TEXT,
    credits INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_subjects_user_updated ON public.subjects(user_id, updated_at);

-- Folders
CREATE TABLE IF NOT EXISTS public.folders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject_id UUID REFERENCES public.subjects(id) ON DELETE CASCADE,
    parent_folder_id UUID REFERENCES public.folders(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    folder_name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'notes',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_folders_user_updated ON public.folders(user_id, updated_at);

-- Materials (Files, PDFs, Documents)
CREATE TABLE IF NOT EXISTS public.materials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject_id UUID REFERENCES public.subjects(id) ON DELETE CASCADE,
    folder_id UUID REFERENCES public.folders(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    file_type TEXT NOT NULL,
    local_path TEXT,
    cloud_url TEXT,
    file_size_bytes BIGINT NOT NULL DEFAULT 0,
    unit_module TEXT,
    exam_tag TEXT,
    importance_level TEXT NOT NULL DEFAULT 'medium',
    is_favorite BOOLEAN DEFAULT false,
    indexed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_materials_user_updated ON public.materials(user_id, updated_at);

-- Notes (Markdown / Rich-text)
CREATE TABLE IF NOT EXISTS public.notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject_id UUID REFERENCES public.subjects(id) ON DELETE CASCADE,
    folder_id UUID REFERENCES public.folders(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content TEXT NOT NULL DEFAULT '',
    content_format TEXT NOT NULL DEFAULT 'markdown',
    summary TEXT,
    ai_generated BOOLEAN DEFAULT false,
    tags JSONB DEFAULT '[]'::jsonb,
    is_favorite BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_notes_user_updated ON public.notes(user_id, updated_at);

-- Study Images Table
CREATE TABLE IF NOT EXISTS public.study_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    folder_id UUID REFERENCES public.folders(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    storage_path TEXT NOT NULL,
    mime_type TEXT,
    extracted_text TEXT,
    ocr_confidence FLOAT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_study_images_user ON public.study_images(user_id);


-- ============================================================
-- 3. AI RAG & VECTOR SEARCH (DOCUMENT CHUNKS & PROCESSING)
-- ============================================================

-- Document Processing Status
CREATE TABLE IF NOT EXISTS public.document_processing (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_id UUID NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('uploaded', 'processing', 'completed', 'failed')),
    error_message TEXT,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_doc_proc_file_user ON public.document_processing(file_id, user_id);

-- Document Chunks for Embeddings
CREATE TABLE IF NOT EXISTS public.document_chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_id UUID NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,  
    chunk_index INTEGER NOT NULL,
    page_number INTEGER,
    token_count INTEGER,
    metadata JSONB,
    embedding vector(1536),
    created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_doc_chunks_file_user ON public.document_chunks(file_id, user_id);

-- Semantic Search RPC Function for AI RAG Tutor
CREATE OR REPLACE FUNCTION match_documents (
    query_embedding vector(1536),
    match_threshold float,
    match_count int
)
RETURNS TABLE (
    id UUID,
    file_id UUID,
    content TEXT,
    page_number int,
    similarity float,
    metadata JSONB,
    file_name TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        dc.id,
        dc.file_id,
        dc.content,
        dc.page_number,
        1 - (dc.embedding <=> query_embedding) AS similarity,
        dc.metadata,
        COALESCE(m.title, 'Document') as file_name
    FROM public.document_chunks dc
    LEFT JOIN public.materials m ON dc.file_id = m.id
    WHERE dc.user_id = auth.uid()
        AND 1 - (dc.embedding <=> query_embedding) > match_threshold
    ORDER BY dc.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;


-- ============================================================
-- 4. PEER SHARING, STUDY GROUPS & STUDY PACKS (PHASE 9)
-- ============================================================

-- Student Direct Sharing
CREATE TABLE IF NOT EXISTS public.shares (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    recipient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    resource_type TEXT NOT NULL DEFAULT 'material',
    resource_id UUID NOT NULL,
    permission TEXT NOT NULL DEFAULT 'view',
    status TEXT NOT NULL DEFAULT 'active',
    message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_shares_owner ON public.shares(owner_id);
CREATE INDEX IF NOT EXISTS idx_shares_recipient ON public.shares(recipient_id);

-- Study Groups
CREATE TABLE IF NOT EXISTS public.study_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    subject TEXT,
    invite_code TEXT UNIQUE NOT NULL,
    is_public BOOLEAN DEFAULT false,
    member_limit INTEGER DEFAULT 50,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_groups_owner ON public.study_groups(owner_id);
CREATE INDEX IF NOT EXISTS idx_groups_invite ON public.study_groups(invite_code);

-- Group Members
CREATE TABLE IF NOT EXISTS public.group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.study_groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(group_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_group_members_group ON public.group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user ON public.group_members(user_id);

-- Group Resources
CREATE TABLE IF NOT EXISTS public.group_resources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.study_groups(id) ON DELETE CASCADE,
    added_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    resource_type TEXT NOT NULL DEFAULT 'material',
    resource_id UUID NOT NULL,
    title TEXT NOT NULL,
    unit_module TEXT,
    cloud_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_group_resources_group ON public.group_resources(group_id);

-- Study Packs
CREATE TABLE IF NOT EXISTS public.study_packs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    subject TEXT,
    unit_module TEXT,
    is_public BOOLEAN DEFAULT false,
    qr_code_payload TEXT,
    download_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_study_packs_creator ON public.study_packs(creator_id);

-- Study Pack Items
CREATE TABLE IF NOT EXISTS public.study_pack_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pack_id UUID NOT NULL REFERENCES public.study_packs(id) ON DELETE CASCADE,
    resource_type TEXT NOT NULL DEFAULT 'material',
    resource_id UUID NOT NULL,
    title TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pack_items_pack ON public.study_pack_items(pack_id);

-- Share Notifications
CREATE TABLE IF NOT EXISTS public.share_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    payload JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.share_notifications(user_id, is_read);


-- ============================================================
-- 5. ROW LEVEL SECURITY (RLS) POLICIES FOR ALL TABLES
-- ============================================================

-- Workspaces
ALTER TABLE public.workspaces ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users own workspaces" ON public.workspaces;
CREATE POLICY "Users own workspaces" ON public.workspaces FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Academic Years
ALTER TABLE public.academic_years ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users own academic years" ON public.academic_years;
CREATE POLICY "Users own academic years" ON public.academic_years FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Semesters
ALTER TABLE public.semesters ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users own semesters" ON public.semesters;
CREATE POLICY "Users own semesters" ON public.semesters FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Subjects
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users own subjects" ON public.subjects;
CREATE POLICY "Users own subjects" ON public.subjects FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Folders
ALTER TABLE public.folders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users own folders" ON public.folders;
CREATE POLICY "Users own folders" ON public.folders FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Materials
ALTER TABLE public.materials ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users own materials" ON public.materials;
CREATE POLICY "Users own materials" ON public.materials FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Notes
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users own notes" ON public.notes;
CREATE POLICY "Users own notes" ON public.notes FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Study Images
ALTER TABLE public.study_images ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users own study images" ON public.study_images;
CREATE POLICY "Users own study images" ON public.study_images FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Document Processing & Chunks
ALTER TABLE public.document_processing ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users own document processing" ON public.document_processing;
CREATE POLICY "Users own document processing" ON public.document_processing FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

ALTER TABLE public.document_chunks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users own document chunks" ON public.document_chunks;
CREATE POLICY "Users own document chunks" ON public.document_chunks FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Shares
ALTER TABLE public.shares ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view shares they sent or received" ON public.shares;
CREATE POLICY "Users can view shares they sent or received" ON public.shares FOR SELECT USING (auth.uid() = owner_id OR auth.uid() = recipient_id);
DROP POLICY IF EXISTS "Users can create shares" ON public.shares;
CREATE POLICY "Users can create shares" ON public.shares FOR INSERT WITH CHECK (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Users can update their shares" ON public.shares;
CREATE POLICY "Users can update their shares" ON public.shares FOR UPDATE USING (auth.uid() = owner_id OR auth.uid() = recipient_id);

-- Helper function to break mutual RLS recursion between study_groups and group_members
CREATE OR REPLACE FUNCTION public.is_member_or_owner(p_group_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.group_members 
        WHERE group_id = p_group_id AND user_id = auth.uid()
    ) OR EXISTS (
        SELECT 1 FROM public.study_groups 
        WHERE id = p_group_id AND owner_id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Study Groups & Members
ALTER TABLE public.study_groups ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members can view study groups" ON public.study_groups;
CREATE POLICY "Members can view study groups" ON public.study_groups FOR SELECT USING (
    is_public = true 
    OR auth.uid() = owner_id 
    OR public.is_member_or_owner(id)
);
DROP POLICY IF EXISTS "Users can create groups" ON public.study_groups;
CREATE POLICY "Users can create groups" ON public.study_groups FOR INSERT WITH CHECK (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owners can update groups" ON public.study_groups;
CREATE POLICY "Owners can update groups" ON public.study_groups FOR UPDATE USING (auth.uid() = owner_id);

ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Group members can view other members" ON public.group_members;
CREATE POLICY "Group members can view other members" ON public.group_members FOR SELECT USING (
    user_id = auth.uid() 
    OR public.is_member_or_owner(group_id)
);
DROP POLICY IF EXISTS "Join group as member" ON public.group_members;
CREATE POLICY "Join group as member" ON public.group_members FOR INSERT WITH CHECK (auth.uid() = user_id);

ALTER TABLE public.group_resources ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members view group resources" ON public.group_resources;
CREATE POLICY "Members view group resources" ON public.group_resources FOR SELECT USING (
    public.is_member_or_owner(group_id)
);
DROP POLICY IF EXISTS "Members add group resources" ON public.group_resources;
CREATE POLICY "Members add group resources" ON public.group_resources FOR INSERT WITH CHECK (auth.uid() = added_by);

-- Study Packs
ALTER TABLE public.study_packs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "View study packs" ON public.study_packs;
CREATE POLICY "View study packs" ON public.study_packs FOR SELECT USING (is_public = true OR auth.uid() = creator_id);
DROP POLICY IF EXISTS "Create study pack" ON public.study_packs;
CREATE POLICY "Create study pack" ON public.study_packs FOR INSERT WITH CHECK (auth.uid() = creator_id);
DROP POLICY IF EXISTS "Update study pack" ON public.study_packs;
CREATE POLICY "Update study pack" ON public.study_packs FOR UPDATE USING (auth.uid() = creator_id);

ALTER TABLE public.study_pack_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "View pack items" ON public.study_pack_items;
CREATE POLICY "View pack items" ON public.study_pack_items FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.study_packs sp WHERE sp.id = pack_id AND (sp.is_public = true OR sp.creator_id = auth.uid()))
);
DROP POLICY IF EXISTS "Add pack items" ON public.study_pack_items;
CREATE POLICY "Add pack items" ON public.study_pack_items FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.study_packs sp WHERE sp.id = pack_id AND sp.creator_id = auth.uid())
);

-- Notifications
ALTER TABLE public.share_notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users own notifications" ON public.share_notifications;
CREATE POLICY "Users own notifications" ON public.share_notifications FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
