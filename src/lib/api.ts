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
export type { LoginRequest, LoginResponse, ApiResponse };