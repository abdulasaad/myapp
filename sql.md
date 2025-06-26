# Universal Task Template System - Database Migration

This file contains all SQL commands for implementing the professional task template system in Al-Tijwal. Copy and paste these commands into your Supabase SQL Editor.

## Geofence RPC Function for Template Tasks

```sql
-- Create RPC function to insert geofence with proper PostGIS geometry conversion
CREATE OR REPLACE FUNCTION insert_task_geofence(
    task_id_param UUID,
    geofence_name TEXT,
    wkt_polygon TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO geofences (task_id, name, area, area_text) 
    VALUES (
        task_id_param, 
        geofence_name, 
        ST_GeomFromText(wkt_polygon, 4326), 
        wkt_polygon
    );
END;
$$;

-- Grant access to authenticated users
GRANT EXECUTE ON FUNCTION insert_task_geofence(UUID, TEXT, TEXT) TO authenticated;
```

## 1. Template Categories Table

```sql
-- Create template categories table
CREATE TABLE IF NOT EXISTS public.template_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    icon_name TEXT NOT NULL DEFAULT 'category',
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Add RLS policies for template categories
ALTER TABLE public.template_categories ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read categories
CREATE POLICY "Allow authenticated users to read template categories"
ON public.template_categories
FOR SELECT
TO authenticated
USING (is_active = true);

-- Only admins can manage categories
CREATE POLICY "Only admins can manage template categories"
ON public.template_categories
FOR ALL
TO authenticated
USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin')
WITH CHECK ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_template_categories_sort_order ON public.template_categories(sort_order);
CREATE INDEX IF NOT EXISTS idx_template_categories_active ON public.template_categories(is_active);
```

## 2. Task Templates Table

```sql
-- Create task templates table
CREATE TABLE IF NOT EXISTS public.task_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category_id UUID REFERENCES public.template_categories(id) ON DELETE CASCADE,
    description TEXT,
    default_points INTEGER DEFAULT 10,
    requires_geofence BOOLEAN DEFAULT false,
    default_evidence_count INTEGER DEFAULT 1,
    template_config JSONB NOT NULL DEFAULT '{}',
    evidence_types JSONB DEFAULT '["image"]'::jsonb,
    custom_instructions TEXT,
    estimated_duration INTEGER, -- in minutes
    difficulty_level TEXT DEFAULT 'medium' CHECK (difficulty_level IN ('easy', 'medium', 'hard')),
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Add RLS policies for task templates
ALTER TABLE public.task_templates ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read active templates
CREATE POLICY "Allow authenticated users to read active task templates"
ON public.task_templates
FOR SELECT
TO authenticated
USING (is_active = true);

-- Only admins can manage templates
CREATE POLICY "Only admins can manage task templates"
ON public.task_templates
FOR ALL
TO authenticated
USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin')
WITH CHECK ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_task_templates_category ON public.task_templates(category_id);
CREATE INDEX IF NOT EXISTS idx_task_templates_active ON public.task_templates(is_active);
CREATE INDEX IF NOT EXISTS idx_task_templates_difficulty ON public.task_templates(difficulty_level);
```

## 3. Template Fields Table

```sql
-- Create template fields table for custom fields
CREATE TABLE IF NOT EXISTS public.template_fields (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID REFERENCES public.task_templates(id) ON DELETE CASCADE,
    field_name TEXT NOT NULL,
    field_type TEXT NOT NULL CHECK (field_type IN ('text', 'number', 'date', 'boolean', 'select', 'multiselect', 'textarea', 'email', 'phone')),
    field_label TEXT NOT NULL,
    placeholder_text TEXT,
    is_required BOOLEAN DEFAULT false,
    field_options JSONB, -- For select/multiselect types
    validation_rules JSONB DEFAULT '{}',
    sort_order INTEGER DEFAULT 0,
    help_text TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Add RLS policies for template fields
ALTER TABLE public.template_fields ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read template fields
CREATE POLICY "Allow authenticated users to read template fields"
ON public.template_fields
FOR SELECT
TO authenticated
USING (true);

-- Only admins can manage template fields
CREATE POLICY "Only admins can manage template fields"
ON public.template_fields
FOR ALL
TO authenticated
USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin')
WITH CHECK ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_template_fields_template ON public.template_fields(template_id);
CREATE INDEX IF NOT EXISTS idx_template_fields_sort_order ON public.template_fields(template_id, sort_order);
```

## 4. Enhanced Tasks Table

```sql
-- Add template-related columns to existing tasks table
ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS template_id UUID REFERENCES public.task_templates(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS custom_fields JSONB DEFAULT '{}',
ADD COLUMN IF NOT EXISTS template_version INTEGER DEFAULT 1;

-- Create index for template-based tasks
CREATE INDEX IF NOT EXISTS idx_tasks_template ON public.tasks(template_id);
```

## 5. Template Usage Analytics Table

```sql
-- Create table to track template usage for analytics
CREATE TABLE IF NOT EXISTS public.template_usage_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID REFERENCES public.task_templates(id) ON DELETE CASCADE,
    task_id UUID REFERENCES public.tasks(id) ON DELETE CASCADE,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    completion_time INTEGER, -- in minutes, set when task completed
    success_rate NUMERIC(3,2), -- 0.00 to 1.00
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    completed_at TIMESTAMPTZ
);

-- Add RLS policies for analytics
ALTER TABLE public.template_usage_analytics ENABLE ROW LEVEL SECURITY;

-- Only admins can read analytics
CREATE POLICY "Only admins can read template analytics"
ON public.template_usage_analytics
FOR SELECT
TO authenticated
USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- System can insert analytics data
CREATE POLICY "Allow system to insert template analytics"
ON public.template_usage_analytics
FOR INSERT
TO authenticated
WITH CHECK (true);

-- System can update completion data
CREATE POLICY "Allow system to update template analytics"
ON public.template_usage_analytics
FOR UPDATE
TO authenticated
USING (true);

-- Create indexes for analytics queries
CREATE INDEX IF NOT EXISTS idx_template_analytics_template ON public.template_usage_analytics(template_id);
CREATE INDEX IF NOT EXISTS idx_template_analytics_created_at ON public.template_usage_analytics(created_at);
```

## 6. Update Triggers for Timestamps

```sql
-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add triggers for timestamp updates
DROP TRIGGER IF EXISTS template_categories_update_trigger ON public.template_categories;
CREATE TRIGGER template_categories_update_trigger
    BEFORE UPDATE ON public.template_categories
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_timestamp();

DROP TRIGGER IF EXISTS task_templates_update_trigger ON public.task_templates;
CREATE TRIGGER task_templates_update_trigger
    BEFORE UPDATE ON public.task_templates
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_timestamp();
```

## 7. Insert Default Template Categories

```sql
-- Insert default template categories
INSERT INTO public.template_categories (name, description, icon_name, sort_order) VALUES
('Business Development', 'Client visits, lead generation, and relationship building tasks', 'business', 1),
('Sales & Orders', 'Product demonstrations, order collection, and contract management', 'shopping_cart', 2),
('Service & Support', 'Customer service, installation, maintenance, and training tasks', 'support_agent', 3),
('Compliance & Audit', 'Compliance checks, inventory audits, and quality assurance', 'verified', 4),
('Operations', 'Delivery, collection, surveys, and inspection tasks', 'local_shipping', 5),
('Marketing', 'Promotional activities, market research, and brand awareness', 'campaign', 6)
ON CONFLICT (name) DO NOTHING;
```

## 8. Insert Sample Task Templates

```sql
-- Get category IDs for inserting templates
DO $$
DECLARE
    business_dev_id UUID;
    sales_orders_id UUID;
    service_support_id UUID;
    compliance_audit_id UUID;
    operations_id UUID;
    marketing_id UUID;
BEGIN
    -- Get category IDs
    SELECT id INTO business_dev_id FROM public.template_categories WHERE name = 'Business Development';
    SELECT id INTO sales_orders_id FROM public.template_categories WHERE name = 'Sales & Orders';
    SELECT id INTO service_support_id FROM public.template_categories WHERE name = 'Service & Support';
    SELECT id INTO compliance_audit_id FROM public.template_categories WHERE name = 'Compliance & Audit';
    SELECT id INTO operations_id FROM public.template_categories WHERE name = 'Operations';
    SELECT id INTO marketing_id FROM public.template_categories WHERE name = 'Marketing';

    -- Insert Business Development Templates
    INSERT INTO public.task_templates (name, category_id, description, default_points, requires_geofence, default_evidence_count, evidence_types, custom_instructions, estimated_duration, difficulty_level) VALUES
    ('Client Visit', business_dev_id, 'Document client meetings and relationship building activities', 15, true, 2, '["image", "document"]', 'Take photo with client, upload meeting summary document', 60, 'medium'),
    ('Lead Generation', business_dev_id, 'Prospect new clients and qualify leads', 10, false, 1, '["document"]', 'Submit lead information form with contact details', 30, 'easy'),
    ('Market Research', business_dev_id, 'Gather competitive intelligence and market insights', 20, true, 3, '["image", "document"]', 'Photo evidence of competitor presence, market analysis document', 90, 'medium');

    -- Insert Sales & Orders Templates
    INSERT INTO public.task_templates (name, category_id, description, default_points, requires_geofence, default_evidence_count, evidence_types, custom_instructions, estimated_duration, difficulty_level) VALUES
    ('Product Demonstration', sales_orders_id, 'Conduct product demos and presentations', 25, true, 2, '["video", "document"]', 'Record demonstration video, upload attendance sheet', 120, 'hard'),
    ('Order Collection', sales_orders_id, 'Process new orders and collect documentation', 20, true, 2, '["document", "image"]', 'Upload signed purchase order and payment confirmation', 45, 'medium'),
    ('Quote Preparation', sales_orders_id, 'Prepare and deliver price quotations', 10, false, 1, '["document"]', 'Submit detailed quote with pricing breakdown', 30, 'easy');

    -- Insert Service & Support Templates
    INSERT INTO public.task_templates (name, category_id, description, default_points, requires_geofence, default_evidence_count, evidence_types, custom_instructions, estimated_duration, difficulty_level) VALUES
    ('Customer Service', service_support_id, 'Handle customer support and issue resolution', 15, true, 2, '["image", "document"]', 'Document issue and resolution with photos and report', 60, 'medium'),
    ('Installation Task', service_support_id, 'Install products or services at client location', 30, true, 3, '["image", "video"]', 'Before/after photos, installation completion video', 180, 'hard'),
    ('Training Session', service_support_id, 'Conduct training for client staff', 25, true, 2, '["video", "document"]', 'Training session video, participant feedback forms', 120, 'hard');

    -- Insert Compliance & Audit Templates
    INSERT INTO public.task_templates (name, category_id, description, default_points, requires_geofence, default_evidence_count, evidence_types, custom_instructions, estimated_duration, difficulty_level) VALUES
    ('Compliance Check', compliance_audit_id, 'Verify regulatory compliance and standards', 20, true, 2, '["image", "document"]', 'Photo evidence of compliance, completed checklist', 75, 'medium'),
    ('Inventory Audit', compliance_audit_id, 'Audit inventory levels and stock management', 15, true, 3, '["image", "document"]', 'Stock level photos, inventory spreadsheet, reorder recommendations', 90, 'medium'),
    ('Quality Assurance', compliance_audit_id, 'Quality control and standards verification', 25, true, 2, '["image", "document"]', 'Quality assessment photos, QA report document', 60, 'hard');

    -- Insert Operations Templates
    INSERT INTO public.task_templates (name, category_id, description, default_points, requires_geofence, default_evidence_count, evidence_types, custom_instructions, estimated_duration, difficulty_level) VALUES
    ('Delivery Task', operations_id, 'Deliver products to client location', 10, true, 2, '["image", "document"]', 'Delivery photo, signed delivery receipt', 30, 'easy'),
    ('Collection Task', operations_id, 'Collect payments or documents from clients', 15, true, 1, '["document"]', 'Upload collection receipt or retrieved documents', 20, 'easy'),
    ('Survey Task', operations_id, 'Conduct customer surveys and feedback collection', 10, false, 1, '["document"]', 'Submit completed survey responses', 45, 'easy');

    -- Insert Marketing Templates
    INSERT INTO public.task_templates (name, category_id, description, default_points, requires_geofence, default_evidence_count, evidence_types, custom_instructions, estimated_duration, difficulty_level) VALUES
    ('Promotional Activity', marketing_id, 'Execute promotional campaigns and events', 20, true, 3, '["image", "video"]', 'Event photos, promotional materials, engagement video', 120, 'medium'),
    ('Brand Awareness', marketing_id, 'Increase brand visibility and awareness', 15, true, 2, '["image", "document"]', 'Campaign photos, reach metrics document', 60, 'medium'),
    ('Customer Feedback', marketing_id, 'Collect customer feedback and testimonials', 10, false, 1, '["document", "video"]', 'Feedback forms or testimonial videos', 30, 'easy');

END $$;
```

## 9. Sample Custom Fields for Templates

```sql
-- Add custom fields to some templates
DO $$
DECLARE
    client_visit_id UUID;
    product_demo_id UUID;
    inventory_audit_id UUID;
BEGIN
    -- Get template IDs
    SELECT id INTO client_visit_id FROM public.task_templates WHERE name = 'Client Visit';
    SELECT id INTO product_demo_id FROM public.task_templates WHERE name = 'Product Demonstration';
    SELECT id INTO inventory_audit_id FROM public.task_templates WHERE name = 'Inventory Audit';

    -- Add custom fields for Client Visit template
    INSERT INTO public.template_fields (template_id, field_name, field_type, field_label, placeholder_text, is_required, sort_order, help_text) VALUES
    (client_visit_id, 'client_name', 'text', 'Client Name', 'Enter client contact name', true, 1, 'Primary contact person for this visit'),
    (client_visit_id, 'meeting_purpose', 'select', 'Meeting Purpose', NULL, true, 2, 'Select the main purpose of this client visit'),
    (client_visit_id, 'follow_up_required', 'boolean', 'Follow-up Required', NULL, false, 3, 'Check if a follow-up meeting is needed'),
    (client_visit_id, 'next_meeting_date', 'date', 'Next Meeting Date', NULL, false, 4, 'Schedule the next meeting if follow-up is required');

    -- Add field options for meeting purpose
    UPDATE public.template_fields 
    SET field_options = '["Initial Meeting", "Product Presentation", "Contract Discussion", "Relationship Building", "Issue Resolution", "Routine Check-in"]'::jsonb
    WHERE template_id = client_visit_id AND field_name = 'meeting_purpose';

    -- Add custom fields for Product Demonstration template
    INSERT INTO public.template_fields (template_id, field_name, field_type, field_label, placeholder_text, is_required, sort_order, help_text) VALUES
    (product_demo_id, 'product_demonstrated', 'text', 'Product Demonstrated', 'Enter product name/model', true, 1, 'Specific product or service demonstrated'),
    (product_demo_id, 'attendee_count', 'number', 'Number of Attendees', '0', true, 2, 'Total number of people who attended the demo'),
    (product_demo_id, 'demo_rating', 'select', 'Demo Rating', NULL, false, 3, 'Rate the success of the demonstration'),
    (product_demo_id, 'questions_asked', 'textarea', 'Questions Asked', 'List key questions from attendees', false, 4, 'Document important questions and concerns raised');

    -- Add field options for demo rating
    UPDATE public.template_fields 
    SET field_options = '["Excellent", "Good", "Average", "Poor"]'::jsonb
    WHERE template_id = product_demo_id AND field_name = 'demo_rating';

    -- Add custom fields for Inventory Audit template
    INSERT INTO public.template_fields (template_id, field_name, field_type, field_label, placeholder_text, is_required, sort_order, help_text) VALUES
    (inventory_audit_id, 'stock_level', 'select', 'Overall Stock Level', NULL, true, 1, 'General assessment of inventory levels'),
    (inventory_audit_id, 'urgent_reorder', 'boolean', 'Urgent Reorder Needed', NULL, false, 2, 'Check if immediate restocking is required'),
    (inventory_audit_id, 'expiry_issues', 'boolean', 'Expiry Date Issues Found', NULL, false, 3, 'Check if any products are near expiry'),
    (inventory_audit_id, 'recommended_quantity', 'number', 'Recommended Reorder Quantity', '0', false, 4, 'Suggested quantity for restocking');

    -- Add field options for stock level
    UPDATE public.template_fields 
    SET field_options = '["Overstocked", "Well Stocked", "Low Stock", "Out of Stock"]'::jsonb
    WHERE template_id = inventory_audit_id AND field_name = 'stock_level';

END $$;
```

## 10. Helper Functions

```sql
-- Function to get templates by category
CREATE OR REPLACE FUNCTION get_templates_by_category(category_name TEXT)
RETURNS TABLE (
    template_id UUID,
    template_name TEXT,
    description TEXT,
    default_points INTEGER,
    requires_geofence BOOLEAN,
    difficulty_level TEXT,
    estimated_duration INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        tt.id,
        tt.name,
        tt.description,
        tt.default_points,
        tt.requires_geofence,
        tt.difficulty_level,
        tt.estimated_duration
    FROM task_templates tt
    JOIN template_categories tc ON tt.category_id = tc.id
    WHERE tc.name = category_name 
    AND tt.is_active = true
    ORDER BY tt.name;
END;
$$;

-- Function to get template with fields
CREATE OR REPLACE FUNCTION get_template_with_fields(template_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'template', row_to_json(tt.*),
        'fields', COALESCE(
            (SELECT jsonb_agg(tf.* ORDER BY tf.sort_order)
             FROM template_fields tf 
             WHERE tf.template_id = tt.id), 
            '[]'::jsonb
        )
    ) INTO result
    FROM task_templates tt
    WHERE tt.id = get_template_with_fields.template_id;
    
    RETURN result;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_templates_by_category(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_template_with_fields(UUID) TO authenticated;
```

## 11. Final Verification Queries

```sql
-- Verify all tables were created successfully
SELECT 
    schemaname,
    tablename,
    tableowner
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('template_categories', 'task_templates', 'template_fields', 'template_usage_analytics')
ORDER BY tablename;

-- Check template categories count
SELECT COUNT(*) as category_count FROM public.template_categories;

-- Check task templates count
SELECT COUNT(*) as template_count FROM public.task_templates;

-- Check template fields count
SELECT COUNT(*) as field_count FROM public.template_fields;

-- Verify RLS policies
SELECT schemaname, tablename, policyname, permissive
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename LIKE 'template%'
ORDER BY tablename, policyname;
```

---

## Summary

This SQL migration creates a comprehensive task template system with:

- ✅ **6 Template Categories** with 18 pre-built templates
- ✅ **Professional Database Schema** with proper indexing and RLS
- ✅ **Custom Fields System** for template flexibility
- ✅ **Usage Analytics** for performance tracking
- ✅ **Helper Functions** for efficient data retrieval
- ✅ **Sample Data** ready for immediate use

**Execute these commands in order in your Supabase SQL Editor to set up the complete template system.**