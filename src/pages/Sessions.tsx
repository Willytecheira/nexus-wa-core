import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { Badge } from '@/components/ui/badge';
import { Separator } from '@/components/ui/separator';
import { useToast } from '@/hooks/use-toast';
import { apiClient, Session } from '@/lib/api';
import { 
  Plus, 
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
  Loader2
} from 'lucide-react';

export function Sessions() {
  const [sessions, setSessions] = useState<Session[]>([]);
  const [isCreateDialogOpen, setIsCreateDialogOpen] = useState(false);
  const [isQrDialogOpen, setIsQrDialogOpen] = useState(false);
  const [selectedSession, setSelectedSession] = useState<Session | null>(null);
  const [newSessionName, setNewSessionName] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [isCreating, setIsCreating] = useState(false);
  const { toast } = useToast();

  // Load sessions on component mount
  useEffect(() => {
    loadSessions();
  }, []);

  const loadSessions = async () => {
    try {
      const response = await apiClient.getSessions();
      if (response.success && response.data) {
        setSessions(response.data);
      } else {
        toast({
          title: "Error",
          description: response.error || "Failed to load sessions",
          variant: "destructive",
        });
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to connect to server",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  // Helper functions for status display
  const getStatusColor = (status: Session['status']) => {
    switch (status) {
      case 'connected':
        return 'bg-status-success text-white';
      case 'connecting':
      case 'qr':
        return 'bg-status-warning text-white';
      case 'disconnected':
        return 'bg-destructive text-white';
      case 'error':
        return 'bg-destructive text-white';
      default:
        return 'bg-muted text-muted-foreground';
    }
  };

  const getStatusIcon = (status: Session['status']) => {
    switch (status) {
      case 'connected':
        return <Wifi className="h-4 w-4" />;
      case 'connecting':
      case 'qr':
        return <Loader2 className="h-4 w-4 animate-spin" />;
      case 'disconnected':
        return <WifiOff className="h-4 w-4" />;
      case 'error':
        return <AlertCircle className="h-4 w-4" />;
      default:
        return <WifiOff className="h-4 w-4" />;
    }
  };

  const handleCreateSession = async () => {
    if (!newSessionName.trim()) return;
    
    setIsCreating(true);
    try {
      const response = await apiClient.createSession(newSessionName);
      if (response.success && response.data) {
        setSessions([...sessions, response.data]);
        setNewSessionName('');
        setIsCreateDialogOpen(false);
        toast({
          title: "Session Created",
          description: `Session "${newSessionName}" has been created successfully.`,
        });
      } else {
        toast({
          title: "Error",
          description: response.error || "Failed to create session",
          variant: "destructive",
        });
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to create session",
        variant: "destructive",
      });
    } finally {
      setIsCreating(false);
    }
  };

  const handleDeleteSession = async (sessionId: string) => {
    const sessionToDelete = sessions.find(s => s.id === sessionId);
    try {
      const response = await apiClient.deleteSession(sessionId);
      if (response.success) {
        setSessions(sessions.filter(session => session.id !== sessionId));
        toast({
          title: "Session Deleted",
          description: `Session "${sessionToDelete?.name}" has been deleted.`,
          variant: "destructive",
        });
      } else {
        toast({
          title: "Error",
          description: response.error || "Failed to delete session",
          variant: "destructive",
        });
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to delete session",
        variant: "destructive",
      });
    }
  };

  const handleRestartSession = async (sessionId: string) => {
    const sessionToRestart = sessions.find(s => s.id === sessionId);
    try {
      const response = await apiClient.restartSession(sessionId);
      if (response.success) {
        // Update session status to connecting
        setSessions(sessions.map(session => 
          session.id === sessionId 
            ? { ...session, status: 'connecting' as const }
            : session
        ));
        toast({
          title: "Session Restarting",
          description: `Session "${sessionToRestart?.name}" is restarting...`,
        });
        // Refresh sessions after a short delay
        setTimeout(loadSessions, 2000);
      } else {
        toast({
          title: "Error",
          description: response.error || "Failed to restart session",
          variant: "destructive",
        });
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to restart session",
        variant: "destructive",
      });
    }
  };

  const showQrCode = async (session: Session) => {
    try {
      const response = await apiClient.getQRCode(session.id);
      if (response.success && response.data?.qr) {
        setSelectedSession({ ...session, qrCode: response.data.qr });
        setIsQrDialogOpen(true);
      } else {
        toast({
          title: "Error",
          description: response.error || "QR Code not available",
          variant: "destructive",
        });
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to load QR code",
        variant: "destructive",
      });
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">WhatsApp Sessions</h1>
          <p className="text-muted-foreground">
            Manage your WhatsApp Web sessions and their connections.
          </p>
        </div>
        
        <Dialog open={isCreateDialogOpen} onOpenChange={setIsCreateDialogOpen}>
          <DialogTrigger asChild>
            <Button className="bg-gradient-primary hover:bg-gradient-primary/90 shadow-whatsapp">
              <Plus className="mr-2 h-4 w-4" />
              New Session
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Create New Session</DialogTitle>
              <DialogDescription>
                Create a new WhatsApp session. You'll need to scan the QR code with your phone.
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-4">
              <div>
                <Label htmlFor="sessionName">Session Name</Label>
                <Input
                  id="sessionName"
                  placeholder="e.g., Business Account, Support Team"
                  value={newSessionName}
                  onChange={(e) => setNewSessionName(e.target.value)}
                />
              </div>
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setIsCreateDialogOpen(false)}>
                Cancel
              </Button>
              <Button onClick={handleCreateSession} disabled={!newSessionName.trim() || isCreating}>
                {isCreating ? (
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                ) : (
                  <Plus className="h-4 w-4 mr-2" />
                )}
                {isCreating ? 'Creating...' : 'Create Session'}
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>

      {/* Sessions Grid */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {/* Sessions Grid */}
        {isLoading ? (
          <Card className="col-span-full">
            <CardContent className="flex flex-col items-center justify-center py-12">
              <Loader2 className="h-8 w-8 animate-spin mb-4" />
              <p className="text-muted-foreground">Loading sessions...</p>
            </CardContent>
          </Card>
        ) : sessions.length === 0 ? (
          <Card className="col-span-full">
            <CardContent className="flex flex-col items-center justify-center py-12">
              <Smartphone className="h-12 w-12 text-muted-foreground mb-4" />
              <h3 className="text-lg font-semibold mb-2">No Sessions Yet</h3>
              <p className="text-muted-foreground text-center mb-4">
                Create your first WhatsApp session to start managing conversations.
              </p>
              <Dialog open={isCreateDialogOpen} onOpenChange={setIsCreateDialogOpen}>
                <DialogTrigger asChild>
                  <Button>
                    <Plus className="h-4 w-4 mr-2" />
                    Create First Session
                  </Button>
                </DialogTrigger>
              </Dialog>
            </CardContent>
          </Card>
        ) : (
          sessions.map((session) => (
            <Card key={session.id} className="hover:shadow-card transition-shadow">
              <CardHeader className="pb-3">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <Smartphone className="h-5 w-5 text-whatsapp-primary" />
                    <CardTitle className="text-lg">{session.name}</CardTitle>
                  </div>
                  
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button variant="ghost" size="sm" className="h-8 w-8 p-0">
                        <MoreVertical className="h-4 w-4" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuItem 
                        onClick={() => showQrCode(session)}
                        disabled={session.status === 'connected'}
                      >
                        <QrCode className="h-4 w-4 mr-2" />
                        Show QR Code
                      </DropdownMenuItem>
                      <DropdownMenuItem onClick={() => handleRestartSession(session.id)}>
                        <RotateCcw className="h-4 w-4 mr-2" />
                        Restart Session
                      </DropdownMenuItem>
                      <DropdownMenuItem 
                        onClick={() => handleDeleteSession(session.id)}
                        className="text-destructive"
                      >
                        <Trash2 className="h-4 w-4 mr-2" />
                        Delete Session
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </div>
                
                <div className="flex items-center gap-2">
                  <Badge className={getStatusColor(session.status)}>
                    {getStatusIcon(session.status)}
                    <span className="ml-1 capitalize">{session.status.replace('_', ' ')}</span>
                  </Badge>
                </div>
              </CardHeader>
              
              <CardContent className="space-y-4">
                {session.phone && (
                  <div>
                    <p className="text-sm font-medium">Phone Number</p>
                    <p className="text-sm text-muted-foreground">{session.phone}</p>
                  </div>
                )}
                
                <div className="flex justify-between items-center">
                  <div>
                    <p className="text-sm font-medium">Messages</p>
                    <p className="text-sm text-muted-foreground">{session.messagesCount || 0}</p>
                  </div>
                  {session.lastSeen && (
                    <div className="text-right">
                      <p className="text-sm font-medium">Last Seen</p>
                      <p className="text-sm text-muted-foreground">{session.lastSeen}</p>
                    </div>
                  )}
                </div>
                
                {(session.status === 'qr' || session.status === 'connecting') && (
                  <Button 
                    onClick={() => showQrCode(session)}
                    variant="outline" 
                    className="w-full"
                  >
                    <QrCode className="mr-2 h-4 w-4" />
                    Show QR Code
                  </Button>
                )}
              </CardContent>
            </Card>
          ))
        )}
      </div>

      {/* QR Code Dialog */}
      <Dialog open={isQrDialogOpen} onOpenChange={setIsQrDialogOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>WhatsApp QR Code</DialogTitle>
            <DialogDescription>
              Scan this QR code with your WhatsApp mobile app to connect the session "{selectedSession?.name}".
            </DialogDescription>
          </DialogHeader>
          
          <div className="flex items-center justify-center p-6 bg-muted rounded-lg">
            {selectedSession?.qrCode ? (
              <div className="text-center">
                <img 
                  src={`data:image/png;base64,${selectedSession.qrCode}`} 
                  alt="WhatsApp QR Code" 
                  className="max-w-full h-auto mx-auto mb-2"
                />
                <p className="text-xs text-muted-foreground">
                  Scan with WhatsApp mobile app
                </p>
              </div>
            ) : (
              <div className="text-center">
                <QrCode className="h-16 w-16 text-muted-foreground mx-auto mb-2" />
                <p className="text-sm text-muted-foreground">QR Code not available</p>
                <p className="text-xs text-muted-foreground mt-1">
                  The session might already be connected or there was an error generating the code.
                </p>
              </div>
            )}
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}

export default Sessions;