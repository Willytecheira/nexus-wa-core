import { useAuth } from '@/contexts/AuthContext';
import { AppSidebar } from '@/components/AppSidebar';
import { SidebarProvider, SidebarTrigger } from '@/components/ui/sidebar';
import { Button } from '@/components/ui/button';
import { MoonIcon, SunIcon, User, LogOut } from 'lucide-react';
import { useTheme } from 'next-themes';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';

interface LayoutProps {
  children: React.ReactNode;
}

export function Layout({ children }: LayoutProps) {
  const { user, logout } = useAuth();
  const { theme, setTheme } = useTheme();

  const getRoleColor = (role: string) => {
    switch (role) {
      case 'admin': return 'bg-gradient-primary text-white';
      case 'operator': return 'bg-status-info text-white';
      case 'viewer': return 'bg-muted text-foreground';
      default: return 'bg-muted text-foreground';
    }
  };

  return (
    <SidebarProvider>
      <div className="min-h-screen flex w-full bg-gradient-bg">
        {/* Header */}
        <header className="fixed top-0 left-0 right-0 h-16 bg-card/80 backdrop-blur-md border-b border-border z-50 flex items-center justify-between px-4">
          <div className="flex items-center gap-3">
            <SidebarTrigger className="hover:bg-accent hover:text-accent-foreground" />
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 bg-gradient-primary rounded-lg flex items-center justify-center">
                <span className="text-white font-bold text-sm">WA</span>
              </div>
              <div>
                <h1 className="font-semibold text-lg">WhatsApp API</h1>
                <p className="text-xs text-muted-foreground">Multi-Session Manager</p>
              </div>
            </div>
          </div>

          <div className="flex items-center gap-3">
            {/* Theme Toggle */}
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
              className="w-9 h-9 p-0"
            >
              <SunIcon className="h-4 w-4 rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0" />
              <MoonIcon className="absolute h-4 w-4 rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100" />
              <span className="sr-only">Toggle theme</span>
            </Button>

            {/* User Menu */}
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" className="flex items-center gap-2 h-9">
                  <Avatar className="h-7 w-7">
                    <AvatarFallback className="bg-gradient-primary text-white text-xs">
                      {user?.username.charAt(0).toUpperCase()}
                    </AvatarFallback>
                  </Avatar>
                  <div className="flex flex-col items-start">
                    <span className="text-sm font-medium">{user?.username}</span>
                    <Badge variant="secondary" className={`text-xs ${getRoleColor(user?.role || '')}`}>
                      {user?.role}
                    </Badge>
                  </div>
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-56">
                <DropdownMenuLabel>
                  <div className="flex flex-col">
                    <span>{user?.username}</span>
                    <span className="font-normal text-muted-foreground text-xs">
                      {user?.role} account
                    </span>
                  </div>
                </DropdownMenuLabel>
                <DropdownMenuSeparator />
                <DropdownMenuItem>
                  <User className="mr-2 h-4 w-4" />
                  <span>Profile</span>
                </DropdownMenuItem>
                <DropdownMenuSeparator />
                <DropdownMenuItem onClick={logout} className="text-destructive">
                  <LogOut className="mr-2 h-4 w-4" />
                  <span>Logout</span>
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </header>

        {/* Sidebar */}
        <AppSidebar />

        {/* Main Content */}
        <main className="flex-1 pt-16 overflow-auto">
          <div className="p-6">
            {children}
          </div>
        </main>
      </div>
    </SidebarProvider>
  );
}