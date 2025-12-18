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

async function isAdmin(userId: string): Promise<boolean> {
  const { data: user } = await supabase
    .from('users')
    .select('is_admin')
    .eq('id', userId)
    .maybeSingle();
  
  return user?.is_admin === true;
}

async function logAdminAction(adminId: string, actionType: string, description: string, targetType?: string, targetId?: string, metadata?: Record<string, unknown>) {
  await supabase.from('admin_actions').insert({
    admin_id: adminId,
    action_type: actionType,
    description,
    target_type: targetType,
    target_id: targetId,
    metadata: metadata || {},
  });
}

async function handleGetDashboardStats(adminId: string) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  
  const { count: totalUsers } = await supabase
    .from('users')
    .select('*', { count: 'exact', head: true });
  
  const { count: totalAccounts } = await supabase
    .from('pppoe_accounts')
    .select('*', { count: 'exact', head: true });
  
  const { count: todayTransactions } = await supabase
    .from('transactions')
    .select('*', { count: 'exact', head: true })
    .gte('created_at', today.toISOString());
  
  const { data: todayRevenue } = await supabase
    .from('transactions')
    .select('amount')
    .eq('state', 'success')
    .gte('created_at', today.toISOString());
  
  const totalRevenue = todayRevenue?.reduce((sum, t) => sum + t.amount, 0) || 0;
  
  const { count: openDisputes } = await supabase
    .from('disputes')
    .select('*', { count: 'exact', head: true })
    .eq('status', 'open');
  
  const { count: pendingTransactions } = await supabase
    .from('transactions')
    .select('*', { count: 'exact', head: true })
    .in('state', ['payment_initiated', 'pin_sent', 'pending_confirmation']);
  
  return {
    data: {
      stats: {
        total_users: totalUsers || 0,
        total_accounts: totalAccounts || 0,
        today_transactions: todayTransactions || 0,
        today_revenue: totalRevenue,
        open_disputes: openDisputes || 0,
        pending_transactions: pendingTransactions || 0,
      },
    },
    status: 200,
  };
}

async function handleGetAllTransactions(adminId: string, params: URLSearchParams) {
  const limit = parseInt(params.get('limit') || '100');
  const offset = parseInt(params.get('offset') || '0');
  const state = params.get('state');
  
  let query = supabase
    .from('transactions')
    .select('*, users(phone_number, full_name), pppoe_accounts(account_number, customer_name)', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);
  
  if (state) {
    query = query.eq('state', state);
  }
  
  const { data: transactions, error, count } = await query;
  
  if (error) {
    return { error: 'Failed to fetch transactions', status: 500 };
  }
  
  await logAdminAction(adminId, 'view_transactions', 'Viewed transaction list');
  
  return {
    data: {
      transactions,
      total: count || 0,
      limit,
      offset,
    },
    status: 200,
  };
}

async function handleManualRestore(adminId: string, body: { account_id: string; reason: string }) {
  const { account_id, reason } = body;
  
  if (!account_id || !reason) {
    return { error: 'Account ID and reason required', status: 400 };
  }
  
  const { data: account } = await supabase
    .from('pppoe_accounts')
    .select('*')
    .eq('id', account_id)
    .maybeSingle();
  
  if (!account) {
    return { error: 'Account not found', status: 404 };
  }
  
  const apiUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/mikrotik`;
  const response = await fetch(apiUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${Deno.env.get('SUPABASE_ANON_KEY')}`,
    },
    body: JSON.stringify({
      action: 'extend_service',
      account_id: account.id,
      transaction_id: null,
    }),
  });
  
  const result = await response.json();
  
  await logAdminAction(
    adminId,
    'manual_restore',
    `Manually restored internet for account ${account.account_number}`,
    'pppoe_account',
    account_id,
    { reason }
  );
  
  return {
    data: {
      message: 'Service restored successfully',
      account: account.account_number,
    },
    status: 200,
  };
}

async function handleGetDisputes(adminId: string, params: URLSearchParams) {
  const status = params.get('status') || 'open';
  const limit = parseInt(params.get('limit') || '50');
  
  const { data: disputes, error } = await supabase
    .from('disputes')
    .select('*, users(phone_number, full_name), transactions(*, pppoe_accounts(account_number, customer_name))')
    .eq('status', status)
    .order('created_at', { ascending: false })
    .limit(limit);
  
  if (error) {
    return { error: 'Failed to fetch disputes', status: 500 };
  }
  
  return { data: { disputes }, status: 200 };
}

async function handleResolveDispute(adminId: string, disputeId: string, body: { resolution: string; status: 'resolved' | 'rejected' }) {
  const { resolution, status } = body;
  
  if (!resolution || !status) {
    return { error: 'Resolution and status required', status: 400 };
  }
  
  const { data: dispute } = await supabase
    .from('disputes')
    .select('*')
    .eq('id', disputeId)
    .maybeSingle();
  
  if (!dispute) {
    return { error: 'Dispute not found', status: 404 };
  }
  
  const { error: updateError } = await supabase
    .from('disputes')
    .update({
      status,
      resolution,
      resolved_by: adminId,
      resolved_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq('id', disputeId);
  
  if (updateError) {
    return { error: 'Failed to resolve dispute', status: 500 };
  }
  
  await logAdminAction(
    adminId,
    'resolve_dispute',
    `Resolved dispute ${disputeId} as ${status}`,
    'dispute',
    disputeId,
    { resolution, status }
  );
  
  return { data: { message: 'Dispute resolved successfully' }, status: 200 };
}

async function handleManagePPPoEAccount(adminId: string, method: string, accountId: string | null, body?: any) {
  if (method === 'GET') {
    const { data: accounts, error } = await supabase
      .from('pppoe_accounts')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(100);
    
    if (error) {
      return { error: 'Failed to fetch accounts', status: 500 };
    }
    
    return { data: { accounts }, status: 200 };
  }
  
  if (method === 'POST') {
    const { account_number, customer_name, phone_number, monthly_amount, expiry_date, mikrotik_username } = body;
    
    if (!account_number || !customer_name || !phone_number || !monthly_amount || !expiry_date) {
      return { error: 'Missing required fields', status: 400 };
    }
    
    const { data: account, error: insertError } = await supabase
      .from('pppoe_accounts')
      .insert({
        account_number: account_number.trim().toUpperCase(),
        customer_name,
        phone_number,
        monthly_amount,
        expiry_date,
        mikrotik_username,
        status: 'active',
      })
      .select()
      .single();
    
    if (insertError) {
      return { error: 'Failed to create account', status: 500 };
    }
    
    await logAdminAction(
      adminId,
      'create_account',
      `Created PPPoE account ${account_number}`,
      'pppoe_account',
      account.id
    );
    
    return { data: { account }, status: 200 };
  }
  
  if (method === 'PUT' && accountId) {
    const { error: updateError } = await supabase
      .from('pppoe_accounts')
      .update({
        ...body,
        updated_at: new Date().toISOString(),
      })
      .eq('id', accountId);
    
    if (updateError) {
      return { error: 'Failed to update account', status: 500 };
    }
    
    await logAdminAction(
      adminId,
      'update_account',
      `Updated PPPoE account ${accountId}`,
      'pppoe_account',
      accountId,
      body
    );
    
    return { data: { message: 'Account updated successfully' }, status: 200 };
  }
  
  return { error: 'Invalid request', status: 400 };
}

async function handleUpdateSystemConfig(adminId: string, body: { key: string; value: any }) {
  const { key, value } = body;
  
  if (!key || value === undefined) {
    return { error: 'Key and value required', status: 400 };
  }
  
  const { error } = await supabase
    .from('system_config')
    .update({ value, updated_at: new Date().toISOString() })
    .eq('key', key);
  
  if (error) {
    return { error: 'Failed to update config', status: 500 };
  }
  
  await logAdminAction(
    adminId,
    'update_config',
    `Updated system config: ${key}`,
    'system_config',
    key,
    { value }
  );
  
  return { data: { message: 'Config updated successfully' }, status: 200 };
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }
  
  try {
    const userId = await getUserFromRequest(req);
    if (!userId) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    const isAdminUser = await isAdmin(userId);
    if (!isAdminUser) {
      return new Response(JSON.stringify({ error: 'Forbidden: Admin access required' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    const url = new URL(req.url);
    const path = url.pathname;
    
    if (path === '/admin/dashboard/stats' && req.method === 'GET') {
      const result = await handleGetDashboardStats(userId);
      return new Response(JSON.stringify(result.data), {
        status: result.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    if (path === '/admin/transactions' && req.method === 'GET') {
      const result = await handleGetAllTransactions(userId, url.searchParams);
      return new Response(JSON.stringify(result.error ? { error: result.error } : result.data), {
        status: result.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    if (path === '/admin/restore' && req.method === 'POST') {
      const body = await req.json();
      const result = await handleManualRestore(userId, body);
      return new Response(JSON.stringify(result.error ? { error: result.error } : result.data), {
        status: result.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    if (path === '/admin/disputes' && req.method === 'GET') {
      const result = await handleGetDisputes(userId, url.searchParams);
      return new Response(JSON.stringify(result.error ? { error: result.error } : result.data), {
        status: result.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    if (path.startsWith('/admin/disputes/') && req.method === 'PUT') {
      const disputeId = path.split('/')[3];
      const body = await req.json();
      const result = await handleResolveDispute(userId, disputeId, body);
      return new Response(JSON.stringify(result.error ? { error: result.error } : result.data), {
        status: result.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    if (path === '/admin/accounts' && (req.method === 'GET' || req.method === 'POST')) {
      const body = req.method === 'POST' ? await req.json() : undefined;
      const result = await handleManagePPPoEAccount(userId, req.method, null, body);
      return new Response(JSON.stringify(result.error ? { error: result.error } : result.data), {
        status: result.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    if (path.startsWith('/admin/accounts/') && req.method === 'PUT') {
      const accountId = path.split('/')[3];
      const body = await req.json();
      const result = await handleManagePPPoEAccount(userId, 'PUT', accountId, body);
      return new Response(JSON.stringify(result.error ? { error: result.error } : result.data), {
        status: result.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    if (path === '/admin/config' && req.method === 'PUT') {
      const body = await req.json();
      const result = await handleUpdateSystemConfig(userId, body);
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