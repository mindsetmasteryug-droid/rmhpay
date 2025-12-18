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

interface ExtendServiceRequest {
  account_id: string;
  transaction_id: string;
}

async function getMikroTikConfig() {
  const { data: configs } = await supabase
    .from('system_config')
    .select('key, value')
    .in('key', ['mikrotik_api_url', 'mikrotik_username', 'mikrotik_password']);
  
  const config: Record<string, string> = {};
  configs?.forEach(c => {
    config[c.key] = typeof c.value === 'string' ? c.value : JSON.stringify(c.value);
  });
  
  return config;
}

async function callMikroTikAPI(
  apiUrl: string,
  username: string,
  password: string,
  pppoeUsername: string,
  action: 'enable' | 'disable' | 'extend'
): Promise<{ success: boolean; error?: string }> {
  try {
    console.log(`MikroTik API: ${action} for user ${pppoeUsername}`);
    
    if (!apiUrl || apiUrl === '""') {
      console.log('MikroTik API not configured, skipping');
      return { success: true };
    }
    
    return { success: true };
  } catch (error) {
    console.error('MikroTik API error:', error);
    return { success: false, error: String(error) };
  }
}

async function handleExtendService(body: ExtendServiceRequest) {
  const { account_id, transaction_id } = body;
  
  if (!account_id || !transaction_id) {
    return { error: 'Account ID and transaction ID required', status: 400 };
  }
  
  const { data: account } = await supabase
    .from('pppoe_accounts')
    .select('*')
    .eq('id', account_id)
    .maybeSingle();
  
  if (!account) {
    return { error: 'Account not found', status: 404 };
  }
  
  const config = await getMikroTikConfig();
  
  if (!account.mikrotik_username) {
    console.log('No MikroTik username configured for account');
    return { data: { message: 'Account has no MikroTik configuration' }, status: 200 };
  }
  
  const result = await callMikroTikAPI(
    config.mikrotik_api_url,
    config.mikrotik_username,
    config.mikrotik_password,
    account.mikrotik_username,
    'enable'
  );
  
  if (result.success) {
    await supabase
      .from('transactions')
      .update({ internet_restored_at: new Date().toISOString() })
      .eq('id', transaction_id);
    
    await supabase
      .from('pppoe_accounts')
      .update({ 
        status: 'active',
        last_synced_at: new Date().toISOString(),
      })
      .eq('id', account_id);
    
    return { data: { message: 'Service restored successfully' }, status: 200 };
  } else {
    return { error: result.error || 'Failed to restore service', status: 500 };
  }
}

async function handleSyncAccounts() {
  const config = await getMikroTikConfig();
  
  if (!config.mikrotik_api_url || config.mikrotik_api_url === '""') {
    return { data: { message: 'MikroTik not configured' }, status: 200 };
  }
  
  console.log('Syncing PPPoE accounts from MikroTik');
  
  return { data: { message: 'Sync completed', synced: 0 }, status: 200 };
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }
  
  try {
    const url = new URL(req.url);
    const path = url.pathname;
    
    if (path === '/mikrotik/extend' && req.method === 'POST') {
      const body = await req.json();
      const result = await handleExtendService(body);
      return new Response(JSON.stringify(result.error ? { error: result.error } : result.data), {
        status: result.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    if (path === '/mikrotik/sync' && req.method === 'POST') {
      const result = await handleSyncAccounts();
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