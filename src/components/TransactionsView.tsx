import { useEffect, useState } from 'react';
import { adminApi } from '../lib/api';
import { ChevronLeft, ChevronRight } from 'lucide-react';

interface Transaction {
  id: string;
  amount: number;
  months: number;
  payment_method: string;
  state: string;
  created_at: string;
  users: { phone_number: string; full_name: string };
  pppoe_accounts: { account_number: string; customer_name: string };
}

export function TransactionsView() {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [offset, setOffset] = useState(0);
  const [total, setTotal] = useState(0);
  const [stateFilter, setStateFilter] = useState('');
  const limit = 50;

  useEffect(() => {
    loadTransactions();
  }, [offset, stateFilter]);

  const loadTransactions = async () => {
    setLoading(true);
    const result = await adminApi.getTransactions({
      limit,
      offset,
      state: stateFilter || undefined
    });

    if (result.data) {
      setTransactions(result.data.transactions);
      setTotal(result.data.total);
    }
    setLoading(false);
  };

  const getStateBadgeColor = (state: string) => {
    const colors: Record<string, string> = {
      success: 'bg-green-500/10 text-green-500 border-green-500',
      failed: 'bg-red-500/10 text-red-500 border-red-500',
      pending_confirmation: 'bg-yellow-500/10 text-yellow-500 border-yellow-500',
      payment_initiated: 'bg-blue-500/10 text-blue-500 border-blue-500',
      pin_sent: 'bg-blue-500/10 text-blue-500 border-blue-500',
      timeout: 'bg-orange-500/10 text-orange-500 border-orange-500',
      reversed: 'bg-purple-500/10 text-purple-500 border-purple-500',
    };
    return colors[state] || 'bg-slate-500/10 text-slate-500 border-slate-500';
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-white">Transactions</h2>

        <select
          value={stateFilter}
          onChange={(e) => {
            setStateFilter(e.target.value);
            setOffset(0);
          }}
          className="px-4 py-2 bg-slate-800 border border-slate-700 rounded-lg text-white focus:outline-none focus:border-blue-500"
        >
          <option value="">All States</option>
          <option value="success">Success</option>
          <option value="failed">Failed</option>
          <option value="pending_confirmation">Pending</option>
          <option value="timeout">Timeout</option>
        </select>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-64">
          <div className="text-slate-400">Loading transactions...</div>
        </div>
      ) : (
        <>
          <div className="bg-slate-800 rounded-lg border border-slate-700 overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-slate-900/50 border-b border-slate-700">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-slate-400 uppercase tracking-wider">
                      Account
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-slate-400 uppercase tracking-wider">
                      Customer
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-slate-400 uppercase tracking-wider">
                      Amount
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-slate-400 uppercase tracking-wider">
                      Months
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-slate-400 uppercase tracking-wider">
                      Method
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-slate-400 uppercase tracking-wider">
                      State
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-slate-400 uppercase tracking-wider">
                      Date
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-700">
                  {transactions.map((tx) => (
                    <tr key={tx.id} className="hover:bg-slate-700/30">
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-white">
                        {tx.pppoe_accounts.account_number}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-slate-300">
                        {tx.pppoe_accounts.customer_name}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-white font-medium">
                        UGX {tx.amount.toLocaleString()}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-slate-300">
                        {tx.months}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-slate-300">
                        {tx.payment_method.toUpperCase().replace('_', ' ')}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className={`px-2 py-1 text-xs font-medium border rounded ${getStateBadgeColor(tx.state)}`}>
                          {tx.state.replace(/_/g, ' ').toUpperCase()}
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-slate-400">
                        {new Date(tx.created_at).toLocaleString()}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          <div className="flex items-center justify-between">
            <div className="text-sm text-slate-400">
              Showing {offset + 1} to {Math.min(offset + limit, total)} of {total} transactions
            </div>

            <div className="flex gap-2">
              <button
                onClick={() => setOffset(Math.max(0, offset - limit))}
                disabled={offset === 0}
                className="px-4 py-2 bg-slate-800 hover:bg-slate-700 disabled:bg-slate-800/50 disabled:cursor-not-allowed text-white rounded-lg border border-slate-700 flex items-center gap-2"
              >
                <ChevronLeft className="w-4 h-4" />
                Previous
              </button>

              <button
                onClick={() => setOffset(offset + limit)}
                disabled={offset + limit >= total}
                className="px-4 py-2 bg-slate-800 hover:bg-slate-700 disabled:bg-slate-800/50 disabled:cursor-not-allowed text-white rounded-lg border border-slate-700 flex items-center gap-2"
              >
                Next
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
