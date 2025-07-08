// Simplified FCM Edge Function (Legacy API)
// Copy this content to Supabase Dashboard → Edge Functions

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface NotificationPayload {
  recipientId?: string
  title: string
  message: string
  data?: Record<string, any>
  fcmToken?: string
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const { recipientId, title, message, data, fcmToken } = await req.json() as NotificationPayload

    let finalFcmToken = fcmToken

    // If FCM token not provided, get it from database
    if (!finalFcmToken && recipientId) {
      const { data: profile, error: profileError } = await supabaseClient
        .from('profiles')
        .select('fcm_token')
        .eq('id', recipientId)
        .single()

      if (profileError || !profile?.fcm_token) {
        throw new Error('Recipient FCM token not found')
      }
      finalFcmToken = profile.fcm_token
    }

    if (!finalFcmToken) {
      throw new Error('No FCM token provided or found')
    }

    // Send notification via FCM Legacy API
    const fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `key=${Deno.env.get('FCM_SERVER_KEY')}`,
      },
      body: JSON.stringify({
        to: finalFcmToken,
        notification: {
          title,
          body: message,
          sound: 'default',
          badge: 1,
        },
        data: {
          ...data,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        priority: 'high',
      }),
    })

    const fcmResult = await fcmResponse.json()

    return new Response(
      JSON.stringify({ success: true, result: fcmResult }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 },
    )
  }
})