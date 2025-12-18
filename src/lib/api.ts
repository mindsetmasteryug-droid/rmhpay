const API_BASE_URL = import.meta.env.VITE_SUPABASE_URL;
const ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY;

export interface ApiResponse<T = any> {
  data?: T;
  error?: string;
}

let accessToken: string | null = null;

export function setAccessToken(token: string | null) {
  accessToken = token;
}

export function getAccessToken(): string | null {
  return accessToken;
}

async function apiCall<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<ApiResponse<T>> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${ANON_KEY}`,
    ...((options.headers as Record<string, string>) || {}),
  };

  if (accessToken) {
    headers['Authorization'] = `Bearer ${accessToken}`;
  }

  try {
    const response = await fetch(`${API_BASE_URL}/functions/v1${endpoint}`, {
      ...options,
      headers,
    });

    const data = await response.json();

    if (!response.ok) {
      return { error: data.error || 'Request failed' };
    }

    return { data };
  } catch (error) {
    return { error: 'Network error' };
  }
}

export const authApi = {
  async sendOTP(phoneNumber: string, purpose: string): Promise<ApiResponse> {
    return apiCall('/auth/send-otp', {
      method: 'POST',
      body: JSON.stringify({ phone_number: phoneNumber, purpose }),
    });
  },

  async verifyOTP(phoneNumber: string, code: string, purpose: string, deviceId: string): Promise<ApiResponse> {
    return apiCall('/auth/verify-otp', {
      method: 'POST',
      body: JSON.stringify({ phone_number: phoneNumber, code, purpose, device_id: deviceId }),
    });
  },

  async login(phoneNumber: string, password: string, deviceId: string): Promise<ApiResponse> {
    return apiCall('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ phone_number: phoneNumber, password, device_id: deviceId }),
    });
  },
};

export const adminApi = {
  async getDashboardStats(): Promise<ApiResponse> {
    return apiCall('/admin/dashboard/stats');
  },

  async getTransactions(params?: { limit?: number; offset?: number; state?: string }): Promise<ApiResponse> {
    const query = new URLSearchParams();
    if (params?.limit) query.append('limit', String(params.limit));
    if (params?.offset) query.append('offset', String(params.offset));
    if (params?.state) query.append('state', params.state);

    return apiCall(`/admin/transactions?${query.toString()}`);
  },

  async manualRestore(accountId: string, reason: string): Promise<ApiResponse> {
    return apiCall('/admin/restore', {
      method: 'POST',
      body: JSON.stringify({ account_id: accountId, reason }),
    });
  },

  async getDisputes(status: string = 'open'): Promise<ApiResponse> {
    return apiCall(`/admin/disputes?status=${status}`);
  },

  async resolveDispute(disputeId: string, resolution: string, status: 'resolved' | 'rejected'): Promise<ApiResponse> {
    return apiCall(`/admin/disputes/${disputeId}`, {
      method: 'PUT',
      body: JSON.stringify({ resolution, status }),
    });
  },

  async getAccounts(): Promise<ApiResponse> {
    return apiCall('/admin/accounts');
  },

  async createAccount(account: any): Promise<ApiResponse> {
    return apiCall('/admin/accounts', {
      method: 'POST',
      body: JSON.stringify(account),
    });
  },

  async updateAccount(accountId: string, updates: any): Promise<ApiResponse> {
    return apiCall(`/admin/accounts/${accountId}`, {
      method: 'PUT',
      body: JSON.stringify(updates),
    });
  },

  async updateConfig(key: string, value: any): Promise<ApiResponse> {
    return apiCall('/admin/config', {
      method: 'PUT',
      body: JSON.stringify({ key, value }),
    });
  },
};
