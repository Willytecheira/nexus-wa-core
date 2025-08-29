import React, { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Textarea } from '@/components/ui/textarea';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Badge } from '@/components/ui/badge';
import { Separator } from '@/components/ui/separator';
import { toast } from 'sonner';
import { apiClient, type Session } from '@/lib/api';
import { 
  Send, 
  MessageSquare, 
  Search, 
  Filter, 
  CheckCircle, 
  XCircle, 
  Clock, 
  MessageCircle, 
  Image, 
  FileText, 
  Phone,
  Calendar,
  Loader2
} from 'lucide-react';
import { format } from 'date-fns';

const messageSchema = z.object({
  sessionId: z.string().min(1, 'Please select a session'),
  phone: z.string().min(10, 'Enter a valid phone number'),
  message: z.string().min(1, 'Message cannot be empty'),
  type: z.enum(['text', 'image', 'document'])
});

type MessageForm = z.infer<typeof messageSchema>;

interface Message {
  id: string;
  sessionId: string;
  sender: string;
  recipient: string;
  content: string;
  type: 'text' | 'image' | 'document';
  status: 'sent' | 'delivered' | 'read' | 'failed';
  timestamp: string;
}

export default function Messages() {
  const [sessions, setSessions] = useState<Session[]>([]);
  const [messages, setMessages] = useState<Message[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [loading, setLoading] = useState(true);
  const [sendingMessage, setSendingMessage] = useState(false);

  const form = useForm<MessageForm>({
    resolver: zodResolver(messageSchema),
    defaultValues: {
      sessionId: '',
      phone: '',
      message: '',
      type: 'text',
    },
  });

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    setLoading(true);
    try {
      const [sessionsResponse, messagesResponse] = await Promise.all([
        apiClient.getSessions(),
        apiClient.getMessages()
      ]);

      if (sessionsResponse.success && sessionsResponse.data) {
        setSessions(sessionsResponse.data);
      }

      if (messagesResponse.success && messagesResponse.data) {
        // Ensure we have an array
        const messagesArray = Array.isArray(messagesResponse.data) ? messagesResponse.data : [];
        setMessages(messagesArray);
      }
    } catch (error) {
      toast.error('Failed to load data');
    } finally {
      setLoading(false);
    }
  };

  const onSubmit = async (data: MessageForm) => {
    setSendingMessage(true);
    
    // Debug logging
    console.log('=== SENDING MESSAGE DEBUG ===');
    console.log('Form data:', data);
    console.log('API Client token:', apiClient.getToken());
    console.log('Selected session:', sessions.find(s => s.id === data.sessionId));
    
    try {
      const payload = {
        sessionId: data.sessionId,
        phone: data.phone,
        message: data.message,
        type: data.type,
      };
      
      console.log('Sending payload:', payload);
      
      const response = await apiClient.sendMessage(payload);
      
      console.log('API Response:', response);
      console.log('Response success:', response.success);
      console.log('Response error:', response.error);

      if (response.success) {
        toast.success('Message sent successfully!');
        form.reset();
        // Refresh messages to show the new one
        loadData();
      } else {
        console.error('Send message failed:', response.error);
        toast.error(response.error || 'Failed to send message');
      }
    } catch (error) {
      console.error('Send message exception:', error);
      console.error('Error details:', {
        message: error.message,
        stack: error.stack,
        name: error.name
      });
      toast.error(`Failed to send message: ${error.message || 'Unknown error'}`);
    } finally {
      setSendingMessage(false);
      console.log('=== SEND MESSAGE DEBUG END ===');
    }
  };

  const getStatusColor = (status: Message['status']) => {
    switch (status) {
      case 'sent': return 'bg-blue-500 text-white';
      case 'delivered': return 'bg-green-500 text-white';
      case 'read': return 'bg-green-600 text-white';
      case 'failed': return 'bg-red-500 text-white';
    }
  };

  const getStatusIcon = (status: Message['status']) => {
    switch (status) {
      case 'sent': return <Clock className="h-3 w-3" />;
      case 'delivered': return <CheckCircle className="h-3 w-3" />;
      case 'read': return <CheckCircle className="h-3 w-3" />;
      case 'failed': return <XCircle className="h-3 w-3" />;
    }
  };

  const getTypeIcon = (type: Message['type']) => {
    switch (type) {
      case 'text': return <MessageSquare className="h-4 w-4" />;
      case 'image': return <Image className="h-4 w-4" />;
      case 'document': return <FileText className="h-4 w-4" />;
    }
  };

  const filteredMessages = messages.filter(message => {
    const matchesSearch = 
      message.recipient.toLowerCase().includes(searchTerm.toLowerCase()) ||
      message.content.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesStatus = statusFilter === 'all' || message.status === statusFilter;
    
    return matchesSearch && matchesStatus;
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Messages</h1>
        <p className="text-muted-foreground">
          Send messages and view your message history across all sessions.
        </p>
      </div>

      <Tabs defaultValue="send" className="space-y-6">
        <TabsList className="grid w-full max-w-md grid-cols-2">
          <TabsTrigger value="send">Send Message</TabsTrigger>
          <TabsTrigger value="history">Message History</TabsTrigger>
        </TabsList>

        {/* Send Message Tab */}
        <TabsContent value="send">
          <Card>
            <CardHeader>
              <CardTitle>Send New Message</CardTitle>
              <CardDescription>
                Choose a session and send a message to any WhatsApp number.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <Form {...form}>
                <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
                  <div className="grid gap-4 md:grid-cols-2">
                    <FormField
                      control={form.control}
                      name="sessionId"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel>Session</FormLabel>
                          <Select onValueChange={field.onChange} defaultValue={field.value}>
                            <FormControl>
                              <SelectTrigger>
                                <SelectValue placeholder="Select a session" />
                              </SelectTrigger>
                            </FormControl>
                            <SelectContent>
            {sessions.map((session) => (
              <SelectItem key={session.id} value={session.id}>
                {session.name} {session.phone_number && `(${session.phone_number})`}
              </SelectItem>
            ))}
                            </SelectContent>
                          </Select>
                          <FormMessage />
                        </FormItem>
                      )}
                    />

                    <FormField
                      control={form.control}
                      name="phone"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel>Phone Number</FormLabel>
                          <FormControl>
                            <Input
                              placeholder="+1234567890"
                              {...field}
                            />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                  </div>

                  <FormField
                    control={form.control}
                    name="type"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Message Type</FormLabel>
                        <Select onValueChange={field.onChange} defaultValue={field.value}>
                          <FormControl>
                            <SelectTrigger>
                              <SelectValue placeholder="Select message type" />
                            </SelectTrigger>
                          </FormControl>
                          <SelectContent>
                            <SelectItem value="text">
                              <div className="flex items-center gap-2">
                                <MessageSquare className="h-4 w-4" />
                                Text Message
                              </div>
                            </SelectItem>
                            <SelectItem value="image">
                              <div className="flex items-center gap-2">
                                <Image className="h-4 w-4" />
                                Image
                              </div>
                            </SelectItem>
                            <SelectItem value="document">
                              <div className="flex items-center gap-2">
                                <FileText className="h-4 w-4" />
                                Document
                              </div>
                            </SelectItem>
                          </SelectContent>
                        </Select>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  <FormField
                    control={form.control}
                    name="message"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Message</FormLabel>
                        <FormControl>
                          <Textarea
                            placeholder="Type your message here..."
                            rows={4}
                            {...field}
                          />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  <Button type="submit" className="w-full" disabled={sendingMessage}>
                    {sendingMessage ? (
                      <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                    ) : (
                      <Send className="w-4 h-4 mr-2" />
                    )}
                    {sendingMessage ? 'Sending...' : 'Send Message'}
                  </Button>
                </form>
              </Form>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Message History Tab */}
        <TabsContent value="history">
          <Card>
            <CardHeader>
              <CardTitle>Message History</CardTitle>
              <CardDescription>
                View all sent messages and their delivery status.
              </CardDescription>
            </CardHeader>
            <CardContent>
              {/* Filters */}
              <div className="flex flex-col sm:flex-row gap-4 mb-6">
                <div className="flex-1">
                  <div className="relative">
                    <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                    <Input
                      placeholder="Search messages, phone numbers..."
                      value={searchTerm}
                      onChange={(e) => setSearchTerm(e.target.value)}
                      className="pl-9"
                    />
                  </div>
                </div>
                <Select value={statusFilter} onValueChange={setStatusFilter}>
                  <SelectTrigger className="w-full sm:w-48">
                    <Filter className="mr-2 h-4 w-4" />
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Status</SelectItem>
                    <SelectItem value="sent">Sent</SelectItem>
                    <SelectItem value="delivered">Delivered</SelectItem>
                    <SelectItem value="read">Read</SelectItem>
                    <SelectItem value="failed">Failed</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              {/* Messages List */}
              {loading ? (
                <div className="text-center py-8">
                  <Loader2 className="w-8 h-8 animate-spin mx-auto mb-2" />
                  <p className="text-muted-foreground">Loading messages...</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {filteredMessages.length === 0 ? (
                    <div className="text-center py-8 text-muted-foreground">
                      <MessageSquare className="w-8 h-8 mx-auto mb-2" />
                      <p>No messages found</p>
                    </div>
                  ) : (
                    filteredMessages.map((message) => (
                      <div key={message.id} className="border rounded-lg p-4 hover:bg-muted/50 transition-colors">
                        <div className="flex items-start justify-between gap-4">
                          <div className="flex-1">
                            <div className="flex items-center gap-2 mb-2">
                              {getTypeIcon(message.type)}
                              <span className="font-medium">
                                {sessions.find(s => s.id === message.sessionId)?.name || 'Unknown Session'}
                              </span>
                              <span className="text-muted-foreground">→</span>
                              <span className="text-muted-foreground">{message.recipient}</span>
                              <Badge className={`ml-auto ${getStatusColor(message.status)}`}>
                                {getStatusIcon(message.status)}
                                <span className="ml-1 capitalize">{message.status}</span>
                              </Badge>
                            </div>
                            <p className="text-sm mb-2">{message.content}</p>
                            <div className="flex items-center gap-2 text-xs text-muted-foreground">
                              <Calendar className="h-3 w-3" />
                              {format(new Date(message.timestamp), 'PPpp')}
                            </div>
                          </div>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}