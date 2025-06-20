# Fixed RPC Function for Uploaded Files

```sql
CREATE OR REPLACE FUNCTION get_agent_campaign_details_fixed(p_campaign_id uuid, p_agent_id uuid)
RETURNS json
LANGUAGE sql
STABLE
AS $$
  SELECT
    jsonb_build_object(
      'earnings', (
        SELECT
          jsonb_build_object(
            'total_points', COALESCE(SUM(t.points), 0),
            'paid_points', COALESCE((SELECT SUM(p.amount) FROM public.payments p WHERE p.agent_id = p_agent_id AND p.campaign_id = p_campaign_id), 0)
          )
        FROM
          public.task_assignments ta
        JOIN
          public.tasks t ON ta.task_id = t.id
        WHERE
          ta.agent_id = p_agent_id AND
          t.campaign_id = p_campaign_id AND
          ta.status = 'completed'
      ),
      'tasks', (
        SELECT
          COALESCE(jsonb_agg(
            jsonb_build_object(
              'id', t.id,
              'title', t.title,
              'description', t.description,
              'points', t.points,
              'status', ta.status,
              'evidence_required', t.required_evidence_count,
              'evidence_uploaded', COALESCE(array_length(ta.evidence_urls, 1), 0)
            )
          ), '[]'::jsonb)
        FROM
          public.tasks t
        JOIN
          public.task_assignments ta ON t.id = ta.task_id
        WHERE
          t.campaign_id = p_campaign_id AND
          ta.agent_id = p_agent_id
      ),
      'files', (
        WITH evidence_files AS (
          SELECT 
            ta.id as assignment_id,
            t.title as task_title,
            evidence_url,
            COALESCE(ta.completed_at, ta.started_at, t.created_at) as file_date,
            ROW_NUMBER() OVER (PARTITION BY ta.id ORDER BY evidence_url) as file_index
          FROM
            public.task_assignments ta
          JOIN
            public.tasks t ON ta.task_id = t.id
          CROSS JOIN LATERAL unnest(COALESCE(ta.evidence_urls, ARRAY[]::text[])) AS evidence_url
          WHERE
            ta.agent_id = p_agent_id AND
            t.campaign_id = p_campaign_id AND
            ta.evidence_urls IS NOT NULL AND
            array_length(ta.evidence_urls, 1) > 0
        )
        SELECT
          COALESCE(jsonb_agg(
            jsonb_build_object(
              'id', assignment_id || '_' || file_index::text,
              'title', 'Evidence ' || file_index::text,
              'file_url', evidence_url,
              'created_at', file_date,
              'task_title', task_title
            ) ORDER BY file_date DESC
          ), '[]'::jsonb)
        FROM evidence_files
      )
    )
$$;
```