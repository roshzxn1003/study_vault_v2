-- ============================================================
-- STUDY VAULT — PHASE 9 SUPABASE MIGRATION
-- Student Sharing, Study Groups, Study Packs & Collaboration Schema
-- ============================================================

-- 1. Profiles Table for Student Identity & Discovery
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

-- Secure Profiles RLS:
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

-- Automatically create profile on user signup
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

-- 2. Student Sharing Table (1-to-1 Sharing, Expiry, Status & Permissions)
CREATE TABLE IF NOT EXISTS public.shares (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    recipient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    resource_type TEXT NOT NULL DEFAULT 'material', -- 'material', 'folder', 'study_pack'
    resource_id UUID NOT NULL,
    permission TEXT NOT NULL DEFAULT 'view', -- 'view', 'download', 'save_copy'
    status TEXT NOT NULL DEFAULT 'active', -- 'pending', 'accepted', 'active', 'expired', 'revoked'
    message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_shares_owner ON public.shares(owner_id, status);
CREATE INDEX IF NOT EXISTS idx_shares_recipient ON public.shares(recipient_id, status);
CREATE INDEX IF NOT EXISTS idx_shares_resource ON public.shares(resource_id, status);
-- Prevent duplicate active shares for identical owner, recipient, and resource
CREATE UNIQUE INDEX IF NOT EXISTS idx_shares_unique_active 
    ON public.shares(owner_id, recipient_id, resource_id) 
    WHERE status = 'active';

ALTER TABLE public.shares ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view shares involving them" ON public.shares;
CREATE POLICY "Users can view shares involving them" ON public.shares
    FOR SELECT TO authenticated
    USING (auth.uid() = owner_id OR auth.uid() = recipient_id);

DROP POLICY IF EXISTS "Users can create shares as owner" ON public.shares;
CREATE POLICY "Users can create shares as owner" ON public.shares
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Owners can update their shares" ON public.shares;
CREATE POLICY "Owners can update their shares" ON public.shares
    FOR UPDATE TO authenticated
    USING (auth.uid() = owner_id OR auth.uid() = recipient_id)
    WITH CHECK (auth.uid() = owner_id OR auth.uid() = recipient_id);

DROP POLICY IF EXISTS "Owners can delete their shares" ON public.shares;
CREATE POLICY "Owners can delete their shares" ON public.shares
    FOR DELETE TO authenticated
    USING (auth.uid() = owner_id);

-- 3. Study Groups Table
CREATE TABLE IF NOT EXISTS public.study_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_study_groups_owner ON public.study_groups(owner_id);

ALTER TABLE public.study_groups ENABLE ROW LEVEL SECURITY;

-- 4. Group Members Table
CREATE TABLE IF NOT EXISTS public.group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.study_groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member', -- 'owner', 'moderator', 'member'
    status TEXT NOT NULL DEFAULT 'invited', -- 'active', 'invited', 'declined'
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    joined_at TIMESTAMPTZ,
    UNIQUE(group_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_group_members_group ON public.group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user ON public.group_members(user_id, status);

ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;

-- Group RLS Policies
DROP POLICY IF EXISTS "Members can view their groups" ON public.study_groups;
CREATE POLICY "Members can view their groups" ON public.study_groups
    FOR SELECT TO authenticated
    USING (
        auth.uid() = owner_id OR 
        EXISTS (
            SELECT 1 FROM public.group_members gm 
            WHERE gm.group_id = public.study_groups.id 
            AND gm.user_id = auth.uid() 
            AND gm.status IN ('active', 'invited')
        )
    );

DROP POLICY IF EXISTS "Owners can create study groups" ON public.study_groups;
CREATE POLICY "Owners can create study groups" ON public.study_groups
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Owners can update study groups" ON public.study_groups;
CREATE POLICY "Owners can update study groups" ON public.study_groups
    FOR UPDATE TO authenticated
    USING (auth.uid() = owner_id)
    WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Owners can delete study groups" ON public.study_groups;
CREATE POLICY "Owners can delete study groups" ON public.study_groups
    FOR DELETE TO authenticated
    USING (auth.uid() = owner_id);

-- Group Members RLS Policies
DROP POLICY IF EXISTS "Members and owners can view group members" ON public.group_members;
CREATE POLICY "Members and owners can view group members" ON public.group_members
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.study_groups sg
            WHERE sg.id = group_members.group_id AND sg.owner_id = auth.uid()
        ) OR
        EXISTS (
            SELECT 1 FROM public.group_members gm2
            WHERE gm2.group_id = group_members.group_id AND gm2.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Owners can add or invite group members" ON public.group_members;
CREATE POLICY "Owners can add or invite group members" ON public.group_members
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.study_groups sg
            WHERE sg.id = group_members.group_id AND sg.owner_id = auth.uid()
        ) OR auth.uid() = user_id
    );

DROP POLICY IF EXISTS "Members can update their own status or owner can update roles" ON public.group_members;
CREATE POLICY "Members can update their own status or owner can update roles" ON public.group_members
    FOR UPDATE TO authenticated
    USING (
        auth.uid() = user_id OR
        EXISTS (
            SELECT 1 FROM public.study_groups sg
            WHERE sg.id = group_members.group_id AND sg.owner_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Members can leave or owner can remove" ON public.group_members;
CREATE POLICY "Members can leave or owner can remove" ON public.group_members
    FOR DELETE TO authenticated
    USING (
        auth.uid() = user_id OR
        EXISTS (
            SELECT 1 FROM public.study_groups sg
            WHERE sg.id = group_members.group_id AND sg.owner_id = auth.uid()
        )
    );

-- 5. Group Resources Table (Reference-only, avoids duplicate physical storage)
CREATE TABLE IF NOT EXISTS public.group_resources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.study_groups(id) ON DELETE CASCADE,
    resource_id UUID NOT NULL REFERENCES public.materials(id) ON DELETE CASCADE,
    resource_type TEXT NOT NULL DEFAULT 'material',
    shared_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    permission TEXT NOT NULL DEFAULT 'view',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ,
    UNIQUE(group_id, resource_id)
);

CREATE INDEX IF NOT EXISTS idx_group_resources_group ON public.group_resources(group_id);

ALTER TABLE public.group_resources ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Active group members can view group resources" ON public.group_resources;
CREATE POLICY "Active group members can view group resources" ON public.group_resources
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.group_members gm 
            WHERE gm.group_id = group_resources.group_id 
            AND gm.user_id = auth.uid() 
            AND gm.status = 'active'
        ) OR
        EXISTS (
            SELECT 1 FROM public.study_groups sg
            WHERE sg.id = group_resources.group_id AND sg.owner_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Active group members can share resources to group" ON public.group_resources;
CREATE POLICY "Active group members can share resources to group" ON public.group_resources
    FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() = shared_by AND
        (
            EXISTS (
                SELECT 1 FROM public.group_members gm 
                WHERE gm.group_id = group_resources.group_id 
                AND gm.user_id = auth.uid() 
                AND gm.status = 'active'
            ) OR
            EXISTS (
                SELECT 1 FROM public.study_groups sg
                WHERE sg.id = group_resources.group_id AND sg.owner_id = auth.uid()
            )
        )
    );

DROP POLICY IF EXISTS "Sharer or group owner can remove shared resource" ON public.group_resources;
CREATE POLICY "Sharer or group owner can remove shared resource" ON public.group_resources
    FOR DELETE TO authenticated
    USING (
        auth.uid() = shared_by OR
        EXISTS (
            SELECT 1 FROM public.study_groups sg
            WHERE sg.id = group_resources.group_id AND sg.owner_id = auth.uid()
        )
    );

-- 6. Study Packs Table
CREATE TABLE IF NOT EXISTS public.study_packs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_study_packs_owner ON public.study_packs(owner_id);

ALTER TABLE public.study_packs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view accessible study packs" ON public.study_packs;
CREATE POLICY "Users can view accessible study packs" ON public.study_packs
    FOR SELECT TO authenticated
    USING (
        auth.uid() = owner_id OR
        EXISTS (
            SELECT 1 FROM public.shares s 
            WHERE s.resource_id = public.study_packs.id 
            AND s.recipient_id = auth.uid() 
            AND s.status = 'active'
            AND (s.expires_at IS NULL OR s.expires_at > now())
            AND s.revoked_at IS NULL
        )
    );

DROP POLICY IF EXISTS "Users can manage own study packs" ON public.study_packs;
CREATE POLICY "Users can manage own study packs" ON public.study_packs
    FOR ALL TO authenticated
    USING (auth.uid() = owner_id)
    WITH CHECK (auth.uid() = owner_id);

-- 7. Study Pack Items Association Table
CREATE TABLE IF NOT EXISTS public.study_pack_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    study_pack_id UUID NOT NULL REFERENCES public.study_packs(id) ON DELETE CASCADE,
    material_id UUID NOT NULL REFERENCES public.materials(id) ON DELETE CASCADE,
    order_index INTEGER DEFAULT 0,
    UNIQUE(study_pack_id, material_id)
);

CREATE INDEX IF NOT EXISTS idx_study_pack_items_pack ON public.study_pack_items(study_pack_id);

ALTER TABLE public.study_pack_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view items of accessible study packs" ON public.study_pack_items;
CREATE POLICY "Users can view items of accessible study packs" ON public.study_pack_items
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.study_packs sp
            WHERE sp.id = study_pack_items.study_pack_id AND (
                sp.owner_id = auth.uid() OR
                EXISTS (
                    SELECT 1 FROM public.shares s 
                    WHERE s.resource_id = sp.id 
                    AND s.recipient_id = auth.uid() 
                    AND s.status = 'active'
                    AND (s.expires_at IS NULL OR s.expires_at > now())
                    AND s.revoked_at IS NULL
                )
            )
        )
    );

DROP POLICY IF EXISTS "Pack owners can manage pack items" ON public.study_pack_items;
CREATE POLICY "Pack owners can manage pack items" ON public.study_pack_items
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.study_packs sp
            WHERE sp.id = study_pack_items.study_pack_id AND sp.owner_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.study_packs sp
            WHERE sp.id = study_pack_items.study_pack_id AND sp.owner_id = auth.uid()
        )
    );

-- 8. Share Notifications Table
CREATE TABLE IF NOT EXISTS public.share_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL, -- 'material_shared', 'pack_shared', 'group_invitation', 'group_accepted', 'share_expiring', 'share_expired'
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    reference_id TEXT,
    reference_type TEXT,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_share_notifications_user_read ON public.share_notifications(user_id, is_read, created_at DESC);

ALTER TABLE public.share_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their notifications" ON public.share_notifications;
CREATE POLICY "Users can view their notifications" ON public.share_notifications
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Authenticated users can create notifications for others" ON public.share_notifications;
CREATE POLICY "Authenticated users can create notifications for others" ON public.share_notifications
    FOR INSERT TO authenticated
    WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can update their notifications (e.g. mark read)" ON public.share_notifications;
CREATE POLICY "Users can update their notifications (e.g. mark read)" ON public.share_notifications
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their notifications" ON public.share_notifications;
CREATE POLICY "Users can delete their notifications" ON public.share_notifications
    FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

-- 9. Enforce Shared Read Access on Materials while Protecting Owner Isolation
-- Recipients of active, unexpired, non-revoked shares or active group resources can READ materials,
-- but only the owner can modify or delete their materials.
DROP POLICY IF EXISTS "Users can manage own materials" ON public.materials;
DROP POLICY IF EXISTS "Users can select own or permitted shared materials" ON public.materials;
DROP POLICY IF EXISTS "Owners can modify own materials" ON public.materials;

CREATE POLICY "Users can select own or permitted shared materials" ON public.materials
    FOR SELECT TO authenticated
    USING (
        auth.uid() = user_id OR
        EXISTS (
            SELECT 1 FROM public.shares s
            WHERE s.resource_id = public.materials.id
            AND s.recipient_id = auth.uid()
            AND s.status = 'active'
            AND (s.expires_at IS NULL OR s.expires_at > now())
            AND s.revoked_at IS NULL
        ) OR
        EXISTS (
            SELECT 1 FROM public.group_resources gr
            JOIN public.group_members gm ON gm.group_id = gr.group_id
            WHERE gr.resource_id = public.materials.id
            AND gm.user_id = auth.uid()
            AND gm.status = 'active'
            AND (gr.expires_at IS NULL OR gr.expires_at > now())
        )
    );

CREATE POLICY "Owners can modify own materials" ON public.materials
    FOR ALL TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
