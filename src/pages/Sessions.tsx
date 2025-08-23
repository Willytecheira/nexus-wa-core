import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { Separator } from '@/components/ui/separator';
import { useToast } from '@/hooks/use-toast';
import { apiClient, Session } from '@/lib/api';
import { SessionCard } from '@/components/SessionCard';
import { 
  Plus, 
  Smartphone, 
  MessageSquare, 
  Clock,
  Loader2,
  RefreshCw,
  Activity,
  Users,
  QrCode
} from 'lucide-react';

export default function Sessions() {
  const [sessions, setSessions] = useState<Session[]>([]);
  const [isCreateDialogOpen, setIsCreateDialogOpen] = useState(false);
  const [isQrDialogOpen, setIsQrDialogOpen] = useState(false);
  const [selectedSession, setSelectedSession] = useState<Session | null>(null);
  const [newSessionName, setNewSessionName] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [isCreating, setIsCreating] = useState(false);
  const [qrCode, setQrCode] = useState<string>('');
  const { toast } = useToast();

  // Load sessions on component mount
  useEffect(() => {
    loadSessions();
  }, []);

  // Auto-refresh sessions every 30 seconds
  useEffect(() => {
    const interval = setInterval(() => {
      if (!isLoading) {
        loadSessions();
      }
    }, 30000);

    return () => clearInterval(interval);
  }, [isLoading]);

  const loadSessions = async () => {
    try {
      const response = await apiClient.getSessionsMetrics();
      if (response.success && response.data) {
        setSessions(response.data);
      } else {
        toast({
          title: "Error",
          description: response.error || "Failed to load sessions",
          variant: "destructive"
        });
      }
    } catch (error) {
      console.error('Load sessions error:', error);
      toast({
        title: "Error",
        description: "Failed to load sessions",
        variant: "destructive"
      });
    } finally {
      setIsLoading(false);
    }
  };

  // Calculate overview metrics
  const totalSessions = sessions.length;
  const activeSessions = sessions.filter(s => s.status === 'ready').length;
  const totalMessages = sessions.reduce((sum, s) => sum + (s.messages_sent || 0) + (s.messages_received || 0), 0);
  const totalUptime = sessions
    .filter(s => s.current_uptime_seconds)
    .reduce((sum, s) => sum + (s.current_uptime_seconds || 0), 0);

  const formatTotalUptime = (seconds: number) => {
    const hours = Math.floor(seconds / 3600);
    if (hours > 24) {
      const days = Math.floor(hours / 24);
      return `${days}d ${hours % 24}h`;
    }
    return `${hours}h ${Math.floor((seconds % 3600) / 60)}m`;
  };

  const handleCreateSession = async () => {
    if (!newSessionName.trim()) return;

    setIsCreating(true);
    try {
      const response = await apiClient.createSession(newSessionName.trim());
      if (response.success) {
        toast({
          title: "Success",
          description: "Session created successfully"
        });
        setNewSessionName('');
        setIsCreateDialogOpen(false);
        await loadSessions();
      } else {
        toast({
          title: "Error",
          description: response.error || "Failed to create session",
          variant: "destructive"
        });
      }
    } catch (error) {
      console.error('Create session error:', error);
      toast({
        title: "Error",
        description: "Failed to create session",
        variant: "destructive"
      });
    } finally {
      setIsCreating(false);
    }
  };

  const handleDeleteSession = async (sessionId: string) => {
    try {
      const response = await apiClient.deleteSession(sessionId);
      if (response.success) {
        toast({
          title: "Success",
          description: "Session deleted successfully"
        });
        setSessions(sessions.filter(s => s.id !== sessionId));
      } else {
        toast({
          title: "Error",
          description: response.error || "Failed to delete session",
          variant: "destructive"
        });
      }
    } catch (error) {
      console.error('Delete session error:', error);
      toast({
        title: "Error",
        description: "Failed to delete session",
        variant: "destructive"
      });
    }
  };

  const handleRestartSession = async (sessionId: string) => {
    try {
      const response = await apiClient.restartSession(sessionId);
      if (response.success) {
        toast({
          title: "Success",
          description: "Session restarted successfully"
        });
        // Update the session status
        setSessions(sessions.map(s => 
          s.id === sessionId ? { ...s, status: 'connecting' as const } : s
        ));
      } else {
        toast({
          title: "Error",
          description: response.error || "Failed to restart session",
          variant: "destructive"
        });
      }
    } catch (error) {
      console.error('Restart session error:', error);
      toast({
        title: "Error",
        description: "Failed to restart session",
        variant: "destructive"
      });
    }
  };

  const showQrCode = async (session: Session) => {
    try {
      const response = await apiClient.getQRCode(session.id);
      if (response.success && response.data?.qr) {
        setQrCode(response.data.qr);
        setSelectedSession(session);
        setIsQrDialogOpen(true);
      } else {
        // Try to restart and get QR
        await handleRestartAndShowQr(session.id);
      }
    } catch (error) {
      console.error('Get QR code error:', error);
      toast({
        title: "Error",
        description: "Failed to get QR code",
        variant: "destructive"
      });
    }
  };

  const handleRestartAndShowQr = async (sessionId: string) => {
    try {
      const restartResponse = await apiClient.restartSession(sessionId);
      if (restartResponse.success) {
        // Wait a moment for QR to be generated
        setTimeout(async () => {
          const qrResponse = await apiClient.getQRCode(sessionId);
          if (qrResponse.success && qrResponse.data?.qr) {
            setQrCode(qrResponse.data.qr);
            const session = sessions.find(s => s.id === sessionId);
            if (session) {
              setSelectedSession(session);
              setIsQrDialogOpen(true);
            }
          } else {
            toast({
              title: "Error",
              description: "Failed to generate QR code after restart",
              variant: "destructive"
            });
          }
        }, 3000);
      }
    } catch (error) {
      console.error('Restart and show QR error:', error);
      toast({
        title: "Error",
        description: "Failed to restart session",
        variant: "destructive"
      });
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Sessions</h1>
          <p className="text-muted-foreground">
            Manage your WhatsApp sessions and connections
          </p>
        </div>
        
        <div className="flex gap-2">
          <Button variant="outline" onClick={loadSessions} disabled={isLoading} className="gap-2">
            <RefreshCw className={`h-4 w-4 ${isLoading ? 'animate-spin' : ''}`} />
            Refresh
          </Button>
          
          <Dialog open={isCreateDialogOpen} onOpenChange={setIsCreateDialogOpen}>
            <DialogTrigger asChild>
              <Button className="gap-2">
                <Plus className="h-4 w-4" />
                New Session
              </Button>
            </DialogTrigger>
            <DialogContent className="sm:max-w-[425px]">
              <DialogHeader>
                <DialogTitle>Create New Session</DialogTitle>
                <DialogDescription>
                  Create a new WhatsApp session. You'll need to scan a QR code to connect.
                </DialogDescription>
              </DialogHeader>
              <div className="grid gap-4 py-4">
                <div className="grid grid-cols-4 items-center gap-4">
                  <Label htmlFor="name" className="text-right">
                    Name
                  </Label>
                  <Input
                    id="name"
                    value={newSessionName}
                    onChange={(e) => setNewSessionName(e.target.value)}
                    className="col-span-3"
                    placeholder="e.g., Support Bot"
                  />
                </div>
              </div>
              <DialogFooter>
                <Button
                  type="submit"
                  onClick={handleCreateSession}
                  disabled={!newSessionName.trim() || isCreating}
                  className="gap-2"
                >
                  {isCreating && <Loader2 className="h-4 w-4 animate-spin" />}
                  Create Session
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      {/* Overview Metrics */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Sessions</CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{totalSessions}</div>
            <p className="text-xs text-muted-foreground">
              {activeSessions} currently active
            </p>
          </CardContent>
        </Card>
        
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active Sessions</CardTitle>
            <Activity className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">{activeSessions}</div>
            <p className="text-xs text-muted-foreground">
              {totalSessions > 0 ? Math.round((activeSessions / totalSessions) * 100) : 0}% online
            </p>
          </CardContent>
        </Card>
        
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Messages</CardTitle>
            <MessageSquare className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{totalMessages.toLocaleString()}</div>
            <p className="text-xs text-muted-foreground">
              All sessions combined
            </p>
          </CardContent>
        </Card>
        
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Uptime</CardTitle>
            <Clock className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{formatTotalUptime(totalUptime)}</div>
            <p className="text-xs text-muted-foreground">
              Combined connection time
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Sessions Grid */}
      {isLoading ? (
        <div className="flex items-center justify-center h-64">
          <Loader2 className="h-8 w-8 animate-spin" />
        </div>
      ) : sessions.length === 0 ? (
        <Card className="p-8 text-center">
          <div className="flex flex-col items-center gap-4">
            <Smartphone className="h-12 w-12 text-muted-foreground" />
            <div>
              <h3 className="text-lg font-semibold">No sessions yet</h3>
              <p className="text-muted-foreground">Create your first WhatsApp session to get started</p>
            </div>
            <Dialog open={isCreateDialogOpen} onOpenChange={setIsCreateDialogOpen}>
              <DialogTrigger asChild>
                <Button className="gap-2">
                  <Plus className="h-4 w-4" />
                  Create First Session
                </Button>
              </DialogTrigger>
            </Dialog>
          </div>
        </Card>
      ) : (
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {sessions.map((session) => (
            <SessionCard
              key={session.id}
              session={session}
              onShowQR={showQrCode}
              onRestart={handleRestartSession}
              onDelete={handleDeleteSession}
            />
          ))}
        </div>
      )}

      {/* QR Code Dialog */}
      <Dialog open={isQrDialogOpen} onOpenChange={setIsQrDialogOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <QrCode className="h-5 w-5" />
              WhatsApp QR Code
            </DialogTitle>
            <DialogDescription>
              Scan this QR code with WhatsApp on your phone to connect the session: {selectedSession?.name}
            </DialogDescription>
          </DialogHeader>
          
          <div className="flex justify-center p-6">
            {qrCode ? (
              <img 
                src={qrCode} 
                alt="WhatsApp QR Code" 
                className="max-w-full h-auto rounded-lg border"
              />
            ) : (
              <div className="flex items-center justify-center w-64 h-64 border-2 border-dashed border-gray-300 rounded-lg">
                <div className="text-center">
                  <Loader2 className="h-8 w-8 animate-spin mx-auto mb-2" />
                  <p className="text-sm text-muted-foreground">Loading QR code...</p>
                </div>
              </div>
            )}
          </div>
          
          <DialogFooter>
            <Button 
              variant="outline" 
              onClick={() => selectedSession && showQrCode(selectedSession)}
            >
              Refresh QR Code
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}