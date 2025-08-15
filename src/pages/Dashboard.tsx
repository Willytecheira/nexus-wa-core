import { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Progress } from '@/components/ui/progress';
import { 
  Activity, 
  MessageSquare, 
  Smartphone, 
  Users, 
  TrendingUp,
  Clock,
  Cpu,
  HardDrive,
  Wifi,
  AlertCircle
} from 'lucide-react';
import { LineChart, Line, AreaChart, Area, PieChart, Pie, Cell, ResponsiveContainer, XAxis, YAxis, CartesianGrid, Tooltip, Legend } from 'recharts';
import { useAuth } from '@/contexts/AuthContext';

interface SystemMetrics {
  activeSessions: number;
  totalMessages: number;
  memoryUsage: number;
  cpuUsage: number;
  uptime: string;
  messagesPerHour: Array<{ time: string; messages: number; delivered: number }>;
  sessionStatus: Array<{ name: string; value: number; color: string }>;
  systemLoad: Array<{ time: string; cpu: number; memory: number; network: number }>;
}

// Mock real-time data generator
const generateMetrics = (): SystemMetrics => {
  const now = new Date();
  const messagesPerHour = Array.from({ length: 24 }, (_, i) => {
    const hour = new Date(now.getTime() - (23 - i) * 60 * 60 * 1000);
    return {
      time: hour.toTimeString().slice(0, 5),
      messages: Math.floor(Math.random() * 100) + 20,
      delivered: Math.floor(Math.random() * 95) + 85
    };
  });

  const systemLoad = Array.from({ length: 20 }, (_, i) => {
    const time = new Date(now.getTime() - (19 - i) * 60 * 1000);
    return {
      time: time.toTimeString().slice(0, 5),
      cpu: Math.floor(Math.random() * 40) + 20,
      memory: Math.floor(Math.random() * 30) + 40,
      network: Math.floor(Math.random() * 60) + 10
    };
  });

  return {
    activeSessions: 3,
    totalMessages: 1247,
    memoryUsage: 67,
    cpuUsage: 34,
    uptime: '7d 14h 32m',
    messagesPerHour,
    sessionStatus: [
      { name: 'Connected', value: 3, color: '#25D366' },
      { name: 'Disconnected', value: 0, color: '#FF6B6B' },
      { name: 'Initializing', value: 1, color: '#FFA726' }
    ],
    systemLoad
  };
};

export default function Dashboard() {
  const { user } = useAuth();
  const [metrics, setMetrics] = useState<SystemMetrics>(generateMetrics());
  const [lastUpdate, setLastUpdate] = useState(new Date());

  useEffect(() => {
    const interval = setInterval(() => {
      setMetrics(generateMetrics());
      setLastUpdate(new Date());
    }, 30000); // Update every 30 seconds

    return () => clearInterval(interval);
  }, []);

  const getGreeting = () => {
    const hour = new Date().getHours();
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  };

  const stats = [
    {
      title: 'Active Sessions',
      value: metrics.activeSessions,
      change: '+2',
      icon: Smartphone,
      color: 'text-whatsapp-primary',
      bg: 'bg-whatsapp-primary/10'
    },
    {
      title: 'Messages Today',
      value: metrics.totalMessages,
      change: '+156',
      icon: MessageSquare,
      color: 'text-status-info',
      bg: 'bg-status-info/10'
    },
    {
      title: 'Delivery Rate',
      value: '98.2%',
      change: '+0.5%',
      icon: TrendingUp,
      color: 'text-status-success',
      bg: 'bg-status-success/10'
    },
    {
      title: 'System Uptime',
      value: metrics.uptime,
      change: 'Stable',
      icon: Activity,
      color: 'text-status-warning',
      bg: 'bg-status-warning/10'
    }
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-2">
        <h1 className="text-3xl font-bold tracking-tight">
          {getGreeting()}, {user?.username}!
        </h1>
        <p className="text-muted-foreground">
          Here's what's happening with your WhatsApp API today.
        </p>
        <div className="flex items-center gap-2 text-sm text-muted-foreground">
          <Clock className="h-4 w-4" />
          Last updated: {lastUpdate.toLocaleTimeString()}
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        {stats.map((stat, index) => (
          <Card key={index} className="hover:shadow-card transition-shadow">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">{stat.title}</CardTitle>
              <div className={`p-2 rounded-lg ${stat.bg}`}>
                <stat.icon className={`h-4 w-4 ${stat.color}`} />
              </div>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stat.value}</div>
              <p className="text-xs text-muted-foreground">
                <span className="text-status-success">↗ {stat.change}</span> from yesterday
              </p>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Charts Row */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {/* Messages Chart */}
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>Message Traffic</CardTitle>
            <CardDescription>Messages sent and delivered over the last 24 hours</CardDescription>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <AreaChart data={metrics.messagesPerHour}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="time" />
                <YAxis />
                <Tooltip />
                <Legend />
                <Area 
                  type="monotone" 
                  dataKey="messages" 
                  stackId="1"
                  stroke="hsl(var(--whatsapp-primary))" 
                  fill="hsl(var(--whatsapp-primary))" 
                  fillOpacity={0.6}
                  name="Sent"
                />
                <Area 
                  type="monotone" 
                  dataKey="delivered" 
                  stackId="2"
                  stroke="hsl(var(--status-success))" 
                  fill="hsl(var(--status-success))" 
                  fillOpacity={0.6}
                  name="Delivered"
                />
              </AreaChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        {/* Session Status */}
        <Card>
          <CardHeader>
            <CardTitle>Session Status</CardTitle>
            <CardDescription>Current status of all WhatsApp sessions</CardDescription>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={metrics.sessionStatus}
                  cx="50%"
                  cy="50%"
                  innerRadius={60}
                  outerRadius={100}
                  paddingAngle={5}
                  dataKey="value"
                >
                  {metrics.sessionStatus.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip />
                <Legend />
              </PieChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </div>

      {/* System Performance */}
      <div className="grid gap-4 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>System Performance</CardTitle>
            <CardDescription>Real-time system metrics</CardDescription>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={200}>
              <LineChart data={metrics.systemLoad}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="time" />
                <YAxis />
                <Tooltip />
                <Legend />
                <Line 
                  type="monotone" 
                  dataKey="cpu" 
                  stroke="hsl(var(--status-warning))" 
                  strokeWidth={2}
                  name="CPU %"
                />
                <Line 
                  type="monotone" 
                  dataKey="memory" 
                  stroke="hsl(var(--status-info))" 
                  strokeWidth={2}
                  name="Memory %"
                />
                <Line 
                  type="monotone" 
                  dataKey="network" 
                  stroke="hsl(var(--whatsapp-primary))" 
                  strokeWidth={2}
                  name="Network %"
                />
              </LineChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        {/* Resource Usage */}
        <Card>
          <CardHeader>
            <CardTitle>Resource Usage</CardTitle>
            <CardDescription>Current system resource consumption</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Cpu className="h-4 w-4 text-status-warning" />
                  <span className="text-sm font-medium">CPU Usage</span>
                </div>
                <span className="text-sm text-muted-foreground">{metrics.cpuUsage}%</span>
              </div>
              <Progress value={metrics.cpuUsage} className="h-2" />
            </div>

            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <HardDrive className="h-4 w-4 text-status-info" />
                  <span className="text-sm font-medium">Memory Usage</span>
                </div>
                <span className="text-sm text-muted-foreground">{metrics.memoryUsage}%</span>
              </div>
              <Progress value={metrics.memoryUsage} className="h-2" />
            </div>

            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Wifi className="h-4 w-4 text-whatsapp-primary" />
                  <span className="text-sm font-medium">Network I/O</span>
                </div>
                <span className="text-sm text-muted-foreground">Active</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="h-2 w-2 bg-status-success rounded-full animate-pulse"></div>
                <span className="text-xs text-muted-foreground">All connections stable</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Alerts */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <AlertCircle className="h-5 w-5" />
            System Alerts
          </CardTitle>
          <CardDescription>Recent system events and notifications</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            <div className="flex items-center gap-3 p-3 bg-status-success/10 rounded-lg border border-status-success/20">
              <div className="w-2 h-2 bg-status-success rounded-full"></div>
              <div className="flex-1">
                <p className="text-sm font-medium">All systems operational</p>
                <p className="text-xs text-muted-foreground">Last checked: {new Date().toLocaleTimeString()}</p>
              </div>
              <Badge variant="secondary" className="bg-status-success/20 text-status-success">
                Healthy
              </Badge>
            </div>
            
            <div className="flex items-center gap-3 p-3 bg-muted/50 rounded-lg">
              <div className="w-2 h-2 bg-status-info rounded-full"></div>
              <div className="flex-1">
                <p className="text-sm font-medium">Session 'Business-01' reconnected</p>
                <p className="text-xs text-muted-foreground">2 minutes ago</p>
              </div>
              <Badge variant="secondary" className="bg-status-info/20 text-status-info">
                Info
              </Badge>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}