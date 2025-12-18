/*
  # RMH PAY Complete Database Schema

  ## Overview
  Complete production database schema for RMH PAY fintech system supporting
  internet subscription payments, PPPoE account management, and mobile money transactions.

  ## New Tables

  ### Core Tables
  1. `users` - User accounts with authentication
     - `id` (uuid, primary key)
     - `phone_number` (text, unique, required)
     - `email` (text, nullable)
     - `full_name` (text, nullable)
     - `password_hash` (text, nullable)
     - `google_id` (text, nullable, unique)
     - `rmh_account_id` (text, nullable)
     - `is_verified` (boolean, default false)
     - `is_active` (boolean, default true)
     - `last_login_at` (timestamptz)
     - `created_at` (timestamptz, default now)
     - `updated_at` (timestamptz, default now)

  2. `user_sessions` - Device session tracking
     - `id` (uuid, primary key)
     - `user_id` (uuid, foreign key)
     - `device_id` (text, required)
     - `device_name` (text, nullable)
     - `refresh_token_hash` (text, required)
     - `expires_at` (timestamptz, required)
     - `last_active_at` (timestamptz, default now)
     - `created_at` (timestamptz, default now)

  3. `otp_codes` - OTP verification
     - `id` (uuid, primary key)
     - `phone_number` (text, required)
     - `code` (text, required)
     - `purpose` (text, required: 'registration', 'login', 'verification')
     - `expires_at` (timestamptz, required)
     - `used_at` (timestamptz, nullable)
     - `attempts` (integer, default 0)
     - `created_at` (timestamptz, default now)

  4. `pppoe_accounts` - PPPoE internet accounts
     - `id` (uuid, primary key)
     - `account_number` (text, unique, required)
     - `customer_name` (text, required)
     - `phone_number` (text, required)
     - `monthly_amount` (integer, required) - UGX
     - `expiry_date` (timestamptz, required)
     - `status` (text, required: 'active', 'expired', 'suspended', 'disabled')
     - `mikrotik_username` (text, nullable)
     - `mikrotik_password` (text, nullable)
     - `mikrotik_profile` (text, nullable)
     - `last_synced_at` (timestamptz, nullable)
     - `created_at` (timestamptz, default now)
     - `updated_at` (timestamptz, default now)

  5. `saved_accounts` - User saved accounts
     - `id` (uuid, primary key)
     - `user_id` (uuid, foreign key)
     - `pppoe_account_id` (uuid, foreign key)
     - `nickname` (text, nullable)
     - `custom_phone` (text, nullable)
     - `is_favorite` (boolean, default false)
     - `created_at` (timestamptz, default now)

  6. `transactions` - Payment transactions
     - `id` (uuid, primary key)
     - `idempotency_key` (text, unique, required)
     - `user_id` (uuid, foreign key)
     - `pppoe_account_id` (uuid, foreign key)
     - `amount` (integer, required) - UGX
     - `months` (integer, required)
     - `payment_method` (text, required: 'mtn_momo', 'airtel_money', 'card')
     - `payment_phone` (text, required)
     - `state` (text, required: 'created', 'lookup_verified', 'payment_initiated', 'pin_sent', 'pending_confirmation', 'success', 'failed', 'timeout', 'reversed')
     - `provider_reference` (text, nullable)
     - `provider_transaction_id` (text, nullable)
     - `receipt_number` (text, nullable, unique)
     - `error_message` (text, nullable)
     - `metadata` (jsonb, default '{}')
     - `internet_restored_at` (timestamptz, nullable)
     - `created_at` (timestamptz, default now)
     - `updated_at` (timestamptz, default now)
     - `completed_at` (timestamptz, nullable)

  7. `bulk_transactions` - Bulk payment groups
     - `id` (uuid, primary key)
     - `user_id` (uuid, foreign key)
     - `total_amount` (integer, required)
     - `total_accounts` (integer, required)
     - `state` (text, required: 'created', 'processing', 'success', 'partial', 'failed')
     - `successful_count` (integer, default 0)
     - `failed_count` (integer, default 0)
     - `created_at` (timestamptz, default now)
     - `completed_at` (timestamptz, nullable)

  8. `transaction_state_log` - State machine audit trail
     - `id` (uuid, primary key)
     - `transaction_id` (uuid, foreign key)
     - `from_state` (text, nullable)
     - `to_state` (text, required)
     - `reason` (text, nullable)
     - `metadata` (jsonb, default '{}')
     - `created_at` (timestamptz, default now)

  9. `receipts` - Payment receipts
     - `id` (uuid, primary key)
     - `transaction_id` (uuid, foreign key)
     - `receipt_number` (text, unique, required)
     - `account_number` (text, required)
     - `customer_name` (text, required)
     - `amount` (integer, required)
     - `months` (integer, required)
     - `payment_method` (text, required)
     - `payment_phone` (text, required)
     - `old_expiry` (timestamptz, required)
     - `new_expiry` (timestamptz, required)
     - `issued_at` (timestamptz, default now)

  10. `disputes` - Transaction disputes
      - `id` (uuid, primary key)
      - `transaction_id` (uuid, foreign key)
      - `user_id` (uuid, foreign key)
      - `reason` (text, required)
      - `description` (text, required)
      - `status` (text, required: 'open', 'investigating', 'resolved', 'rejected')
      - `resolution` (text, nullable)
      - `resolved_by` (uuid, nullable, foreign key to users)
      - `resolved_at` (timestamptz, nullable)
      - `metadata` (jsonb, default '{}')
      - `created_at` (timestamptz, default now)
      - `updated_at` (timestamptz, default now)

  11. `admin_actions` - Admin activity log
      - `id` (uuid, primary key)
      - `admin_id` (uuid, foreign key to users)
      - `action_type` (text, required)
      - `target_type` (text, nullable)
      - `target_id` (uuid, nullable)
      - `description` (text, required)
      - `metadata` (jsonb, default '{}')
      - `created_at` (timestamptz, default now)

  12. `push_tokens` - Push notification tokens
      - `id` (uuid, primary key)
      - `user_id` (uuid, foreign key)
      - `token` (text, unique, required)
      - `device_id` (text, required)
      - `platform` (text, required: 'ios', 'android')
      - `is_active` (boolean, default true)
      - `created_at` (timestamptz, default now)
      - `updated_at` (timestamptz, default now)

  13. `notifications` - Notification history
      - `id` (uuid, primary key)
      - `user_id` (uuid, foreign key)
      - `type` (text, required)
      - `title` (text, required)
      - `body` (text, required)
      - `data` (jsonb, default '{}')
      - `read_at` (timestamptz, nullable)
      - `created_at` (timestamptz, default now)

  14. `system_config` - System configuration
      - `key` (text, primary key)
      - `value` (jsonb, required)
      - `description` (text, nullable)
      - `updated_at` (timestamptz, default now)

  ## Security
  - RLS enabled on all tables
  - Policies for authenticated users
  - Admin role policies
  - API key policies for system operations

  ## Indexes
  - Performance indexes on foreign keys
  - Lookup indexes on account numbers, phone numbers
  - Transaction state indexes
  - Timestamp indexes for reporting
*/

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone_number text UNIQUE NOT NULL,
  email text UNIQUE,
  full_name text,
  password_hash text,
  google_id text UNIQUE,
  rmh_account_id text,
  is_verified boolean DEFAULT false,
  is_active boolean DEFAULT true,
  is_admin boolean DEFAULT false,
  last_login_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone_number);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_google_id ON users(google_id);

-- User sessions table
CREATE TABLE IF NOT EXISTS user_sessions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id text NOT NULL,
  device_name text,
  refresh_token_hash text NOT NULL,
  expires_at timestamptz NOT NULL,
  last_active_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON user_sessions(expires_at);

-- OTP codes table
CREATE TABLE IF NOT EXISTS otp_codes (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone_number text NOT NULL,
  code text NOT NULL,
  purpose text NOT NULL CHECK (purpose IN ('registration', 'login', 'verification')),
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  attempts integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_otp_phone_purpose ON otp_codes(phone_number, purpose) WHERE used_at IS NULL;

-- PPPoE accounts table
CREATE TABLE IF NOT EXISTS pppoe_accounts (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_number text UNIQUE NOT NULL,
  customer_name text NOT NULL,
  phone_number text NOT NULL,
  monthly_amount integer NOT NULL,
  expiry_date timestamptz NOT NULL,
  status text NOT NULL CHECK (status IN ('active', 'expired', 'suspended', 'disabled')) DEFAULT 'active',
  mikrotik_username text,
  mikrotik_password text,
  mikrotik_profile text,
  last_synced_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pppoe_account_number ON pppoe_accounts(account_number);
CREATE INDEX IF NOT EXISTS idx_pppoe_status ON pppoe_accounts(status);
CREATE INDEX IF NOT EXISTS idx_pppoe_expiry ON pppoe_accounts(expiry_date);

-- Saved accounts table
CREATE TABLE IF NOT EXISTS saved_accounts (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  pppoe_account_id uuid NOT NULL REFERENCES pppoe_accounts(id) ON DELETE CASCADE,
  nickname text,
  custom_phone text,
  is_favorite boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, pppoe_account_id)
);

CREATE INDEX IF NOT EXISTS idx_saved_accounts_user_id ON saved_accounts(user_id);

-- Transactions table
CREATE TABLE IF NOT EXISTS transactions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  idempotency_key text UNIQUE NOT NULL,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  pppoe_account_id uuid NOT NULL REFERENCES pppoe_accounts(id),
  bulk_transaction_id uuid,
  amount integer NOT NULL,
  months integer NOT NULL CHECK (months > 0 AND months <= 12),
  payment_method text NOT NULL CHECK (payment_method IN ('mtn_momo', 'airtel_money', 'card')),
  payment_phone text NOT NULL,
  state text NOT NULL CHECK (state IN ('created', 'lookup_verified', 'payment_initiated', 'pin_sent', 'pending_confirmation', 'success', 'failed', 'timeout', 'reversed')) DEFAULT 'created',
  provider_reference text,
  provider_transaction_id text,
  receipt_number text UNIQUE,
  error_message text,
  metadata jsonb DEFAULT '{}',
  internet_restored_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  completed_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_pppoe_account_id ON transactions(pppoe_account_id);
CREATE INDEX IF NOT EXISTS idx_transactions_state ON transactions(state);
CREATE INDEX IF NOT EXISTS idx_transactions_idempotency_key ON transactions(idempotency_key);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at DESC);

-- Bulk transactions table
CREATE TABLE IF NOT EXISTS bulk_transactions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  total_amount integer NOT NULL,
  total_accounts integer NOT NULL,
  state text NOT NULL CHECK (state IN ('created', 'processing', 'success', 'partial', 'failed')) DEFAULT 'created',
  successful_count integer DEFAULT 0,
  failed_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  completed_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_bulk_transactions_user_id ON bulk_transactions(user_id);

-- Add foreign key for bulk_transaction_id
ALTER TABLE transactions ADD CONSTRAINT fk_bulk_transaction 
  FOREIGN KEY (bulk_transaction_id) REFERENCES bulk_transactions(id) ON DELETE SET NULL;

-- Transaction state log table
CREATE TABLE IF NOT EXISTS transaction_state_log (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  transaction_id uuid NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  from_state text,
  to_state text NOT NULL,
  reason text,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_state_log_transaction_id ON transaction_state_log(transaction_id);

-- Receipts table
CREATE TABLE IF NOT EXISTS receipts (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  transaction_id uuid UNIQUE NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  receipt_number text UNIQUE NOT NULL,
  account_number text NOT NULL,
  customer_name text NOT NULL,
  amount integer NOT NULL,
  months integer NOT NULL,
  payment_method text NOT NULL,
  payment_phone text NOT NULL,
  old_expiry timestamptz NOT NULL,
  new_expiry timestamptz NOT NULL,
  issued_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_receipts_transaction_id ON receipts(transaction_id);
CREATE INDEX IF NOT EXISTS idx_receipts_receipt_number ON receipts(receipt_number);

-- Disputes table
CREATE TABLE IF NOT EXISTS disputes (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  transaction_id uuid NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason text NOT NULL,
  description text NOT NULL,
  status text NOT NULL CHECK (status IN ('open', 'investigating', 'resolved', 'rejected')) DEFAULT 'open',
  resolution text,
  resolved_by uuid REFERENCES users(id),
  resolved_at timestamptz,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_disputes_transaction_id ON disputes(transaction_id);
CREATE INDEX IF NOT EXISTS idx_disputes_user_id ON disputes(user_id);
CREATE INDEX IF NOT EXISTS idx_disputes_status ON disputes(status);

-- Admin actions table
CREATE TABLE IF NOT EXISTS admin_actions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  admin_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  action_type text NOT NULL,
  target_type text,
  target_id uuid,
  description text NOT NULL,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_actions_admin_id ON admin_actions(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_actions_created_at ON admin_actions(created_at DESC);

-- Push tokens table
CREATE TABLE IF NOT EXISTS push_tokens (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token text UNIQUE NOT NULL,
  device_id text NOT NULL,
  platform text NOT NULL CHECK (platform IN ('ios', 'android')),
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_push_tokens_user_id ON push_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_push_tokens_token ON push_tokens(token);

-- Notifications table
CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  data jsonb DEFAULT '{}',
  read_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

-- System config table
CREATE TABLE IF NOT EXISTS system_config (
  key text PRIMARY KEY,
  value jsonb NOT NULL,
  description text,
  updated_at timestamptz DEFAULT now()
);

-- Insert default system config
INSERT INTO system_config (key, value, description) VALUES
  ('grace_period_minutes', '30', 'Grace period for pending transactions in minutes'),
  ('max_saved_accounts', '50', 'Maximum saved accounts per user'),
  ('otp_expiry_minutes', '10', 'OTP code expiry time in minutes'),
  ('otp_max_attempts', '3', 'Maximum OTP verification attempts'),
  ('payment_timeout_minutes', '15', 'Payment timeout in minutes'),
  ('mikrotik_api_url', '""', 'MikroTik RouterOS API URL'),
  ('mikrotik_username', '""', 'MikroTik API username'),
  ('mikrotik_password', '""', 'MikroTik API password')
ON CONFLICT (key) DO NOTHING;

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE otp_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE pppoe_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE bulk_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_state_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_config ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Users: can read and update own profile
CREATE POLICY "Users can read own profile" ON users
  FOR SELECT TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Admins can read all users
CREATE POLICY "Admins can read all users" ON users
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true
    )
  );

-- User sessions: can manage own sessions
CREATE POLICY "Users can read own sessions" ON user_sessions
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can delete own sessions" ON user_sessions
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- OTP codes: no direct access (managed by edge functions)

-- PPPoE accounts: read-only for all authenticated users (for lookup)
CREATE POLICY "Authenticated users can read pppoe accounts" ON pppoe_accounts
  FOR SELECT TO authenticated
  USING (true);

-- Admins can manage pppoe accounts
CREATE POLICY "Admins can manage pppoe accounts" ON pppoe_accounts
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true
    )
  );

-- Saved accounts: users can manage their own
CREATE POLICY "Users can read own saved accounts" ON saved_accounts
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own saved accounts" ON saved_accounts
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own saved accounts" ON saved_accounts
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own saved accounts" ON saved_accounts
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- Transactions: users can read their own
CREATE POLICY "Users can read own transactions" ON transactions
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Admins can read all transactions
CREATE POLICY "Admins can read all transactions" ON transactions
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true
    )
  );

-- Bulk transactions: users can read their own
CREATE POLICY "Users can read own bulk transactions" ON bulk_transactions
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Transaction state log: users can read logs for their transactions
CREATE POLICY "Users can read own transaction logs" ON transaction_state_log
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM transactions 
      WHERE transactions.id = transaction_state_log.transaction_id 
      AND transactions.user_id = auth.uid()
    )
  );

-- Receipts: users can read receipts for their transactions
CREATE POLICY "Users can read own receipts" ON receipts
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM transactions 
      WHERE transactions.id = receipts.transaction_id 
      AND transactions.user_id = auth.uid()
    )
  );

-- Disputes: users can manage their own disputes
CREATE POLICY "Users can read own disputes" ON disputes
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can create disputes" ON disputes
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Admins can manage all disputes
CREATE POLICY "Admins can manage disputes" ON disputes
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true
    )
  );

-- Admin actions: admins only
CREATE POLICY "Admins can read admin actions" ON admin_actions
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true
    )
  );

-- Push tokens: users can manage their own
CREATE POLICY "Users can read own push tokens" ON push_tokens
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own push tokens" ON push_tokens
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own push tokens" ON push_tokens
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own push tokens" ON push_tokens
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- Notifications: users can read their own
CREATE POLICY "Users can read own notifications" ON notifications
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- System config: read-only for authenticated, admins can update
CREATE POLICY "Authenticated users can read system config" ON system_config
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Admins can update system config" ON system_config
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true
    )
  );