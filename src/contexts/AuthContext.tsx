import React, { createContext, useContext, useState, useEffect } from 'react';
import { useToast } from '@/hooks/use-toast';
import { apiClient, type LoginResponse } from '@/lib/api';

interface User {
  id: string;
  username: string;
  role: 'admin' | 'operator' | 'viewer';
  lastLogin: string;
  status: 'active' | 'inactive';
}

interface AuthContextType {
  user: User | null;
  isAuthenticated: boolean;
  login: (username: string, password: string, rememberMe?: boolean) => Promise<boolean>;
  logout: () => void;
  loading: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const { toast } = useToast();

  useEffect(() => {
    const initializeAuth = async () => {
      // Check for stored auth
      const storedUser = localStorage.getItem('auth_user') || sessionStorage.getItem('auth_user');
      const storedToken = localStorage.getItem('auth_token') || sessionStorage.getItem('auth_token');
      
      if (storedUser && storedToken) {
        try {
          const parsedUser = JSON.parse(storedUser);
          
          // Verify token format and expiration
          if (storedToken.includes('.')) {
            const tokenParts = storedToken.split('.');
            if (tokenParts.length === 3) {
              const payload = JSON.parse(atob(tokenParts[1]));
              if (payload.exp * 1000 > Date.now()) {
                apiClient.setToken(storedToken);
                setUser(parsedUser);
                console.log('Auth restored for user:', parsedUser.username);
              } else {
                console.log('Token expired, clearing auth');
                clearStoredAuth();
              }
            } else {
              console.log('Invalid token format, clearing auth');
              clearStoredAuth();
            }
          } else {
            console.log('Invalid token format, clearing auth');
            clearStoredAuth();
          }
        } catch (error) {
          console.error('Auth restore error:', error);
          clearStoredAuth();
        }
      } else {
        console.log('No stored auth found');
      }
      
      setLoading(false);
    };

    const clearStoredAuth = () => {
      localStorage.removeItem('auth_user');
      localStorage.removeItem('auth_token');
      sessionStorage.removeItem('auth_user');
      sessionStorage.removeItem('auth_token');
      apiClient.clearToken();
    };

    initializeAuth();
  }, []);

  const login = async (username: string, password: string, rememberMe = false): Promise<boolean> => {
    setLoading(true);
    
    try {
      console.log('Attempting login for:', username);
      
      const response = await apiClient.login({ username, password });
      
      if (!response.success || !response.data) {
        toast({
          title: "Login Failed",
          description: response.error || "Invalid username or password",
          variant: "destructive"
        });
        return false;
      }

      const { token, user: userData } = response.data;
      
      if (!userData || !token) {
        toast({
          title: "Login Failed",
          description: "Invalid response from server",
          variant: "destructive"
        });
        return false;
      }

      // Update user with current timestamp
      const updatedUser: User = {
        ...userData,
        lastLogin: new Date().toISOString()
      };

      setUser(updatedUser);
      
      // Store auth data
      const storage = rememberMe ? localStorage : sessionStorage;
      storage.setItem('auth_user', JSON.stringify(updatedUser));
      storage.setItem('auth_token', token);
      
      // Set token in API client
      apiClient.setToken(token);

      toast({
        title: "Welcome back!",
        description: `Logged in as ${updatedUser.username} (${updatedUser.role})`
      });

      console.log('Login successful for:', updatedUser.username);
      return true;
    } catch (error) {
      console.error('Login error:', error);
      toast({
        title: "Login Error",
        description: error instanceof Error ? error.message : "An unexpected error occurred. Please try again.",
        variant: "destructive"
      });
      return false;
    } finally {
      setLoading(false);
    }
  };

  const logout = async () => {
    try {
      // Call logout endpoint
      await apiClient.logout();
    } catch (error) {
      console.error('Logout API error:', error);
      // Continue with local logout even if API fails
    }
    
    setUser(null);
    localStorage.removeItem('auth_user');
    localStorage.removeItem('auth_token');
    sessionStorage.removeItem('auth_user');
    sessionStorage.removeItem('auth_token');
    apiClient.clearToken();
    
    toast({
      title: "Logged out",
      description: "You have been successfully logged out"
    });
  };

  return (
    <AuthContext.Provider value={{
      user,
      isAuthenticated: !!user,
      login,
      logout,
      loading
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}