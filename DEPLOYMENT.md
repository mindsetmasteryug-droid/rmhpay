# RMH PAY - Deployment Guide

## System Architecture

RMH PAY is a complete fintech payment system with three main components:
1. iOS Native Application (SwiftUI)
2. Backend API (Supabase Edge Functions)
3. Web Admin Dashboard (React + Vite)

## Prerequisites

- Supabase account and project
- DigitalOcean account (optional, for production hosting)
- Apple Developer Account (for iOS deployment)
- MikroTik RouterOS with API access
- Mobile Money provider API credentials (MTN, Airtel)

## Database Setup

The database is already configured with all necessary tables and RLS policies.

### Initial Data Setup

1. Create an admin user:
```sql
INSERT INTO users (phone_number, password_hash, is_admin, is_verified, is_active)
VALUES (
  '+256700000000',
  -- Password hash for 'admin123' (change this!)
  '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9',
  true,
  true,
  true
);
```

2. Add sample PPPoE accounts:
```sql
INSERT INTO pppoe_accounts (
  account_number,
  customer_name,
  phone_number,
  monthly_amount,
  expiry_date,
  status,
  mikrotik_username
) VALUES
('LUB0001', 'John Doe', '+256700111111', 50000, '2025-01-31', 'active', 'john.doe'),
('RMH0001', 'Jane Smith', '+256700222222', 75000, '2025-02-15', 'active', 'jane.smith');
```

3. Configure MikroTik settings:
```sql
UPDATE system_config SET value = '"https://your-mikrotik-api.com"' WHERE key = 'mikrotik_api_url';
UPDATE system_config SET value = '"admin"' WHERE key = 'mikrotik_username';
UPDATE system_config SET value = '"your-password"' WHERE key = 'mikrotik_password';
```

## Backend Deployment

### Supabase Edge Functions

All edge functions are already deployed:
- `/auth` - Authentication (OTP, password, Google Sign-In)
- `/payments` - Payment processing
- `/accounts` - Account lookup and management
- `/mikrotik` - MikroTik integration
- `/admin` - Admin operations

### Environment Variables

The following environment variables are automatically configured in Supabase:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `JWT_SECRET`

## Web Admin Dashboard Deployment

### Local Development

1. Copy environment variables:
```bash
cp .env.example .env
```

2. Edit `.env` with your Supabase credentials:
```
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your_anon_key_here
```

3. Install dependencies:
```bash
npm install
```

4. Run development server:
```bash
npm run dev
```

### Production Deployment

1. Build the application:
```bash
npm run build
```

2. Deploy to hosting provider (Vercel, Netlify, etc.):
```bash
# Vercel
vercel --prod

# Netlify
netlify deploy --prod
```

## iOS App Deployment

### Xcode Project Setup

1. Create new Xcode project:
   - Product Name: RMH PAY
   - Organization Identifier: com.rmhpay
   - Interface: SwiftUI
   - Language: Swift
   - Minimum iOS: 16.0

2. Copy all Swift files from `ios-app/Sources/` into the project

3. Configure Info.plist:
```xml
<key>API_BASE_URL</key>
<string>https://your-project.supabase.co</string>
<key>API_KEY</key>
<string>your_supabase_anon_key</string>
<key>NSFaceIDUsageDescription</key>
<string>Use Face ID to securely access your account</string>
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

4. Enable Capabilities:
   - Push Notifications
   - Background Modes > Remote notifications

### Testing on Physical Device

1. Connect your iPhone
2. Select your device in Xcode
3. Build and Run (⌘R)

### App Store Submission

1. Configure signing:
   - Select your team
   - Create provisioning profiles
   - Set Bundle Identifier

2. Prepare assets:
   - App icon (1024x1024)
   - Launch screen
   - Screenshots for all device sizes

3. Archive and upload:
   - Product > Archive
   - Upload to App Store Connect
   - Complete app information
   - Submit for review

## MikroTik Integration

### RouterOS API Setup

1. Enable API on RouterOS:
```
/ip service enable api
/ip service enable api-ssl
```

2. Create API user:
```
/user add name=rmhpay group=full password=your-secure-password
```

3. Configure firewall rules to allow API access

### PPPoE Account Sync

The system can automatically sync PPPoE users from MikroTik. To trigger sync:
```bash
curl -X POST https://your-project.supabase.co/functions/v1/mikrotik/sync \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

## Payment Provider Integration

### MTN Mobile Money

1. Register for MTN MoMo API: https://momodeveloper.mtn.com
2. Get API credentials (User ID, API Key)
3. Update the payment processing logic in `/functions/payments/index.ts`

### Airtel Money

1. Register for Airtel Money API
2. Get API credentials
3. Update the payment processing logic in `/functions/payments/index.ts`

## Monitoring & Operations

### Health Checks

Monitor Edge Function health:
```bash
curl https://your-project.supabase.co/functions/v1/auth
curl https://your-project.supabase.co/functions/v1/payments/history
```

### Database Monitoring

Monitor key metrics in Supabase dashboard:
- Active connections
- Query performance
- Storage usage

### Transaction Reconciliation

Run daily reconciliation job to check:
- Stuck transactions (>30 min in pending state)
- Failed internet restorations
- Payment discrepancies

### Logs

View Edge Function logs in Supabase dashboard:
1. Go to Edge Functions
2. Select function
3. View logs

## Security Checklist

- [ ] Change default admin password
- [ ] Configure proper JWT secret
- [ ] Enable MFA for admin users
- [ ] Set up rate limiting
- [ ] Configure proper CORS origins
- [ ] Enable SSL/TLS everywhere
- [ ] Regular security audits
- [ ] Backup database regularly
- [ ] Monitor for suspicious activity
- [ ] Keep dependencies updated

## Backup & Recovery

### Database Backup

Supabase provides automatic daily backups. To create manual backup:
```bash
pg_dump postgresql://postgres:password@db.your-project.supabase.co:5432/postgres > backup.sql
```

### Restore from Backup

```bash
psql postgresql://postgres:password@db.your-project.supabase.co:5432/postgres < backup.sql
```

## Scaling Considerations

### Database
- Add indexes for frequently queried columns
- Use read replicas for heavy queries
- Partition large tables (transactions, notifications)

### Edge Functions
- Monitor execution time
- Optimize database queries
- Use connection pooling
- Cache frequently accessed data

### iOS App
- Implement proper pagination
- Use local caching
- Background task processing
- Optimize network requests

## Support & Maintenance

### Regular Tasks
- Daily: Monitor pending transactions
- Weekly: Review dispute reports
- Monthly: Reconcile payments
- Quarterly: Security audit

### Emergency Procedures
1. Payment failures: Check provider status
2. Internet restoration failures: Verify MikroTik connectivity
3. App crashes: Check error logs
4. Database issues: Check connection limits

## Production Checklist

### Backend
- [ ] Database migrations applied
- [ ] Admin user created
- [ ] System config updated
- [ ] Edge functions deployed
- [ ] MikroTik integration configured
- [ ] Payment providers integrated

### Web Dashboard
- [ ] Environment variables configured
- [ ] Production build created
- [ ] Deployed to hosting
- [ ] SSL certificate configured
- [ ] Admin login tested

### iOS App
- [ ] API endpoints configured
- [ ] Push notifications enabled
- [ ] Testing on physical devices
- [ ] App Store assets prepared
- [ ] Privacy policy added
- [ ] Terms of service added
- [ ] App submitted for review

### Testing
- [ ] Authentication flows
- [ ] Account lookup
- [ ] Payment processing (test accounts)
- [ ] Receipt generation
- [ ] Admin operations
- [ ] Error handling
- [ ] Offline scenarios
- [ ] Network failures

## Contact & Support

For technical support or questions:
- Documentation: See README files in each directory
- Database Schema: See migration file for complete schema
- API Documentation: See edge function source code
