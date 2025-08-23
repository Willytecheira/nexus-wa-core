import React from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { Badge } from '@/components/ui/badge';
import { Session } from '@/lib/api';
import { 
  MoreVertical, 
  Smartphone, 
  MessageSquare, 
  Clock,
  QrCode,
  RotateCcw,
  Trash2,
  Wifi,
  WifiOff,
  AlertCircle,
  Activity,
  TrendingUp,
  TrendingDown
} from 'lucide-react';

interface SessionCardProps {
  session: Session;
  onShowQR: (session: Session) => void;
  onRestart: (sessionId: string) => void;
  onDelete: (sessionId: string) => void;
}

export function SessionCard({ session, onShowQR, onRestart, onDelete }: SessionCardProps) {
  const getStatusColor = (status: string) => {
    switch (status) {
      case 'ready': return 'bg-green-500 text-white';
      case 'connecting': case 'qr': case 'authenticated': return 'bg-yellow-500 text-white';
      case 'disconnected': return 'bg-red-500 text-white';
      default: return 'bg-gray-500 text-white';
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'ready': return Wifi;
      case 'connecting': case 'qr': case 'authenticated': return Clock;
      case 'disconnected': return WifiOff;
      default: return AlertCircle;
    }
  };

  const formatUptime = (seconds?: number) => {
    if (!seconds || seconds < 0) return '0m';
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    if (hours > 0) return `${hours}h ${minutes}m`;
    return `${minutes}m`;
  };

  const formatLastActivity = (seconds?: number) => {
    if (!seconds) return 'Now';
    if (seconds < 60) return 'Just now';
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);
    
    if (days > 0) return `${days}d ago`;
    if (hours > 0) return `${hours}h ago`;
    return `${minutes}m ago`;
  };

  const StatusIcon = getStatusIcon(session.status);
  const isOnline = session.status === 'ready';
  const totalMessages = (session.messages_sent || 0) + (session.messages_received || 0);

  return (
    <Card className="hover:shadow-md transition-all duration-200 border-l-4" 
          style={{ borderLeftColor: isOnline ? '#10b981' : '#ef4444' }}>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-3">
        <div className="flex items-center gap-3">
          <div className={`p-2 rounded-full ${isOnline ? 'bg-green-100 text-green-600' : 'bg-red-100 text-red-600'}`}>
            <StatusIcon className="h-4 w-4" />
          </div>
          <div>
            <CardTitle className="text-lg font-semibold">{session.name}</CardTitle>
            <CardDescription className="text-sm text-muted-foreground">
              {session.phone_number || 'Not connected'}
            </CardDescription>
          </div>
        </div>
        
        <div className="flex items-center gap-2">
          <Badge className={getStatusColor(session.status)} variant="outline">
            {session.status}
          </Badge>
          
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" className="h-8 w-8 p-0">
                <MoreVertical className="h-4 w-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="bg-background border shadow-md">
              <DropdownMenuItem onClick={() => onShowQR(session)} className="hover:bg-muted">
                <QrCode className="mr-2 h-4 w-4" />
                Show QR
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => onRestart(session.id)} className="hover:bg-muted">
                <RotateCcw className="mr-2 h-4 w-4" />
                Restart
              </DropdownMenuItem>
              <DropdownMenuItem 
                onClick={() => onDelete(session.id)} 
                className="text-destructive hover:bg-destructive/10"
              >
                <Trash2 className="mr-2 h-4 w-4" />
                Delete
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </CardHeader>

      <CardContent className="space-y-4">
        {/* Activity Metrics */}
        <div className="grid grid-cols-2 gap-4">
          <div className="flex items-center gap-2">
            <div className="p-1.5 rounded bg-blue-100 text-blue-600">
              <Clock className="h-3 w-3" />
            </div>
            <div>
              <p className="text-xs text-muted-foreground">Uptime</p>
              <p className="text-sm font-medium">
                {formatUptime(session.current_uptime_seconds)}
              </p>
            </div>
          </div>
          
          <div className="flex items-center gap-2">
            <div className="p-1.5 rounded bg-purple-100 text-purple-600">
              <Activity className="h-3 w-3" />
            </div>
            <div>
              <p className="text-xs text-muted-foreground">Last Active</p>
              <p className="text-sm font-medium">
                {formatLastActivity(session.seconds_since_last_activity)}
              </p>
            </div>
          </div>
        </div>

        {/* Message Statistics */}
        <div className="grid grid-cols-3 gap-3 pt-2 border-t">
          <div className="text-center">
            <div className="flex items-center justify-center gap-1 mb-1">
              <TrendingUp className="h-3 w-3 text-green-600" />
              <span className="text-xs text-muted-foreground">Sent</span>
            </div>
            <p className="text-lg font-bold text-green-600">{session.messages_sent || 0}</p>
          </div>
          
          <div className="text-center">
            <div className="flex items-center justify-center gap-1 mb-1">
              <TrendingDown className="h-3 w-3 text-blue-600" />
              <span className="text-xs text-muted-foreground">Received</span>
            </div>
            <p className="text-lg font-bold text-blue-600">{session.messages_received || 0}</p>
          </div>
          
          <div className="text-center">
            <div className="flex items-center justify-center gap-1 mb-1">
              <MessageSquare className="h-3 w-3 text-purple-600" />
              <span className="text-xs text-muted-foreground">Total</span>
            </div>
            <p className="text-lg font-bold text-purple-600">{totalMessages}</p>
          </div>
        </div>

        {/* Error Count */}
        {session.error_count > 0 && (
          <div className="flex items-center gap-2 p-2 bg-red-50 rounded-lg border border-red-200">
            <AlertCircle className="h-4 w-4 text-red-600" />
            <span className="text-sm text-red-700">
              {session.error_count} error{session.error_count > 1 ? 's' : ''} detected
            </span>
          </div>
        )}
      </CardContent>
    </Card>
  );
}