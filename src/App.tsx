import { useState } from 'react';
import { AdminLogin } from './components/AdminLogin';
import { AdminDashboard } from './components/AdminDashboard';
import { TransactionsView } from './components/TransactionsView';
import { DisputesView } from './components/DisputesView';
import { LayoutDashboard, CreditCard, AlertCircle, LogOut } from 'lucide-react';
import { setAccessToken } from './lib/api';

type View = 'dashboard' | 'transactions' | 'disputes';

function App() {
  const [user, setUser] = useState<any>(null);
  const [currentView, setCurrentView] = useState<View>('dashboard');

  const handleLogout = () => {
    setAccessToken(null);
    setUser(null);
    setCurrentView('dashboard');
  };

  if (!user) {
    return <AdminLogin onLoginSuccess={setUser} />;
  }

  if (!user.is_admin) {
    return (
      <div className="min-h-screen bg-slate-900 flex items-center justify-center p-4">
        <div className="bg-slate-800 p-8 rounded-lg shadow-xl text-center">
          <h2 className="text-2xl font-bold text-white mb-4">Access Denied</h2>
          <p className="text-slate-300 mb-6">You need admin privileges to access this dashboard.</p>
          <button
            onClick={handleLogout}
            className="bg-blue-600 hover:bg-blue-700 text-white font-medium px-6 py-2 rounded-lg"
          >
            Sign Out
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-slate-900">
      <div className="flex">
        <div className="w-64 bg-slate-800 min-h-screen border-r border-slate-700 p-6">
          <h1 className="text-2xl font-bold text-white mb-8">RMH PAY</h1>

          <nav className="space-y-2">
            <button
              onClick={() => setCurrentView('dashboard')}
              className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg text-left transition-colors ${
                currentView === 'dashboard'
                  ? 'bg-blue-600 text-white'
                  : 'text-slate-300 hover:bg-slate-700'
              }`}
            >
              <LayoutDashboard className="w-5 h-5" />
              Dashboard
            </button>

            <button
              onClick={() => setCurrentView('transactions')}
              className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg text-left transition-colors ${
                currentView === 'transactions'
                  ? 'bg-blue-600 text-white'
                  : 'text-slate-300 hover:bg-slate-700'
              }`}
            >
              <CreditCard className="w-5 h-5" />
              Transactions
            </button>

            <button
              onClick={() => setCurrentView('disputes')}
              className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg text-left transition-colors ${
                currentView === 'disputes'
                  ? 'bg-blue-600 text-white'
                  : 'text-slate-300 hover:bg-slate-700'
              }`}
            >
              <AlertCircle className="w-5 h-5" />
              Disputes
            </button>
          </nav>

          <div className="mt-auto pt-8">
            <div className="border-t border-slate-700 pt-4">
              <div className="text-sm text-slate-400 mb-4">
                <div className="font-medium text-white">{user.full_name || 'Admin'}</div>
                <div>{user.phone_number}</div>
              </div>

              <button
                onClick={handleLogout}
                className="w-full flex items-center gap-3 px-4 py-3 rounded-lg text-slate-300 hover:bg-slate-700"
              >
                <LogOut className="w-5 h-5" />
                Sign Out
              </button>
            </div>
          </div>
        </div>

        <div className="flex-1 p-8">
          {currentView === 'dashboard' && <AdminDashboard />}
          {currentView === 'transactions' && <TransactionsView />}
          {currentView === 'disputes' && <DisputesView />}
        </div>
      </div>
    </div>
  );
}

export default App;
