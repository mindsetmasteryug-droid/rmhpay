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

async function verifyJWT(token: string): Promise<string | null> {
  try {
    const [header, payload, signature] = token.split('.');
    const data = JSON.parse(atob(payload));
    
    if (data.exp < Math.floor(Date.now() / 1000)) {
      return null;
    }
    
    return data.sub;
  } catch {
    return null;
  }
}

async function getUserFromRequest(req: Request): Promise<string | null> {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null;
  }
  
  const token = authHeader.substring(7);
  return await verifyJWT(token);
}

async function handleLookupAccount(accountNumber: string) {
  if (!accountNumber) {
    return { error: 'Account number required', status: 400 };
  }
  
  const { data: account, error } = await supabase
    .from('pppoe_accounts')
    .select('*')
    .eq('account_number', accountNumber.trim().toUpperCase())
    .maybeSingle();
  
  if (error || !account) {
    return { error: 'Account not found', status: 404 };
  }
  
  return {
    data: {
      account: {
        id: account.id,
        account_number: account.account_number,
        customer_name: account.customer_name,
        phone_number: account.phone_number,
        monthly_amount: account.monthly_amount,
        expiry_date: account.expiry_date,
        status: account.status,
      },
    },
    status: 200,
  };
}

async function handleGetSavedAccounts(userId: string) {
  const { data: savedAccounts, error } = await supabase
    .from('saved_accounts')
    .select('*, pppoe_accounts(*)')
    .eq('user_id', userId)
    .order('is_favorite', { ascending: false })
    .order('created_at', { ascending: false });
  
  if (error) {
    return { error: 'Failed to fetch saved accounts', status: 500 };
  }
  
  const { data: config } = await supabase
    .from('system_config')
    .select('value')
    .eq('key', 'max_saved_accounts')
    .single();
  
  const maxSaved = parseInt(config?.value || '50');
  
  return {
    data: {
      accounts: savedAccounts,
      max_saved: maxSaved,
      count: savedAccounts.length,
    },
    status: 200,
  };
}

async function handleSaveAccount(userId: string, body: { account_number: string; nickname?: string; custom_phone?: string }) {
  const { account_number, nickname, custom_phone } = body;
  
  if (!account_number) {
    return { error: 'Account number required', status: 400 };
  }
  
  const { data: account } = await supabase
    .from('pppoe_accounts')
    .select('*')
    .eq('account_number', account_number.trim().toUpperCase())
    .maybeSingle();
  
  if (!account) {
    return { error: 'Account not found', status: 404 };
  }
  
  const { data: savedCount } = await supabase
    .from('saved_accounts')
    .select('id', { count: 'exact' })
    .eq('user_id', userId);
  
  const { data: config } = await supabase
    .from('system_config')
    .select('value')
    .eq('key', 'max_saved_accounts')
    .single();
  
  const maxSaved = parseInt(config?.value || '50');
  
  if ((savedCount?.length || 0) >= maxSaved) {
    return { error: `Maximum ${maxSaved} saved accounts allowed`, status: 400 };
  }
  
  const { data: existing } = await supabase
    .from('saved_accounts')
    .select('*')
    .eq('user_id', userId)
    .eq('pppoe_account_id', account.id)
    .maybeSingle();
  
  if (existing) {
    return { error: 'Account already saved', status: 400 };
  }
  
  const { data: savedAccount, error: insertError } = await supabase
    .from('saved_accounts')
    .insert({
      user_id: userId,
      pppoe_account_id: account.id,
      nickname,
      custom_phone: custom_phone || account.phone_number,
    })
    .select('*, pppoe_accounts(*)')
    .single();
  
  if (insertError) {
    return { error: 'Failed to save account', status: 500 };
  }
  
  return { data: { saved_account: savedAccount }, status: 200 };
}

async function handleUpdateSavedAccount(userId: string, savedAccountId: string, body: { nickname?: string; custom_phone?: string; is_favorite?: boolean }) {
  const { nickname, custom_phone, is_favorite } = body;
  
  const { data: savedAccount } = await supabase
    .from('saved_accounts')
    .select('*')
    .eq('id', savedAccountId)
    .eq('user_id', userId)
    .maybeSingle();
  
  if (!savedAccount) {
    return { error: 'Saved account not found', status: 404 };
  }
  
  const updates: Record<string, unknown> = {};
  if (nickname !== undefined) updates.nickname = nickname;
  if (custom_phone !== undefined) updates.custom_phone = custom_phone;
  if (is_favorite !== undefined) updates.is_favorite = is_favorite;
  
  const { data: updated, error: updateError } = await supabase
    .from('saved_accounts')
    .update(updates)
    .eq('id', savedAccountId)
    .select('*, pppoe_accounts(*)')
    .single();
  
  if (updateError) {
    return { error: 'Failed to update saved account', status: 500 };
  }
  
  return { data: { saved_account: updated }, status: 200 };
}

async function handleDeleteSavedAccount(userId: string, savedAccountId: string) {
  const { error } = await supabase
    .from('saved_accounts')
    .delete()
    .eq('id', savedAccountId)
    .eq('user_id', userId);
  
  if (error) {
    return { error: 'Failed to delete saved account', status: 500 };
  }
  
  return { data: { message: 'Account removed successfully' }, status: 200 };
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }
  
  try {
    const url = new URL(req.url);
    const path = url.pathname;
    
    if (path === '/accounts/lookup' && req.method === 'GET') {
      const accountNumber = url.searchParams.get('account_number');
      if (!accountNumber) {
        return new Response(JSON.stringify({ error: 'Account number required' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      
      const result = await handleLookupAccount(accountNumber);
      return new Response(JSON.stringify(result.error ? { error: result.error } : result.data), {
        status: result.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    const userId = await getUserFromRequest(req);
    if (!userId) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    if (path === '/accounts/saved' && req.method === 'GET') {
      const result = await handleGetSavedAccounts(userId);
      return new Response(JSON.stringify(result.error ? { error: result.error } : result.data), {
        status: result.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    if (path === '/accounts/saved' && req.method === 'POST') {
      const body = await req.json();
      const result = await handleSaveAccount(userId, body);
      return new Response(JSON.stringify(result.error ? { error: result.error } : result.data), {
        status: result.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    if (path.startsWith('/accounts/saved/') && req.method === 'PUT') {
      const savedAccountId = path.split('/')[3];
      const body = await req.json();
      const result = await handleUpdateSavedAccount(userId, savedAccountId, body);
      return new Response(JSON.stringify(result.error ? { error: result.error } : result.data), {
        status: result.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    if (path.startsWith('/accounts/saved/') && req.method === 'DELETE') {
      const savedAccountId = path.split('/')[3];
      const result = await handleDeleteSavedAccount(userId, savedAccountId);
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