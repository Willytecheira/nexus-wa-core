import { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Switch } from '@/components/ui/switch';
import { AlertCircle, CheckCircle, Clock, Globe, Settings as SettingsIcon, Webhook, Zap } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import { apiClient } from '@/lib/api';

interface WebhookEvent {
  id: number;
  event_type: string;
  webhook_url: string;
  response_status: number;
  retry_count: number;
  created_at: string;
}

interface Session {
  id: string;
  name: string;
  status: string;
  webhook_url?: string;
}

export default function Settings() {
  const [sessions, setSessions] = useState<Session[]>([]);
  const [webhookEvents, setWebhookEvents] = useState<WebhookEvent[]>([]);
  const [selectedSession, setSelectedSession] = useState<string>('');
  const [webhookUrl, setWebhookUrl] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [testingWebhook, setTestingWebhook] = useState<string | null>(null);
  const { toast } = useToast();

  // Load sessions on mount
  useEffect(() => {
    loadSessions();
  }, []);

  // Load webhook events when session is selected
  useEffect(() => {
    if (selectedSession) {
      loadWebhookEvents(selectedSession);
      loadSessionWebhook(selectedSession);
    }
  }, [selectedSession]);

  const loadSessions = async () => {
    try {
      const response = await apiClient.getSessions();
      if (response.success) {
        setSessions(response.data || []);
        if (response.data?.length > 0 && !selectedSession) {
          setSelectedSession(response.data[0].id);
        }
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to load sessions",
        variant: "destructive",
      });
    }
  };

  const loadSessionWebhook = async (sessionId: string) => {
    try {
      const response = await apiClient.getSessionWebhook(sessionId);
      if (response.success && response.data) {
        setWebhookUrl(response.data.webhook_url || '');
      }
    } catch (error) {
      console.error('Error loading webhook:', error);
    }
  };

  const loadWebhookEvents = async (sessionId: string) => {
    try {
      const response = await apiClient.getWebhookEvents(sessionId);
      if (response.success) {
        setWebhookEvents(response.data || []);
      }
    } catch (error) {
      console.error('Error loading webhook events:', error);
    }
  };

  const handleSaveWebhook = async () => {
    if (!selectedSession) {
      toast({
        title: "Error",
        description: "Please select a session",
        variant: "destructive",
      });
      return;
    }

    setIsLoading(true);
    try {
      const response = await apiClient.configureWebhook(selectedSession, webhookUrl);
      if (response.success) {
        toast({
          title: "Success",
          description: "Webhook configured successfully",
        });
        loadSessions(); // Refresh sessions to show updated webhook status
      } else {
        throw new Error(response.message);
      }
    } catch (error: any) {
      toast({
        title: "Error",
        description: error.message || "Failed to configure webhook",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleRemoveWebhook = async () => {
    if (!selectedSession) return;

    setIsLoading(true);
    try {
      const response = await apiClient.removeWebhook(selectedSession);
      if (response.success) {
        setWebhookUrl('');
        toast({
          title: "Success",
          description: "Webhook removed successfully",
        });
        loadSessions();
      } else {
        throw new Error(response.message);
      }
    } catch (error: any) {
      toast({
        title: "Error",
        description: error.message || "Failed to remove webhook",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleTestWebhook = async (sessionId: string) => {
    setTestingWebhook(sessionId);
    try {
      const response = await apiClient.testWebhook(sessionId);
      if (response.success) {
        toast({
          title: "Success",
          description: "Test webhook sent successfully",
        });
        // Refresh events to show the test
        loadWebhookEvents(sessionId);
      } else {
        throw new Error(response.message);
      }
    } catch (error: any) {
      toast({
        title: "Error",
        description: error.message || "Failed to send test webhook",
        variant: "destructive",
      });
    } finally {
      setTestingWebhook(null);
    }
  };

  const getStatusBadge = (status: number, retryCount: number) => {
    if (status >= 200 && status < 300) {
      return <Badge variant="default" className="bg-green-500"><CheckCircle className="w-3 h-3 mr-1" />Success</Badge>;
    } else if (retryCount > 0) {
      return <Badge variant="secondary"><Clock className="w-3 h-3 mr-1" />Retried</Badge>;
    } else {
      return <Badge variant="destructive"><AlertCircle className="w-3 h-3 mr-1" />Failed</Badge>;
    }
  };

  const formatEventType = (eventType: string) => {
    return eventType.replace(/\./g, ' ').replace(/\b\w/g, l => l.toUpperCase());
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Settings</h1>
        <p className="text-muted-foreground">Manage webhooks and system configuration</p>
      </div>

      <Tabs defaultValue="webhooks" className="space-y-4">
        <TabsList>
          <TabsTrigger value="webhooks" className="flex items-center gap-2">
            <Webhook className="w-4 h-4" />
            Webhooks
          </TabsTrigger>
          <TabsTrigger value="system" className="flex items-center gap-2">
            <SettingsIcon className="w-4 h-4" />
            System
          </TabsTrigger>
        </TabsList>

        <TabsContent value="webhooks" className="space-y-4">
          <div className="grid gap-4 md:grid-cols-2">
            {/* Webhook Configuration */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Globe className="w-5 h-5" />
                  Webhook Configuration
                </CardTitle>
                <CardDescription>
                  Configure webhook endpoints for session events
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="session-select">Session</Label>
                  <Select value={selectedSession} onValueChange={setSelectedSession}>
                    <SelectTrigger>
                      <SelectValue placeholder="Select a session" />
                    </SelectTrigger>
                    <SelectContent>
                      {sessions.map((session) => (
                        <SelectItem key={session.id} value={session.id}>
                          <div className="flex items-center gap-2">
                            <span>{session.name}</span>
                            {session.webhook_url && (
                              <Badge variant="outline" className="text-xs">
                                <Webhook className="w-3 h-3 mr-1" />
                                Configured
                              </Badge>
                            )}
                          </div>
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                <div className="space-y-2">
                  <Label htmlFor="webhook-url">Webhook URL</Label>
                  <Input
                    id="webhook-url"
                    placeholder="https://your-server.com/webhook"
                    value={webhookUrl}
                    onChange={(e) => setWebhookUrl(e.target.value)}
                  />
                </div>

                <div className="flex gap-2">
                  <Button 
                    onClick={handleSaveWebhook}
                    disabled={!selectedSession || !webhookUrl || isLoading}
                    className="flex-1"
                  >
                    {isLoading ? 'Saving...' : 'Save Webhook'}
                  </Button>
                  
                  {webhookUrl && (
                    <Button
                      variant="outline"
                      onClick={() => handleTestWebhook(selectedSession)}
                      disabled={testingWebhook === selectedSession}
                    >
                      {testingWebhook === selectedSession ? (
                        <Clock className="w-4 h-4" />
                      ) : (
                        <Zap className="w-4 h-4" />
                      )}
                    </Button>
                  )}
                  
                  {webhookUrl && (
                    <Button
                      variant="destructive"
                      onClick={handleRemoveWebhook}
                      disabled={isLoading}
                    >
                      Remove
                    </Button>
                  )}
                </div>

                <div className="text-sm text-muted-foreground">
                  <p><strong>Events sent:</strong></p>
                  <ul className="list-disc list-inside space-y-1 mt-1">
                    <li>session.ready - When session connects</li>
                    <li>session.disconnected - When session disconnects</li>
                    <li>message.received - When message is received</li>
                    <li>webhook.test - Test event</li>
                  </ul>
                </div>
              </CardContent>
            </Card>

            {/* Session Overview */}
            <Card>
              <CardHeader>
                <CardTitle>Sessions Overview</CardTitle>
                <CardDescription>Webhook status for all sessions</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-3">
                  {sessions.map((session) => (
                    <div key={session.id} className="flex items-center justify-between p-3 border rounded-lg">
                      <div>
                        <p className="font-medium">{session.name}</p>
                        <p className="text-sm text-muted-foreground">
                          Status: <Badge variant={session.status === 'connected' ? 'default' : 'secondary'}>
                            {session.status}
                          </Badge>
                        </p>
                      </div>
                      <div className="flex items-center gap-2">
                        {session.webhook_url ? (
                          <>
                            <Badge variant="outline" className="text-green-600 border-green-200">
                              <Webhook className="w-3 h-3 mr-1" />
                              Active
                            </Badge>
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => handleTestWebhook(session.id)}
                              disabled={testingWebhook === session.id}
                            >
                              {testingWebhook === session.id ? 'Testing...' : 'Test'}
                            </Button>
                          </>
                        ) : (
                          <Badge variant="secondary">
                            No webhook
                          </Badge>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Webhook Events History */}
          {selectedSession && (
            <Card>
              <CardHeader>
                <CardTitle>Webhook Events History</CardTitle>
                <CardDescription>
                  Recent webhook events for {sessions.find(s => s.id === selectedSession)?.name}
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="rounded-md border">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Event</TableHead>
                        <TableHead>Status</TableHead>
                        <TableHead>Retries</TableHead>
                        <TableHead>Time</TableHead>
                        <TableHead>URL</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {webhookEvents.length === 0 ? (
                        <TableRow>
                          <TableCell colSpan={5} className="text-center text-muted-foreground">
                            No webhook events found
                          </TableCell>
                        </TableRow>
                      ) : (
                        webhookEvents.map((event) => (
                          <TableRow key={event.id}>
                            <TableCell>
                              <Badge variant="outline">
                                {formatEventType(event.event_type)}
                              </Badge>
                            </TableCell>
                            <TableCell>
                              {getStatusBadge(event.response_status, event.retry_count)}
                            </TableCell>
                            <TableCell>{event.retry_count}</TableCell>
                            <TableCell>
                              {new Date(event.created_at).toLocaleString()}
                            </TableCell>
                            <TableCell className="truncate max-w-xs">
                              <span className="text-xs text-muted-foreground">
                                {event.webhook_url}
                              </span>
                            </TableCell>
                          </TableRow>
                        ))
                      )}
                    </TableBody>
                  </Table>
                </div>
              </CardContent>
            </Card>
          )}
        </TabsContent>

        <TabsContent value="system" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>System Configuration</CardTitle>
              <CardDescription>General system settings and preferences</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-center justify-between">
                <div className="space-y-0.5">
                  <Label>Auto-refresh sessions</Label>
                  <p className="text-sm text-muted-foreground">
                    Automatically refresh session data every 30 seconds
                  </p>
                </div>
                <Switch defaultChecked />
              </div>

              <div className="flex items-center justify-between">
                <div className="space-y-0.5">
                  <Label>Webhook retries</Label>
                  <p className="text-sm text-muted-foreground">
                    Number of retry attempts for failed webhooks
                  </p>
                </div>
                <Select defaultValue="3">
                  <SelectTrigger className="w-20">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="1">1</SelectItem>
                    <SelectItem value="2">2</SelectItem>
                    <SelectItem value="3">3</SelectItem>
                    <SelectItem value="5">5</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="flex items-center justify-between">
                <div className="space-y-0.5">
                  <Label>Webhook timeout</Label>
                  <p className="text-sm text-muted-foreground">
                    Timeout in seconds for webhook requests
                  </p>
                </div>
                <Select defaultValue="10">
                  <SelectTrigger className="w-20">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="5">5s</SelectItem>
                    <SelectItem value="10">10s</SelectItem>
                    <SelectItem value="15">15s</SelectItem>
                    <SelectItem value="30">30s</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}