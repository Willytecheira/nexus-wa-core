import { useState } from 'react';
import { useLocation, NavLink } from 'react-router-dom';
import {
  LayoutDashboard,
  MessageSquare,
  Users,
  Settings,
  BarChart3,
  Shield,
  Smartphone,
  Send,
  Database,
  Activity
} from 'lucide-react';
import {
  Sidebar,
  SidebarContent,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  useSidebar,
} from '@/components/ui/sidebar';
import { Badge } from '@/components/ui/badge';
import { useAuth } from '@/contexts/AuthContext';

const menuItems = [
  {
    title: 'Dashboard',
    url: '/',
    icon: LayoutDashboard,
    description: 'System overview',
    roles: ['admin', 'operator', 'viewer']
  },
  {
    title: 'Sessions',
    url: '/sessions',
    icon: Smartphone,
    description: 'WhatsApp sessions',
    roles: ['admin', 'operator'],
    badge: '3'
  },
  {
    title: 'Messages',
    url: '/messages',
    icon: Send,
    description: 'Send & manage messages',
    roles: ['admin', 'operator']
  },
  {
    title: 'Analytics',
    url: '/analytics',
    icon: BarChart3,
    description: 'Usage metrics',
    roles: ['admin', 'operator', 'viewer']
  },
  {
    title: 'Users',
    url: '/users',
    icon: Users,
    description: 'User management',
    roles: ['admin']
  }
];

const systemItems = [
  {
    title: 'Logs',
    url: '/logs',
    icon: Database,
    description: 'System logs',
    roles: ['admin']
  },
  {
    title: 'Health',
    url: '/health',
    icon: Activity,
    description: 'System health',
    roles: ['admin', 'operator']
  },
  {
    title: 'Settings',
    url: '/settings',
    icon: Settings,
    description: 'Configuration',
    roles: ['admin']
  }
];

export function AppSidebar() {
  const { state } = useSidebar();
  const location = useLocation();
  const { user } = useAuth();
  const currentPath = location.pathname;
  const collapsed = state === 'collapsed';

  const isActive = (path: string) => {
    if (path === '/') return currentPath === '/';
    return currentPath.startsWith(path);
  };

  const hasAccess = (roles: string[]) => {
    return user && roles.includes(user.role);
  };

  const getNavClass = (path: string) => {
    const active = isActive(path);
    return active 
      ? "bg-whatsapp-primary text-white hover:bg-whatsapp-primary/90" 
      : "hover:bg-accent hover:text-accent-foreground";
  };

  const filteredMenuItems = menuItems.filter(item => hasAccess(item.roles));
  const filteredSystemItems = systemItems.filter(item => hasAccess(item.roles));

  return (
    <Sidebar className={collapsed ? "w-16" : "w-64"} collapsible="icon">
      <SidebarContent className="p-2">
        {/* Main Navigation */}
        <SidebarGroup>
          <SidebarGroupLabel className={collapsed ? "sr-only" : ""}>
            Navigation
          </SidebarGroupLabel>
          <SidebarGroupContent>
            <SidebarMenu>
              {filteredMenuItems.map((item) => (
                <SidebarMenuItem key={item.title}>
                  <SidebarMenuButton asChild>
                    <NavLink 
                      to={item.url} 
                      end={item.url === '/'}
                      className={getNavClass(item.url)}
                    >
                      <item.icon className="h-4 w-4" />
                      {!collapsed && (
                        <>
                          <div className="flex-1">
                            <div className="font-medium">{item.title}</div>
                            <div className="text-xs opacity-70">{item.description}</div>
                          </div>
                          {item.badge && (
                            <Badge variant="secondary" className="ml-auto bg-whatsapp-light text-whatsapp-dark">
                              {item.badge}
                            </Badge>
                          )}
                        </>
                      )}
                    </NavLink>
                  </SidebarMenuButton>
                </SidebarMenuItem>
              ))}
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>

        {/* System */}
        {filteredSystemItems.length > 0 && (
          <SidebarGroup>
            <SidebarGroupLabel className={collapsed ? "sr-only" : ""}>
              System
            </SidebarGroupLabel>
            <SidebarGroupContent>
              <SidebarMenu>
                {filteredSystemItems.map((item) => (
                  <SidebarMenuItem key={item.title}>
                    <SidebarMenuButton asChild>
                      <NavLink 
                        to={item.url}
                        className={getNavClass(item.url)}
                      >
                        <item.icon className="h-4 w-4" />
                        {!collapsed && (
                          <div className="flex-1">
                            <div className="font-medium">{item.title}</div>
                            <div className="text-xs opacity-70">{item.description}</div>
                          </div>
                        )}
                      </NavLink>
                    </SidebarMenuButton>
                  </SidebarMenuItem>
                ))}
              </SidebarMenu>
            </SidebarGroupContent>
          </SidebarGroup>
        )}

        {/* Status Indicator */}
        {!collapsed && (
          <SidebarGroup className="mt-auto">
            <div className="p-3 bg-card rounded-lg border">
              <div className="flex items-center gap-2 mb-2">
                <div className="w-2 h-2 bg-status-online rounded-full animate-pulse"></div>
                <span className="text-sm font-medium">System Status</span>
              </div>
              <div className="text-xs text-muted-foreground">
                All services operational
              </div>
            </div>
          </SidebarGroup>
        )}
      </SidebarContent>
    </Sidebar>
  );
}