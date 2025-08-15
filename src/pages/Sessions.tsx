import { useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { 
  Plus, 
  Smartphone, 
  QrCode, 
  Power, 
  Trash2, 
  RefreshCw, 
  CheckCircle, 
  XCircle, 
  Clock,
  Eye,
  MoreVertical
} from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import { 
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';

interface Session {
  id: string;
  name: string;
  phone: string;
  status: 'connected' | 'disconnected' | 'initializing' | 'qr_received';
  lastSeen: string;
  messagesCount: number;
  qrCode?: string;
}

// Mock sessions data
const initialSessions: Session[] = [
  {
    id: '1',
    name: 'Business Main',
    phone: '+1 (555) 123-4567',
    status: 'connected',
    lastSeen: '2 minutes ago',
    messagesCount: 247
  },
  {
    id: '2', 
    name: 'Support Team',
    phone: '+1 (555) 987-6543',
    status: 'connected',
    lastSeen: '5 minutes ago',
    messagesCount: 89
  },
  {
    id: '3',
    name: 'Marketing Bot',
    phone: '+1 (555) 456-7890',
    status: 'qr_received',
    lastSeen: '1 hour ago',
    messagesCount: 0,
    qrCode: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='
  }
];

export default function Sessions() {
  const [sessions, setSessions] = useState<Session[]>(initialSessions);
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [isQrOpen, setIsQrOpen] = useState(false);
  const [selectedSession, setSelectedSession] = useState<Session | null>(null);
  const [newSessionName, setNewSessionName] = useState('');
  const { toast } = useToast();

  const getStatusColor = (status: Session['status']) => {
    switch (status) {
      case 'connected': return 'bg-status-success text-white';
      case 'disconnected': return 'bg-destructive text-white';
      case 'initializing': return 'bg-status-warning text-white';
      case 'qr_received': return 'bg-status-info text-white';
    }
  };

  const getStatusIcon = (status: Session['status']) => {
    switch (status) {
      case 'connected': return <CheckCircle className="h-4 w-4" />;
      case 'disconnected': return <XCircle className="h-4 w-4" />;
      case 'initializing': return <Clock className="h-4 w-4" />;
      case 'qr_received': return <QrCode className="h-4 w-4" />;
    }
  };

  const handleCreateSession = () => {
    if (!newSessionName.trim()) return;

    const newSession: Session = {
      id: Date.now().toString(),
      name: newSessionName,
      phone: '',
      status: 'initializing',
      lastSeen: 'Just created',
      messagesCount: 0,
      qrCode: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='
    };

    setSessions([...sessions, newSession]);
    setNewSessionName('');
    setIsCreateOpen(false);
    
    toast({
      title: "Session Created",
      description: `${newSessionName} session has been created successfully.`
    });

    // Simulate QR code generation
    setTimeout(() => {
      setSessions(prev => prev.map(s => 
        s.id === newSession.id 
          ? { ...s, status: 'qr_received' as const }
          : s
      ));
    }, 2000);
  };

  const handleDeleteSession = (sessionId: string) => {
    const session = sessions.find(s => s.id === sessionId);
    setSessions(sessions.filter(s => s.id !== sessionId));
    
    toast({
      title: "Session Deleted",
      description: `${session?.name} session has been deleted.`,
      variant: "destructive"
    });
  };

  const handleRestartSession = (sessionId: string) => {
    const session = sessions.find(s => s.id === sessionId);
    setSessions(sessions.map(s => 
      s.id === sessionId 
        ? { ...s, status: 'initializing' as const, lastSeen: 'Restarting...' }
        : s
    ));
    
    toast({
      title: "Session Restarted",
      description: `${session?.name} session is restarting.`
    });

    // Simulate restart process
    setTimeout(() => {
      setSessions(prev => prev.map(s => 
        s.id === sessionId 
          ? { ...s, status: 'qr_received' as const, lastSeen: 'Just now' }
          : s
      ));
    }, 3000);
  };

  const showQrCode = (session: Session) => {
    setSelectedSession(session);
    setIsQrOpen(true);
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
        
        <Dialog open={isCreateOpen} onOpenChange={setIsCreateOpen}>
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
              <div className="flex justify-end gap-2">
                <Button variant="outline" onClick={() => setIsCreateOpen(false)}>
                  Cancel
                </Button>
                <Button 
                  onClick={handleCreateSession}
                  disabled={!newSessionName.trim()}
                  className="bg-gradient-primary hover:bg-gradient-primary/90"
                >
                  Create Session
                </Button>
              </div>
            </div>
          </DialogContent>
        </Dialog>
      </div>

      {/* Sessions Grid */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {sessions.map((session) => (
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
                    {session.status === 'qr_received' && (
                      <DropdownMenuItem onClick={() => showQrCode(session)}>
                        <QrCode className="mr-2 h-4 w-4" />
                        Show QR Code
                      </DropdownMenuItem>
                    )}
                    <DropdownMenuItem onClick={() => handleRestartSession(session.id)}>
                      <RefreshCw className="mr-2 h-4 w-4" />
                      Restart
                    </DropdownMenuItem>
                    <DropdownMenuItem 
                      onClick={() => handleDeleteSession(session.id)}
                      className="text-destructive"
                    >
                      <Trash2 className="mr-2 h-4 w-4" />
                      Delete
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
                  <p className="text-sm font-medium">Messages Sent</p>
                  <p className="text-sm text-muted-foreground">{session.messagesCount.toLocaleString()}</p>
                </div>
                <div className="text-right">
                  <p className="text-sm font-medium">Last Seen</p>
                  <p className="text-sm text-muted-foreground">{session.lastSeen}</p>
                </div>
              </div>
              
              {session.status === 'qr_received' && (
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
        ))}
      </div>

      {/* QR Code Modal */}
      <Dialog open={isQrOpen} onOpenChange={setIsQrOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Scan QR Code</DialogTitle>
            <DialogDescription>
              Open WhatsApp on your phone and scan this QR code to connect {selectedSession?.name}.
            </DialogDescription>
          </DialogHeader>
          
          <div className="flex flex-col items-center space-y-4">
            <div className="w-64 h-64 bg-white p-4 rounded-lg border-2 border-dashed border-muted flex items-center justify-center">
              {selectedSession?.qrCode ? (
                <div className="w-full h-full bg-gray-100 rounded flex items-center justify-center">
                  <QrCode className="h-16 w-16 text-muted-foreground" />
                </div>
              ) : (
                <div className="text-center">
                  <RefreshCw className="h-8 w-8 animate-spin mx-auto mb-2" />
                  <p className="text-sm text-muted-foreground">Generating QR code...</p>
                </div>
              )}
            </div>
            
            <div className="text-center">
              <p className="text-sm font-medium mb-1">Steps to connect:</p>
              <ol className="text-xs text-muted-foreground space-y-1">
                <li>1. Open WhatsApp on your phone</li>
                <li>2. Tap the three dots menu</li>
                <li>3. Select "Linked devices"</li>
                <li>4. Tap "Link a device"</li>
                <li>5. Scan this QR code</li>
              </ol>
            </div>
            
            <Button 
              onClick={() => setIsQrOpen(false)} 
              className="w-full"
            >
              Close
            </Button>
          </div>
        </DialogContent>
      </Dialog>

      {/* Empty State */}
      {sessions.length === 0 && (
        <Card className="text-center py-12">
          <CardContent>
            <Smartphone className="h-16 w-16 mx-auto mb-4 text-muted-foreground" />
            <h3 className="text-lg font-semibold mb-2">No sessions yet</h3>
            <p className="text-muted-foreground mb-4">
              Create your first WhatsApp session to get started.
            </p>
            <Button 
              onClick={() => setIsCreateOpen(true)}
              className="bg-gradient-primary hover:bg-gradient-primary/90"
            >
              <Plus className="mr-2 h-4 w-4" />
              Create First Session
            </Button>
          </CardContent>
        </Card>
      )}
    </div>
  );
}