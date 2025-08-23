// API configuration and utilities
import { logger } from './logger';
import { config } from './config';

logger.info('API initialized', { baseUrl: config.apiUrl });

interface ApiResponse<T = any> {
  success?: boolean;
  data?: T;
  message?: string;
  error?: string;
}

interface LoginRequest {
  username: string;
  password: string;
}

interface LoginResponse {
  token: string;
  user: {
    id: string;
    username: string;
    role: 'admin' | 'operator' | 'viewer';
    lastLogin: string;
    status: 'active' | 'inactive';
  };
}

interface Session {
  id: string;
  name: string;
  phone?: string;
  status: 'disconnected' | 'connecting' | 'connected' | 'qr' | 'error';
  lastSeen?: string;
  messagesCount?: number;
  qrCode?: string;
}

class ApiClient {
  private baseURL: string;
  private token: string | null = null;

  constructor(baseURL: string) {
    this.baseURL = baseURL;
    this.token = localStorage.getItem(config.tokenStorageKey) || sessionStorage.getItem(config.tokenStorageKey);
  }

  private async request<T>(
    endpoint: string, 
    options: RequestInit = {}
  ): Promise<ApiResponse<T>> {
    const url = `${this.baseURL}${endpoint}`;
    
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      ...(options.headers as Record<string, string> || {}),
    };

    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }

    logger.debug('Making API request', { url, method: options.method || 'GET' });

    try {
      const response = await fetch(url, {
        ...options,
        headers,
        signal: AbortSignal.timeout(config.requestTimeout),
      });

      const contentType = response.headers.get('content-type');
      let data: any;

      if (contentType && contentType.includes('application/json')) {
        data = await response.json();
      } else {
        data = await response.text();
      }

      logger.debug('API response received', { status: response.status, url });

      if (!response.ok) {
        throw new Error(
          typeof data === 'object' && data.error 
            ? data.error 
            : `HTTP ${response.status}: ${response.statusText}`
        );
      }

      return { success: true, data };
    } catch (error) {
      logger.error('API request failed', { url, error: error instanceof Error ? error.message : 'Network error' });
      const errorMessage = error instanceof Error ? error.message : 'Network error';
      return { success: false, error: errorMessage };
    }
  }

  async login(credentials: LoginRequest): Promise<ApiResponse<LoginResponse>> {
    const response = await this.request<LoginResponse>('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify(credentials),
    });

    if (response.success && response.data?.token) {
      this.setToken(response.data.token);
    }

    return response;
  }

  async logout(): Promise<ApiResponse> {
    const response = await this.request('/api/auth/logout', {
      method: 'POST',
    });
    
    this.clearToken();
    return response;
  }

  async healthCheck(): Promise<ApiResponse> {
    return this.request('/health');
  }

  // Session Management Methods
  async getSessions(): Promise<ApiResponse<Session[]>> {
    return this.request<Session[]>('/api/sessions');
  }

  async createSession(name: string): Promise<ApiResponse<Session>> {
    return this.request<Session>('/api/sessions', {
      method: 'POST',
      body: JSON.stringify({ name }),
    });
  }

  async deleteSession(sessionId: string): Promise<ApiResponse> {
    return this.request(`/api/sessions/${sessionId}`, {
      method: 'DELETE',
    });
  }

  async restartSession(sessionId: string): Promise<ApiResponse> {
    return this.request(`/api/sessions/${sessionId}/restart`, {
      method: 'POST',
    });
  }

  async getQRCode(sessionId: string): Promise<ApiResponse<{ qr: string }>> {
    return this.request<{ qr: string }>(`/api/sessions/${sessionId}/qr`);
  }

  async getMetrics(): Promise<ApiResponse<any>> {
    return this.request('/api/metrics');
  }

  // Message Methods
  async sendMessage(messageData: { sessionId: string; phone: string; message: string; type: string }): Promise<ApiResponse> {
    return this.request('/api/messages/send', {
      method: 'POST',
      body: JSON.stringify(messageData),
    });
  }

  async getMessages(page = 1, limit = 20, sessionId?: string): Promise<ApiResponse> {
    const params = new URLSearchParams({
      page: page.toString(),
      limit: limit.toString(),
    });
    
    if (sessionId) {
      params.append('sessionId', sessionId);
    }
    
    return this.request(`/api/messages?${params.toString()}`);
  }

  // User Management Methods
  async getUsers(): Promise<ApiResponse> {
    return this.request('/api/users');
  }

  async createUser(userData: any): Promise<ApiResponse> {
    return this.request('/api/users', {
      method: 'POST',
      body: JSON.stringify(userData),
    });
  }

  async updateUser(userId: string, userData: any): Promise<ApiResponse> {
    return this.request(`/api/users/${userId}`, {
      method: 'PUT',
      body: JSON.stringify(userData),
    });
  }

  async deleteUser(userId: string): Promise<ApiResponse> {
    return this.request(`/api/users/${userId}`, {
      method: 'DELETE',
    });
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
export type { LoginRequest, LoginResponse, ApiResponse, Session };