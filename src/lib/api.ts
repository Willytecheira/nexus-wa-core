// API configuration and utilities
const API_BASE_URL = import.meta.env.VITE_API_URL || (
  window.location.hostname === 'localhost' 
    ? 'http://localhost:3000'
    : window.location.origin
);

console.log('API_BASE_URL:', API_BASE_URL);

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
    this.token = localStorage.getItem('auth_token') || sessionStorage.getItem('auth_token');
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

    console.log(`Making API request to: ${url}`, { method: options.method || 'GET' });

    try {
      const response = await fetch(url, {
        ...options,
        headers,
      });

      const contentType = response.headers.get('content-type');
      let data: any;

      if (contentType && contentType.includes('application/json')) {
        data = await response.json();
      } else {
        data = await response.text();
      }

      console.log(`API Response (${response.status}):`, data);

      if (!response.ok) {
        throw new Error(
          typeof data === 'object' && data.error 
            ? data.error 
            : `HTTP ${response.status}: ${response.statusText}`
        );
      }

      return { success: true, data };
    } catch (error) {
      console.error(`API Error for ${url}:`, error);
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
    localStorage.removeItem('auth_token');
    sessionStorage.removeItem('auth_token');
  }

  getToken(): string | null {
    return this.token;
  }
}

export const apiClient = new ApiClient(API_BASE_URL);
export type { LoginRequest, LoginResponse, ApiResponse };