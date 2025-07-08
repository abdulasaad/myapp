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

    // Use service account key for v1 API
    const serviceAccountKey = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_KEY')
    if (!serviceAccountKey) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_KEY environment variable not set')
    }

    const serviceAccount = JSON.parse(serviceAccountKey)
    const projectId = serviceAccount.project_id

    if (!projectId) {
      throw new Error('Firebase project ID not found in service account key')
    }

    // Get access token using Google's token endpoint directly
    const accessToken = await getAccessToken(serviceAccount)

    // Send notification via FCM v1 API
    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: finalFcmToken,
            notification: {
              title,
              body: message,
            },
            data: data || {},
            android: {
              priority: 'high',
              notification: {
                sound: 'default',
                notification_count: 1,
              },
            },
            apns: {
              payload: {
                aps: {
                  badge: 1,
                  sound: 'default',
                },
              },
            },
          },
        }),
      }
    )

    const fcmResult = await fcmResponse.json()

    if (!fcmResponse.ok) {
      throw new Error(`FCM API error: ${JSON.stringify(fcmResult)}`)
    }

    return new Response(
      JSON.stringify({ success: true, result: fcmResult }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (error) {
    console.error('Push notification error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 },
    )
  }
})

// Get OAuth 2.0 access token for service account
async function getAccessToken(serviceAccount: any): Promise<string> {
  try {
    console.log('Creating JWT for service account:', serviceAccount.client_email)
    
    const now = Math.floor(Date.now() / 1000)
    const oneHour = 3600

    const payload = {
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + oneHour,
    }

    // Create JWT header and payload
    const header = { alg: 'RS256', typ: 'JWT' }
    
    // Encode to base64url
    const encodedHeader = base64urlEncode(JSON.stringify(header))
    const encodedPayload = base64urlEncode(JSON.stringify(payload))
    
    const unsignedToken = `${encodedHeader}.${encodedPayload}`
    
    // Clean up private key - handle both escaped and unescaped newlines
    let privateKey = serviceAccount.private_key
    if (typeof privateKey === 'string') {
      privateKey = privateKey.replace(/\\n/g, '\n')
    }
    
    console.log('Private key format check:', {
      hasBeginMarker: privateKey.includes('-----BEGIN PRIVATE KEY-----'),
      hasEndMarker: privateKey.includes('-----END PRIVATE KEY-----'),
      length: privateKey.length
    })

    // Convert PEM to DER format for Web Crypto API
    const pemContents = privateKey
      .replace('-----BEGIN PRIVATE KEY-----', '')
      .replace('-----END PRIVATE KEY-----', '')
      .replace(/\s/g, '')
    
    const keyData = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))
    
    // Import the private key
    const algorithm = {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    }

    const key = await crypto.subtle.importKey(
      'pkcs8',
      keyData,
      algorithm,
      false,
      ['sign']
    )

    // Sign the token
    const signature = await crypto.subtle.sign(
      algorithm,
      key,
      new TextEncoder().encode(unsignedToken)
    )

    const encodedSignature = base64urlEncode(new Uint8Array(signature))
    const jwt = `${unsignedToken}.${encodedSignature}`
    
    console.log('JWT created successfully, length:', jwt.length)

    // Exchange JWT for access token
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    })

    const tokenData = await tokenResponse.json()
    
    console.log('Token response status:', tokenResponse.status)
    console.log('Token response:', tokenData)
    
    if (!tokenData.access_token) {
      throw new Error(`Failed to get access token: ${JSON.stringify(tokenData)}`)
    }

    console.log('Access token obtained successfully')
    return tokenData.access_token
  } catch (error) {
    console.error('Error in getAccessToken:', error)
    throw error
  }
}

// Helper function for base64url encoding
function base64urlEncode(data: string | Uint8Array): string {
  let base64: string
  if (typeof data === 'string') {
    base64 = btoa(data)
  } else {
    base64 = btoa(String.fromCharCode(...data))
  }
  return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}