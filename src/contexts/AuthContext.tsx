import React, { createContext, useContext, useState, useEffect } from 'react';
import { useToast } from '@/hooks/use-toast';

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

// Default admin user for demo
const DEFAULT_ADMIN: User = {
  id: '1',
  username: 'admin',
  role: 'admin',
  lastLogin: new Date().toISOString(),
  status: 'active'
};

const DEFAULT_USERS = [
  DEFAULT_ADMIN,
  {
    id: '2',
    username: 'operator',
    role: 'operator' as const,
    lastLogin: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(),
    status: 'active' as const
  },
  {
    id: '3', 
    username: 'viewer',
    role: 'viewer' as const,
    lastLogin: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString(),
    status: 'active' as const
  }
];

const DEFAULT_PASSWORDS = {
  admin: 'admin123',
  operator: 'operator123',
  viewer: 'viewer123'
};

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const { toast } = useToast();

  useEffect(() => {
    // Check for stored auth
    const storedUser = localStorage.getItem('auth_user');
    const storedToken = localStorage.getItem('auth_token');
    
    if (storedUser && storedToken) {
      try {
        const parsedUser = JSON.parse(storedUser);
        // Verify token isn't expired (24h)
        const tokenData = JSON.parse(atob(storedToken.split('.')[1]));
        if (tokenData.exp * 1000 > Date.now()) {
          setUser(parsedUser);
        } else {
          localStorage.removeItem('auth_user');
          localStorage.removeItem('auth_token');
        }
      } catch (error) {
        console.error('Auth restore error:', error);
        localStorage.removeItem('auth_user');
        localStorage.removeItem('auth_token');
      }
    }
    
    setLoading(false);
  }, []);

  const login = async (username: string, password: string, rememberMe = false): Promise<boolean> => {
    setLoading(true);
    
    try {
      // Simulate API call delay
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Check credentials
      const userRecord = DEFAULT_USERS.find(u => u.username === username);
      const validPassword = DEFAULT_PASSWORDS[username as keyof typeof DEFAULT_PASSWORDS];
      
      if (!userRecord || password !== validPassword) {
        toast({
          title: "Login Failed",
          description: "Invalid username or password",
          variant: "destructive"
        });
        return false;
      }

      if (userRecord.status === 'inactive') {
        toast({
          title: "Account Disabled",
          description: "Your account has been disabled. Contact administrator.",
          variant: "destructive"
        });
        return false;
      }

      // Update last login
      const updatedUser = {
        ...userRecord,
        lastLogin: new Date().toISOString()
      };

      // Create JWT-like token (for demo)
      const token = btoa(JSON.stringify({
        userId: updatedUser.id,
        username: updatedUser.username,
        role: updatedUser.role,
        iat: Math.floor(Date.now() / 1000),
        exp: Math.floor(Date.now() / 1000) + (24 * 60 * 60) // 24h
      }));

      setUser(updatedUser);
      
      if (rememberMe) {
        localStorage.setItem('auth_user', JSON.stringify(updatedUser));
        localStorage.setItem('auth_token', `header.${token}.signature`);
      } else {
        sessionStorage.setItem('auth_user', JSON.stringify(updatedUser));
        sessionStorage.setItem('auth_token', `header.${token}.signature`);
      }

      toast({
        title: "Welcome back!",
        description: `Logged in as ${updatedUser.username} (${updatedUser.role})`
      });

      return true;
    } catch (error) {
      console.error('Login error:', error);
      toast({
        title: "Login Error",
        description: "An unexpected error occurred. Please try again.",
        variant: "destructive"
      });
      return false;
    } finally {
      setLoading(false);
    }
  };

  const logout = () => {
    setUser(null);
    localStorage.removeItem('auth_user');
    localStorage.removeItem('auth_token');
    sessionStorage.removeItem('auth_user');
    sessionStorage.removeItem('auth_token');
    
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