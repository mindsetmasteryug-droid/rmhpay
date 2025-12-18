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

interface InitiatePaymentRequest {
  account_number: string;
  months: number;
  payment_method: 'mtn_momo' | 'airtel_money' | 'card';
  payment_phone: string;
  idempotency_key: string;
}

interface ConfirmPaymentRequest {
  transaction_id: string;
  pin?: string;
}

interface BulkPaymentRequest {
  payments: Array<{
    account_number: string;
    months: number;
  }>;
  payment_method: 'mtn_momo' | 'airtel_money' | 'card';
  payment_phone: string;
  idempotency_key: string;
}

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

async function logStateTransition(
  transactionId: string,
  fromState: string | null,
  toState: string,
  reason?: string,
  metadata?: Record<string, unknown>
) {
  await supabase.from('transaction_state_log').insert({
    transaction_id: transactionId,
    from_state: fromState,
    to_state: toState,
    reason,
    metadata: metadata || {},
  });
}

async function updateTransactionState(
  transactionId: string,
  newState: string,
  updates?: Record<string, unknown>
) {
  const { data: transaction } = await supabase
    .from('transactions')
    .select('state')
    .eq('id', transactionId)
    .single();
  
  const oldState = transaction?.state || null;
  
  await supabase
    .from('transactions')
    .update({ 
      state: newState, 
      updated_at: new Date().toISOString(),
      ...updates 
    })
    .eq('id', transactionId);
  
  await logStateTransition(transactionId, oldState, newState);
}

async function callMobileMoneyAPI(
  method: string,
  phone: string,
  amount: number
): Promise<{ success: boolean; reference?: string; error?: string }> {
  console.log(`Calling ${method} API for ${phone} with amount ${amount}`);
  
  const mockSuccess = Math.random() > 0.1;
  
  if (mockSuccess) {
    return {
      success: true,
      reference: `REF${Date.now()}${Math.floor(Math.random() * 1000)}`,
    };
  } else {
    return {
      success: false,
      error: 'Payment failed. Please try again.',
    };
  }
}

async function handleInitiatePayment(userId: string, body: InitiatePaymentRequest) {
  const { account_number, months, payment_method, payment_phone, idempotency_key } = body;
  
  if (!account_number || !months || !payment_method || !payment_phone || !idempotency_key) {
    return { error: 'Missing required fields', status: 400 };
  }
  
  if (months < 1 || months > 12) {
    return { error: 'Months must be between 1 and 12', status: 400 };
  }
  
  const { data: existingTransaction } = await supabase
    .from('transactions')
    .select('*')
    .eq('idempotency_key', idempotency_key)
    .maybeSingle();
  
  if (existingTransaction) {
    return { data: { transaction: existingTransaction }, status: 200 };
  }
  
  const { data: account } = await supabase
    .from('pppoe_accounts')
    .select('*')
    .eq('account_number', account_number)
    .maybeSingle();
  
  if (!account) {
    return { error: 'Account not found', status: 404 };
  }
  
  const amount = account.monthly_amount * months;
  
  const { data: transaction, error: createError } = await supabase
    .from('transactions')
    .insert({
      idempotency_key,
      user_id: userId,
      pppoe_account_id: account.id,
      amount,
      months,
      payment_method,
      payment_phone,
      state: 'lookup_verified',
    })
    .select()
    .single();
  
  if (createError) {
    return { error: 'Failed to create transaction', status: 500 };
  }
  
  await logStateTransition(transaction.id, null, 'lookup_verified', 'Account verified');
  
  const paymentResult = await callMobileMoneyAPI(payment_method, payment_phone, amount);
  
  if (paymentResult.success) {
    await updateTransactionState(transaction.id, 'payment_initiated', {
      provider_reference: paymentResult.reference,
    });
    
    await updateTransactionState(transaction.id, 'pin_sent');
    
    return {
      data: {
        transaction: {
          ...transaction,
          state: 'pin_sent',
          provider_reference: paymentResult.reference,
        },
        message: 'Please enter your PIN to complete the payment',
      },
      status: 200,
    };
  } else {
    await updateTransactionState(transaction.id, 'failed', {
      error_message: paymentResult.error,
    });
    
    return { error: paymentResult.error, status: 400 };
  }
}

async function handleConfirmPayment(userId: string, body: ConfirmPaymentRequest) {
  const { transaction_id, pin } = body;
  
  if (!transaction_id) {
    return { error: 'Transaction ID required', status: 400 };
  }
  
  const { data: transaction } = await supabase
    .from('transactions')
    .select('*, pppoe_accounts(*)')
    .eq('id', transaction_id)
    .eq('user_id', userId)
    .maybeSingle();
  
  if (!transaction) {
    return { error: 'Transaction not found', status: 404 };
  }
  
  if (transaction.state === 'success') {
    return { data: { transaction }, status: 200 };
  }
  
  if (transaction.state !== 'pin_sent' && transaction.state !== 'pending_confirmation') {
    return { error: 'Invalid transaction state', status: 400 };
  }
  
  await updateTransactionState(transaction.id, 'pending_confirmation');
  
  const mockSuccess = Math.random() > 0.05;
  
  if (mockSuccess) {
    const account = transaction.pppoe_accounts;
    const oldExpiry = new Date(account.expiry_date);
    const newExpiry = new Date(oldExpiry);
    newExpiry.setDate(newExpiry.getDate() + (transaction.months * 30));
    
    const receiptNumber = `RMH${Date.now()}${Math.floor(Math.random() * 1000)}`;
    
    await supabase
      .from('pppoe_accounts')
      .update({ 
        expiry_date: newExpiry.toISOString(),
        status: 'active',
        updated_at: new Date().toISOString(),
      })
      .eq('id', account.id);
    
    await updateTransactionState(transaction.id, 'success', {
      receipt_number: receiptNumber,
      completed_at: new Date().toISOString(),
      provider_transaction_id: `TXN${Date.now()}`,
    });
    
    await supabase.from('receipts').insert({
      transaction_id: transaction.id,
      receipt_number: receiptNumber,
      account_number: account.account_number,
      customer_name: account.customer_name,
      amount: transaction.amount,
      months: transaction.months,
      payment_method: transaction.payment_method,
      payment_phone: transaction.payment_phone,
      old_expiry: oldExpiry.toISOString(),
      new_expiry: newExpiry.toISOString(),
    });
    
    const apiUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/mikrotik`;
    fetch(apiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${Deno.env.get('SUPABASE_ANON_KEY')}`,
      },
      body: JSON.stringify({
        action: 'extend_service',
        account_id: account.id,
        transaction_id: transaction.id,
      }),
    }).catch(err => console.error('MikroTik restoration failed:', err));
    
    return {
      data: {
        transaction: {
          ...transaction,
          state: 'success',
          receipt_number: receiptNumber,
        },
        receipt: {
          receipt_number: receiptNumber,
          account_number: account.account_number,
          customer_name: account.customer_name,
          amount: transaction.amount,
          months: transaction.months,
          new_expiry: newExpiry.toISOString(),
        },
      },
      status: 200,
    };
  } else {
    await updateTransactionState(transaction.id, 'failed', {
      error_message: 'Payment failed or was declined',
    });
    
    return { error: 'Payment failed or was declined', status: 400 };
  }
}

async function handleGetTransaction(userId: string, transactionId: string) {
  const { data: transaction, error } = await supabase
    .from('transactions')
    .select('*, pppoe_accounts(*), receipts(*)')
    .eq('id', transactionId)
    .eq('user_id', userId)
    .maybeSingle();
  
  if (error || !transaction) {
    return { error: 'Transaction not found', status: 404 };
  }
  
  return { data: { transaction }, status: 200 };
}

async function handleGetTransactionHistory(userId: string, limit: number = 50) {
  const { data: transactions, error } = await supabase
    .from('transactions')
    .select('*, pppoe_accounts(*)')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(limit);
  
  if (error) {
    return { error: 'Failed to fetch transactions', status: 500 };
  }
  
  return { data: { transactions }, status: 200 };
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
    
    const url = new URL(req.url);
    const path = url.pathname;
    
    if (path === '/payments/initiate' && req.method === 'POST') {
      const body = await req.json();
      const result = await handleInitiatePayment(userId, body);
      return new Response(JSON.stringify(result.error ? { error: result.error } : result.data), {
        status: result.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    if (path === '/payments/confirm' && req.method === 'POST') {
      const body = await req.json();
      const result = await handleConfirmPayment(userId, body);
      return new Response(JSON.stringify(result.error ? { error: result.error } : result.data), {
        status: result.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    if (path.startsWith('/payments/transaction/') && req.method === 'GET') {
      const transactionId = path.split('/')[3];
      const result = await handleGetTransaction(userId, transactionId);
      return new Response(JSON.stringify(result.error ? { error: result.error } : result.data), {
        status: result.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    if (path === '/payments/history' && req.method === 'GET') {
      const limit = parseInt(url.searchParams.get('limit') || '50');
      const result = await handleGetTransactionHistory(userId, limit);
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