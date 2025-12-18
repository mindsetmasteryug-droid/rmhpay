import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

const JWT_SECRET = Deno.env.get('JWT_SECRET') || 'your-secret-key-change-in-production';

interface SendOTPRequest {
  phone_number: string;
  purpose: 'registration' | 'login' | 'verification';
}

interface VerifyOTPRequest {
  phone_number: string;
  code: string;
  purpose: string;
  device_id: string;
  device_name?: string;
}

interface PasswordLoginRequest {
  phone_number: string;
  password: string;
  device_id: string;
  device_name?: string;
}

interface GoogleSignInRequest {
  google_id: string;
  email: string;
  full_name: string;
  device_id: string;
  device_name?: string;
}

interface RefreshTokenRequest {
  refresh_token: string;
  device_id: string;
}

async function generateJWT(userId: string): Promise<string> {
  const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = btoa(JSON.stringify({
    sub: userId,
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + (60 * 60),
  }));
  
  const signature = await crypto.subtle.sign(
    'HMAC',
    await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(JWT_SECRET),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign']
    ),
    new TextEncoder().encode(`${header}.${payload}`)
  );
  
  return `${header}.${payload}.${btoa(String.fromCharCode(...new Uint8Array(signature)))}`;
}

async function generateRefreshToken(): Promise<string> {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return btoa(String.fromCharCode(...array));
}

async function hashToken(token: string): Promise<string> {
  const msgBuffer = new TextEncoder().encode(token);
  const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

async function sendOTP(phoneNumber: string, code: string): Promise<boolean> {
  console.log(`Sending OTP ${code} to ${phoneNumber}`);
  return true;
}

async function handleSendOTP(body: SendOTPRequest) {
  const { phone_number, purpose } = body;
  
  if (!phone_number || !purpose) {
    return { error: 'Phone number and purpose required', status: 400 };
  }
  
  const { data: existingOTP } = await supabase
    .from('otp_codes')
    .select('*')
    .eq('phone_number', phone_number)
    .eq('purpose', purpose)
    .is('used_at', null)
    .gte('expires_at', new Date().toISOString())
    .maybeSingle();
  
  if (existingOTP) {
    return { error: 'OTP already sent. Please wait before requesting a new one.', status: 429 };
  }
  
  const code = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000);
  
  const { error: insertError } = await supabase
    .from('otp_codes')
    .insert({
      phone_number,
      code,
      purpose,
      expires_at: expiresAt.toISOString(),
    });
  
  if (insertError) {
    return { error: 'Failed to generate OTP', status: 500 };
  }
  
  await sendOTP(phone_number, code);
  
  return { data: { message: 'OTP sent successfully', expires_at: expiresAt.toISOString() }, status: 200 };
}

async function handleVerifyOTP(body: VerifyOTPRequest) {
  const { phone_number, code, purpose, device_id, device_name } = body;
  
  if (!phone_number || !code || !purpose || !device_id) {
    return { error: 'Missing required fields', status: 400 };
  }
  
  const { data: otpRecord, error: otpError } = await supabase
    .from('otp_codes')
    .select('*')
    .eq('phone_number', phone_number)
    .eq('purpose', purpose)
    .is('used_at', null)
    .gte('expires_at', new Date().toISOString())
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  
  if (otpError || !otpRecord) {
    return { error: 'Invalid or expired OTP', status: 400 };
  }
  
  if (otpRecord.attempts >= 3) {
    return { error: 'Too many attempts. Please request a new OTP.', status: 429 };
  }
  
  if (otpRecord.code !== code) {
    await supabase
      .from('otp_codes')
      .update({ attempts: otpRecord.attempts + 1 })
      .eq('id', otpRecord.id);
    
    return { error: 'Invalid OTP code', status: 400 };
  }
  
  await supabase
    .from('otp_codes')
    .update({ used_at: new Date().toISOString() })
    .eq('id', otpRecord.id);
  
  let user;
  const { data: existingUser } = await supabase
    .from('users')
    .select('*')
    .eq('phone_number', phone_number)
    .maybeSingle();
  
  if (existingUser) {
    user = existingUser;
    await supabase
      .from('users')
      .update({ 
        is_verified: true,
        last_login_at: new Date().toISOString()
      })
      .eq('id', user.id);
  } else {
    const { data: newUser, error: createError } = await supabase
      .from('users')
      .insert({
        phone_number,
        is_verified: true,
        last_login_at: new Date().toISOString()
      })
      .select()
      .single();
    
    if (createError) {
      return { error: 'Failed to create user', status: 500 };
    }
    user = newUser;
  }
  
  const accessToken = await generateJWT(user.id);
  const refreshToken = await generateRefreshToken();
  const refreshTokenHash = await hashToken(refreshToken);
  
  const { error: sessionError } = await supabase
    .from('user_sessions')
    .insert({
      user_id: user.id,
      device_id,
      device_name,
      refresh_token_hash: refreshTokenHash,
      expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
    });
  
  if (sessionError) {
    return { error: 'Failed to create session', status: 500 };
  }
  
  return {
    data: {
      user: {
        id: user.id,
        phone_number: user.phone_number,
        email: user.email,
        full_name: user.full_name,
        is_verified: user.is_verified,
        is_admin: user.is_admin,
      },
      access_token: accessToken,
      refresh_token: refreshToken,
    },
    status: 200
  };
}

async function handlePasswordLogin(body: PasswordLoginRequest) {
  const { phone_number, password, device_id, device_name } = body;
  
  if (!phone_number || !password || !device_id) {
    return { error: 'Missing required fields', status: 400 };
  }
  
  const { data: user, error: userError } = await supabase
    .from('users')
    .select('*')
    .eq('phone_number', phone_number)
    .maybeSingle();
  
  if (userError || !user || !user.password_hash) {
    return { error: 'Invalid credentials', status: 401 };
  }
  
  const encoder = new TextEncoder();
  const data = encoder.encode(password);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const passwordHash = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  
  if (passwordHash !== user.password_hash) {
    return { error: 'Invalid credentials', status: 401 };
  }
  
  if (!user.is_active) {
    return { error: 'Account is disabled', status: 403 };
  }
  
  await supabase
    .from('users')
    .update({ last_login_at: new Date().toISOString() })
    .eq('id', user.id);
  
  const accessToken = await generateJWT(user.id);
  const refreshToken = await generateRefreshToken();
  const refreshTokenHash = await hashToken(refreshToken);
  
  await supabase
    .from('user_sessions')
    .insert({
      user_id: user.id,
      device_id,
      device_name,
      refresh_token_hash: refreshTokenHash,
      expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
    });
  
  return {
    data: {
      user: {
        id: user.id,
        phone_number: user.phone_number,
        email: user.email,
        full_name: user.full_name,
        is_verified: user.is_verified,
        is_admin: user.is_admin,
      },
      access_token: accessToken,
      refresh_token: refreshToken,
    },
    status: 200
  };
}

async function handleGoogleSignIn(body: GoogleSignInRequest) {
  const { google_id, email, full_name, device_id, device_name } = body;
  
  if (!google_id || !email || !device_id) {
    return { error: 'Missing required fields', status: 400 };
  }
  
  let user;
  const { data: existingUser } = await supabase
    .from('users')
    .select('*')
    .eq('google_id', google_id)
    .maybeSingle();
  
  if (existingUser) {
    user = existingUser;
    await supabase
      .from('users')
      .update({ last_login_at: new Date().toISOString() })
      .eq('id', user.id);
  } else {
    const { data: newUser, error: createError } = await supabase
      .from('users')
      .insert({
        google_id,
        email,
        full_name,
        is_verified: true,
        last_login_at: new Date().toISOString()
      })
      .select()
      .single();
    
    if (createError) {
      return { error: 'Failed to create user', status: 500 };
    }
    user = newUser;
  }
  
  const accessToken = await generateJWT(user.id);
  const refreshToken = await generateRefreshToken();
  const refreshTokenHash = await hashToken(refreshToken);
  
  await supabase
    .from('user_sessions')
    .insert({
      user_id: user.id,
      device_id,
      device_name,
      refresh_token_hash: refreshTokenHash,
      expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
    });
  
  return {
    data: {
      user: {
        id: user.id,
        phone_number: user.phone_number,
        email: user.email,
        full_name: user.full_name,
        is_verified: user.is_verified,
        is_admin: user.is_admin,
      },
      access_token: accessToken,
      refresh_token: refreshToken,
    },
    status: 200
  };
}

async function handleRefreshToken(body: RefreshTokenRequest) {
  const { refresh_token, device_id } = body;
  
  if (!refresh_token || !device_id) {
    return { error: 'Missing required fields', status: 400 };
  }
  
  const refreshTokenHash = await hashToken(refresh_token);
  
  const { data: session, error: sessionError } = await supabase
    .from('user_sessions')
    .select('*, users(*)')
    .eq('refresh_token_hash', refreshTokenHash)
    .eq('device_id', device_id)
    .gte('expires_at', new Date().toISOString())
    .maybeSingle();
  
  if (sessionError || !session) {
    return { error: 'Invalid or expired refresh token', status: 401 };
  }
  
  const user = session.users;
  
  if (!user.is_active) {
    return { error: 'Account is disabled', status: 403 };
  }
  
  const accessToken = await generateJWT(user.id);
  const newRefreshToken = await generateRefreshToken();
  const newRefreshTokenHash = await hashToken(newRefreshToken);
  
  await supabase
    .from('user_sessions')
    .update({ 
      refresh_token_hash: newRefreshTokenHash,
      last_active_at: new Date().toISOString(),
    })
    .eq('id', session.id);
  
  return {
    data: {
      user: {
        id: user.id,
        phone_number: user.phone_number,
        email: user.email,
        full_name: user.full_name,
        is_verified: user.is_verified,
        is_admin: user.is_admin,
      },
      access_token: accessToken,
      refresh_token: newRefreshToken,
    },
    status: 200
  };
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }
  
  try {
    const url = new URL(req.url);
    const path = url.pathname;
    
    if (path === '/auth/send-otp' && req.method === 'POST') {
      const body = await req.json();
      const result = await handleSendOTP(body);
      return new Response(JSON.stringify(result.error ? { error: result.error } : result.data), {
        status: result.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    if (path === '/auth/verify-otp' && req.method === 'POST') {
      const body = await req.json();
      const result = await handleVerifyOTP(body);
      return new Response(JSON.stringify(result.error ? { error: result.error } : result.data), {
        status: result.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    if (path === '/auth/login' && req.method === 'POST') {
      const body = await req.json();
      const result = await handlePasswordLogin(body);
      return new Response(JSON.stringify(result.error ? { error: result.error } : result.data), {
        status: result.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    if (path === '/auth/google' && req.method === 'POST') {
      const body = await req.json();
      const result = await handleGoogleSignIn(body);
      return new Response(JSON.stringify(result.error ? { error: result.error } : result.data), {
        status: result.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    if (path === '/auth/refresh' && req.method === 'POST') {
      const body = await req.json();
      const result = await handleRefreshToken(body);
      return new Response(JSON.stringify(result.error ? { error: result.error } : result.data), {
        status: result.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    return new Response(JSON.stringify({ error: 'Not found' }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('Error:', error);
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});