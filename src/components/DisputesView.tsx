import { useEffect, useState } from 'react';
import { adminApi } from '../lib/api';
import { X } from 'lucide-react';

interface Dispute {
  id: string;
  reason: string;
  description: string;
  status: string;
  created_at: string;
  users: { phone_number: string; full_name: string };
  transactions: {
    amount: number;
    pppoe_accounts: { account_number: string; customer_name: string };
  };
}

export function DisputesView() {
  const [disputes, setDisputes] = useState<Dispute[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedDispute, setSelectedDispute] = useState<Dispute | null>(null);
  const [resolution, setResolution] = useState('');
  const [resolving, setResolving] = useState(false);

  useEffect(() => {
    loadDisputes();
  }, []);

  const loadDisputes = async () => {
    setLoading(true);
    const result = await adminApi.getDisputes('open');
    if (result.data) {
      setDisputes(result.data.disputes);
    }
    setLoading(false);
  };

  const handleResolve = async (status: 'resolved' | 'rejected') => {
    if (!selectedDispute || !resolution.trim()) return;

    setResolving(true);
    const result = await adminApi.resolveDispute(selectedDispute.id, resolution, status);
    setResolving(false);

    if (!result.error) {
      setSelectedDispute(null);
      setResolution('');
      loadDisputes();
    }
  };

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-white">Disputes</h2>

      {loading ? (
        <div className="flex items-center justify-center h-64">
          <div className="text-slate-400">Loading disputes...</div>
        </div>
      ) : disputes.length === 0 ? (
        <div className="bg-slate-800 rounded-lg border border-slate-700 p-12 text-center">
          <p className="text-slate-400">No open disputes</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4">
          {disputes.map((dispute) => (
            <div
              key={dispute.id}
              className="bg-slate-800 rounded-lg border border-slate-700 p-6 hover:border-slate-600 cursor-pointer"
              onClick={() => setSelectedDispute(dispute)}
            >
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-2">
                    <h3 className="text-lg font-semibold text-white">{dispute.reason}</h3>
                    <span className="px-2 py-1 text-xs font-medium bg-red-500/10 text-red-500 border border-red-500 rounded">
                      OPEN
                    </span>
                  </div>

                  <p className="text-slate-300 mb-4">{dispute.description}</p>

                  <div className="grid grid-cols-2 gap-4 text-sm">
                    <div>
                      <span className="text-slate-400">Account:</span>
                      <span className="text-white ml-2">
                        {dispute.transactions.pppoe_accounts.account_number}
                      </span>
                    </div>
                    <div>
                      <span className="text-slate-400">Amount:</span>
                      <span className="text-white ml-2">
                        UGX {dispute.transactions.amount.toLocaleString()}
                      </span>
                    </div>
                    <div>
                      <span className="text-slate-400">Customer:</span>
                      <span className="text-white ml-2">
                        {dispute.transactions.pppoe_accounts.customer_name}
                      </span>
                    </div>
                    <div>
                      <span className="text-slate-400">Reported:</span>
                      <span className="text-white ml-2">
                        {new Date(dispute.created_at).toLocaleDateString()}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {selectedDispute && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div className="bg-slate-800 rounded-lg border border-slate-700 p-6 max-w-2xl w-full">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-xl font-bold text-white">Resolve Dispute</h3>
              <button
                onClick={() => setSelectedDispute(null)}
                className="text-slate-400 hover:text-white"
              >
                <X className="w-6 h-6" />
              </button>
            </div>

            <div className="space-y-4 mb-6">
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">
                  Resolution Notes
                </label>
                <textarea
                  value={resolution}
                  onChange={(e) => setResolution(e.target.value)}
                  className="w-full px-4 py-2 bg-slate-700 border border-slate-600 rounded-lg text-white focus:outline-none focus:border-blue-500"
                  rows={4}
                  placeholder="Explain how this dispute was resolved..."
                  required
                />
              </div>
            </div>

            <div className="flex gap-3">
              <button
                onClick={() => handleResolve('resolved')}
                disabled={resolving || !resolution.trim()}
                className="flex-1 bg-green-600 hover:bg-green-700 disabled:bg-green-800 text-white font-medium py-3 rounded-lg"
              >
                {resolving ? 'Resolving...' : 'Mark as Resolved'}
              </button>

              <button
                onClick={() => handleResolve('rejected')}
                disabled={resolving || !resolution.trim()}
                className="flex-1 bg-red-600 hover:bg-red-700 disabled:bg-red-800 text-white font-medium py-3 rounded-lg"
              >
                {resolving ? 'Rejecting...' : 'Reject Dispute'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
