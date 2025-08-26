import { config } from './config';

// Define request/response interfaces
export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  message?: string;
  error?: string;
}

export interface LoginRequest {
  username: string;
  password: string;
}

export interface LoginResponse {
  token: string;
  user: {
    id: string;
    username: string;
    role: string;
  };
}

export interface Session {
  id: string;
  name: string;
  status: string;
  connected: boolean;
  phoneNumber?: string;
  phone_number?: string;
  createdAt: string;
  lastActivity?: string;
  userId: string;
  webhook_url?: string;
  messages_sent?: number;
  messages_received?: number;
  current_uptime_seconds?: number;
  seconds_since_last_activity?: number;
  error_count?: number;
}

class ApiClient {
  private token: string | null = null;
  private baseUrl: string;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
    // Try to restore token from storage
    this.token = localStorage.getItem(config.tokenStorageKey) || 
                 sessionStorage.getItem(config.tokenStorageKey);
  }

  private async request<T = any>(endpoint: string, options: RequestInit = {}): Promise<ApiResponse<T>> {
    const url = `${this.baseUrl}${endpoint}`;
    
    console.log('Making API request to:', url);
    console.log('With token:', this.token ? 'Present' : 'Missing');
    
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };

    if (options.headers) {
      Object.assign(headers, options.headers);
    }

    if (this.token) {
      headers.Authorization = `Bearer ${this.token}`;
    }

    try {
      const response = await fetch(url, {
        ...options,
        headers,
        credentials: 'include',
      });

      console.log('Response status:', response.status);
      console.log('Response headers:', Object.fromEntries(response.headers.entries()));

      const data = await response.json();
      console.log('Response data:', data);

      if (!response.ok) {
        throw new Error(data.message || data.error || `HTTP ${response.status}`);
      }

      // For login endpoint, the backend returns direct data, not wrapped
      if (endpoint === '/auth/login' && response.ok) {
        return {
          success: true,
          data: data
        } as ApiResponse<T>;
      }

      // For other endpoints, assume they already return the correct format
      return data.success !== undefined ? data : {
        success: true,
        data: data
      } as ApiResponse<T>;
    } catch (error) {
      console.error('Request error:', error);
      if (error instanceof Error) {
        throw error;
      }
      throw new Error('Network error occurred');
    }
  }

  // Authentication Methods
  async login(credentials: LoginRequest): Promise<ApiResponse<LoginResponse>> {
    const response = await this.request<LoginResponse>('/auth/login', {
      method: 'POST',
      body: JSON.stringify(credentials),
    });

    if (response.success && response.data?.token) {
      this.token = response.data.token;
      localStorage.setItem(config.tokenStorageKey, this.token);
    }

    return response;
  }

  async logout(): Promise<ApiResponse> {
    const response = await this.request('/auth/logout', {
      method: 'POST',
    });

    this.clearToken();
    return response;
  }

  async healthCheck(): Promise<ApiResponse> {
    return this.request('/health');
  }

  // Session Methods
  async getSessions(): Promise<ApiResponse<Session[]>> {
    return this.request('/sessions');
  }

  async createSession(name: string): Promise<ApiResponse<Session>> {
    return this.request('/sessions', {
      method: 'POST',
      body: JSON.stringify({ name }),
    });
  }

  async deleteSession(sessionId: string): Promise<ApiResponse> {
    return this.request(`/sessions/${sessionId}`, {
      method: 'DELETE',
    });
  }

  async restartSession(sessionId: string): Promise<ApiResponse> {
    return this.request(`/sessions/${sessionId}/restart`, {
      method: 'POST',
    });
  }

  async getQRCode(sessionId: string): Promise<ApiResponse<{ qr: string; qrCode: string }>> {
    return this.request(`/sessions/${sessionId}/qr`);
  }

  async getSessionMetrics(sessionId: string): Promise<ApiResponse> {
    return this.request(`/sessions/${sessionId}/metrics`);
  }

  async getSessionsMetrics(): Promise<ApiResponse> {
    return this.request('/sessions/metrics');
  }

  async getMetricsOld(): Promise<ApiResponse> {
    return this.request('/metrics');
  }

  // Message Methods
  async sendMessage(messageData: { sessionId: string; phone: string; message: string; type: string }): Promise<ApiResponse> {
    return this.request('/messages/send', {
      method: 'POST',
      body: JSON.stringify(messageData),
    });
  }

  async getMessages(page = 1, limit = 20, sessionId?: string): Promise<ApiResponse<any[]>> {
    const params = new URLSearchParams({
      page: page.toString(),
      limit: limit.toString(),
    });
    
    if (sessionId) {
      params.append('sessionId', sessionId);
    }
    
    return this.request(`/messages?${params.toString()}`);
  }

  // Webhook management
  async configureWebhook(sessionId: string, webhookUrl: string, eventTypes?: string[]): Promise<ApiResponse> {
    return this.request('/webhooks/configure', {
      method: 'POST',
      body: JSON.stringify({
        sessionId,
        webhookUrl,
        eventTypes
      })
    });
  }

  async getSessionWebhook(sessionId: string): Promise<ApiResponse<any>> {
    return this.request(`/webhooks/${sessionId}`);
  }

  async removeWebhook(sessionId: string): Promise<ApiResponse> {
    return this.request(`/webhooks/${sessionId}`, {
      method: 'DELETE'
    });
  }

  async getWebhookEvents(sessionId: string, limit = 50, offset = 0): Promise<ApiResponse<any[]>> {
    const params = new URLSearchParams({
      limit: limit.toString(),
      offset: offset.toString()
    });
    
    return this.request(`/webhooks/events/${sessionId}?${params.toString()}`);
  }

  async testWebhook(sessionId: string): Promise<ApiResponse> {
    return this.request(`/webhooks/test/${sessionId}`, {
      method: 'POST'
    });
  }

  // User Management Methods
  async getUsers(): Promise<ApiResponse> {
    return this.request('/users');
  }

  async createUser(userData: any): Promise<ApiResponse> {
    return this.request('/users', {
      method: 'POST',
      body: JSON.stringify(userData),
    });
  }

  async updateUser(userId: string, userData: any): Promise<ApiResponse> {
    return this.request(`/users/${userId}`, {
      method: 'PUT',
      body: JSON.stringify(userData),
    });
  }

  async deleteUser(userId: string): Promise<ApiResponse> {
    return this.request(`/users/${userId}`, {
      method: 'DELETE',
    });
  }

  // Get metrics
  async getMetrics(): Promise<ApiResponse<any>> {
    return this.request('/metrics/dashboard');
  }

  // Get analytics
  async getAnalytics(): Promise<ApiResponse<any>> {
    return this.request('/analytics');
  }

  // Get logs
  async getLogs(params?: { limit?: number; level?: string }): Promise<ApiResponse<any>> {
    const query = new URLSearchParams();
    if (params?.limit) query.set('limit', params.limit.toString());
    if (params?.level) query.set('level', params.level);
    
    return this.request(`/logs${query.toString() ? '?' + query.toString() : ''}`);
  }

  // Get health
  async getHealth(): Promise<ApiResponse<any>> {
    return this.request('/health');
  }

  setToken(token: string) {
    this.token = token;
  }

  clearToken() {
    this.token = null;
    localStorage.removeItem(config.tokenStorageKey);
    sessionStorage.removeItem(config.tokenStorageKey);
  }

  getToken(): string | null {
    return this.token;
  }
}

export const apiClient = new ApiClient(config.apiUrl);