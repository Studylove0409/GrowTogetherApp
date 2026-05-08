import { createClient } from 'jsr:@supabase/supabase-js@2';
import { SignJWT, importPKCS8 } from 'npm:jose@5';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

async function getAccessToken(): Promise<string> {
  const clientEmail = Deno.env.get('FCM_CLIENT_EMAIL')!;
  const privateKey = Deno.env.get('FCM_PRIVATE_KEY')!;
  const projectId = Deno.env.get('FCM_PROJECT_ID')!;

  const key = await importPKCS8(privateKey, 'RS256');

  const jwt = await new SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(clientEmail)
    .setAudience('https://oauth2.googleapis.com/token')
    .setSubject(clientEmail)
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(key);

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  const data = await res.json();
  return data.access_token;
}

Deno.serve(async (req: Request) => {
  try {
    const { to_user_id, content, plan_id } = await req.json();

    if (!to_user_id || !content) {
      return new Response(
        JSON.stringify({ error: 'missing to_user_id or content' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('fcm_token')
      .eq('user_id', to_user_id)
      .maybeSingle();

    if (profileError || !profile?.fcm_token) {
      console.log('Recipient has no FCM token');
      return new Response(JSON.stringify({ status: 'no_fcm_token' }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const clientEmail = Deno.env.get('FCM_CLIENT_EMAIL');
    if (!clientEmail) {
      console.log('FCM not configured — missing service account');
      return new Response(JSON.stringify({ status: 'fcm_not_configured' }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const accessToken = await getAccessToken();
    const projectId = Deno.env.get('FCM_PROJECT_ID')!;

    const fcmPayload = {
      message: {
        token: profile.fcm_token,
        notification: {
          title: '「一起进步呀」',
          body: content,
        },
        data: {
          plan_id: plan_id ?? '',
          type: 'reminder',
        },
        android: {
          priority: 'high',
          notification: {
            channel_id: 'partner_reminders',
            sound: 'default',
          },
        },
      },
    };

    const fcmRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(fcmPayload),
      }
    );

    const fcmResult = await fcmRes.json();
    console.log('FCM response:', JSON.stringify(fcmResult));

    return new Response(JSON.stringify({ status: 'sent', fcm: fcmResult }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error('Error:', err);
    return new Response(JSON.stringify({ error: 'internal error' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
