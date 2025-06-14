import "jsr:@supabase/functions-js/edge-runtime.d.ts";
// supabase/functions/create-user-admin/index.ts

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2'

interface UserCreationPayload {
  emailForAuth: string;
  password?: string; 
  userMetadata?: { [key: string]: any };
  fullNameForProfile: string;
  roleForProfile: 'agent' | 'manager';
  usernameForProfile?: string;
  emailForProfile?: string;
  agentCreationLimit?: number;
}

async function getCallingUserRole(userSupabaseClient: SupabaseClient): Promise<string | null> {
  const { data: { user }, error: userError } = await userSupabaseClient.auth.getUser();
  if (userError || !user) {
    console.error('Error fetching calling user for authorization:', userError?.message || 'No user found');
    return null;
  }
  const { data: roleData, error: rpcError } = await userSupabaseClient.rpc('get_my_role');
  if (rpcError) {
    console.error('Error calling get_my_role RPC:', rpcError.message);
    return null;
  }
  return roleData as string | null;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  console.log(`Received request: ${req.method} ${req.url}`);
  if (req.method === 'OPTIONS') {
    console.log('Handling OPTIONS preflight request.');
    return new Response('ok', { headers: corsHeaders });
  }

  // Environment variables are fetched here, inside the request handler.
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  console.log(`Retrieved from env: SUPABASE_URL is ${supabaseUrl ? 'set' : 'NOT SET'}, SUPABASE_ANON_KEY is ${supabaseAnonKey ? 'set' : 'NOT SET'}, SUPABASE_SERVICE_ROLE_KEY is ${serviceRoleKey ? 'set' : 'NOT SET'}`);

  if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey) {
    console.error('CRITICAL: One or more Supabase environment variables are missing.');
    return new Response(JSON.stringify({ error: 'Internal server configuration error: Missing Supabase credentials.' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
    });
  }

  if (req.method !== 'POST') {
    console.warn(`Method Not Allowed: ${req.method}`);
    return new Response(JSON.stringify({ error: 'Method Not Allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  let payload: UserCreationPayload;
  try {
    payload = await req.json();
    console.log('Request payload parsed successfully.');
  } catch (e: any) {
    console.error('Invalid JSON payload:', e.message);
    return new Response(JSON.stringify({ error: 'Invalid JSON payload: ' + e.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    console.warn('Missing Authorization header.');
    return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
  console.log('Authorization header present.');

  const userSupabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  console.log('User-scoped Supabase client created.');

  const callingUserRole = await getCallingUserRole(userSupabaseClient);
  const { data: { user: callingUser } } = await userSupabaseClient.auth.getUser(); 
  console.log(`Calling user role: ${callingUserRole}, Calling user ID: ${callingUser?.id}`);

  if (!callingUser) {
     console.warn('Could not identify calling user from token.');
     return new Response(JSON.stringify({ error: 'Could not identify calling user.' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  let authorizedToCreate = false;
  if (callingUserRole === 'admin') {
    authorizedToCreate = true;
  } else if (callingUserRole === 'manager' && payload.roleForProfile === 'agent') {
    authorizedToCreate = true;
  }
  console.log(`Authorized to create: ${authorizedToCreate}`);

  if (!authorizedToCreate) {
    console.warn(`Forbidden: Caller role '${callingUserRole}' not authorized to create role '${payload.roleForProfile}'.`);
    return new Response(JSON.stringify({ error: 'Forbidden: Caller is not authorized to perform this action.' }), {
      status: 403,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  console.log('Attempting to create supabaseAdmin client...');
  const supabaseAdmin = createClient(supabaseUrl!, serviceRoleKey!);
  console.log('supabaseAdmin client instance created.');

  const userMetadataForAuth = payload.userMetadata || { full_name: payload.fullNameForProfile };
  if (!userMetadataForAuth.full_name) userMetadataForAuth.full_name = payload.fullNameForProfile;

  console.log(`About to call supabaseAdmin.auth.admin.createUser for email: ${payload.emailForAuth}`);
  console.log('Simplified payload for createUser (excluding password, user_metadata, email_confirm):', { 
    email: payload.emailForAuth, 
  });

  try {
    const { data: authUserResponse, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: payload.emailForAuth,
      password: payload.password,
      // user_metadata: userMetadataForAuth, // Temporarily removed for testing
      // email_confirm: true, // Temporarily removed, will use project default
    });
    console.log('supabaseAdmin.auth.admin.createUser call completed (simplified).');

    if (authError) {
      console.error('Supabase auth.admin.createUser authError object:', JSON.stringify(authError, null, 2));
      console.error('Supabase auth.admin.createUser error message:', authError.message);
      return new Response(JSON.stringify({ error: authError.message || 'Failed to create user in auth due to authError' }), {
        status: (authError as any).status || 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (!authUserResponse || !authUserResponse.user) {
      console.error('User creation in auth did not return a user object or authUserResponse was null/undefined. Response:', JSON.stringify(authUserResponse, null, 2));
      return new Response(JSON.stringify({ error: 'User creation in auth returned unexpected data.' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const newUserId = authUserResponse.user.id;
    console.log(`New user ID from auth: ${newUserId}`);

    const profileDataToUpdate: any = {
      full_name: payload.fullNameForProfile,
      role: payload.roleForProfile,
      status: 'active',
    };

    if (payload.roleForProfile === 'agent') {
      if (!payload.usernameForProfile) {
        console.error('Attempted to create agent without username.');
        return new Response(JSON.stringify({ error: 'Username is required for agent role.' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      profileDataToUpdate.username = payload.usernameForProfile;
      if (callingUserRole === 'manager') {
        profileDataToUpdate.created_by = callingUser!.id;
      } else if (callingUserRole === 'admin') {
        profileDataToUpdate.created_by = null; 
      }
    } else if (payload.roleForProfile === 'manager') {
      profileDataToUpdate.email = payload.emailForProfile || payload.emailForAuth;
      profileDataToUpdate.agent_creation_limit = payload.agentCreationLimit ?? 0;
      if (callingUserRole === 'admin') {
        profileDataToUpdate.created_by = null;
      }
    }
    console.log(`Attempting to update profile for user ID ${newUserId} with data:`, JSON.stringify(profileDataToUpdate, null, 2));
    
    const { error: profileError } = await supabaseAdmin
      .from('profiles')
      .update(profileDataToUpdate)
      .eq('id', newUserId);
    console.log('Profile update call completed.');

    if (profileError) {
      console.error('Supabase profile update error object:', JSON.stringify(profileError, null, 2));
      console.error('Supabase profile update error message:', profileError.message);
      return new Response(JSON.stringify({ error: `Failed to update profile: ${profileError.message}` }), {
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    console.log(`User ${newUserId} created and profile updated successfully.`);
    return new Response(JSON.stringify({ message: 'User created and profile updated successfully', userId: newUserId }), {
      status: 201, 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (e: any) {
    console.error('EXCEPTION during user creation/profile update process:', e.message);
    console.error('Full exception object:', JSON.stringify(e, null, 2));
    return new Response(JSON.stringify({ error: 'Critical exception during user processing: ' + e.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
