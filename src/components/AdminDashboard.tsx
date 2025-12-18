import { useEffect, useState } from 'react';
import { adminApi } from '../lib/api';
import { Users, CreditCard, AlertCircle, TrendingUp } from 'lucide-react';

interface DashboardStats {
  total_users: number;
  total_accounts: number;
  today_transactions: number;
  today_revenue: number;
  open_disputes: number;
  pending_transactions: number;
}

export function AdminDashboard() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadStats();
  }, []);

  const loadStats = async () => {
    const result = await adminApi.getDashboardStats();
    if (result.data) {
      setStats(result.data.stats);
    }
    setLoading(false);
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-slate-400">Loading stats...</div>
      </div>
    );
  }

  if (!stats) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-slate-400">Failed to load stats</div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-white">Dashboard</h2>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <div className="bg-slate-800 p-6 rounded-lg border border-slate-700">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-slate-400 text-sm">Total Users</p>
              <p className="text-3xl font-bold text-white mt-2">{stats.total_users}</p>
            </div>
            <Users className="w-12 h-12 text-blue-500" />
          </div>
        </div>

        <div className="bg-slate-800 p-6 rounded-lg border border-slate-700">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-slate-400 text-sm">Total Accounts</p>
              <p className="text-3xl font-bold text-white mt-2">{stats.total_accounts}</p>
            </div>
            <CreditCard className="w-12 h-12 text-green-500" />
          </div>
        </div>

        <div className="bg-slate-800 p-6 rounded-lg border border-slate-700">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-slate-400 text-sm">Today's Transactions</p>
              <p className="text-3xl font-bold text-white mt-2">{stats.today_transactions}</p>
            </div>
            <TrendingUp className="w-12 h-12 text-purple-500" />
          </div>
        </div>

        <div className="bg-slate-800 p-6 rounded-lg border border-slate-700">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-slate-400 text-sm">Today's Revenue</p>
              <p className="text-3xl font-bold text-white mt-2">
                UGX {stats.today_revenue.toLocaleString()}
              </p>
            </div>
            <TrendingUp className="w-12 h-12 text-emerald-500" />
          </div>
        </div>

        <div className="bg-slate-800 p-6 rounded-lg border border-slate-700">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-slate-400 text-sm">Open Disputes</p>
              <p className="text-3xl font-bold text-white mt-2">{stats.open_disputes}</p>
            </div>
            <AlertCircle className="w-12 h-12 text-red-500" />
          </div>
        </div>

        <div className="bg-slate-800 p-6 rounded-lg border border-slate-700">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-slate-400 text-sm">Pending Transactions</p>
              <p className="text-3xl font-bold text-white mt-2">{stats.pending_transactions}</p>
            </div>
            <AlertCircle className="w-12 h-12 text-yellow-500" />
          </div>
        </div>
      </div>
    </div>
  );
}
