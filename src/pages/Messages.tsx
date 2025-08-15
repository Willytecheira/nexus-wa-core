import { useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { 
  Send, 
  Image, 
  Paperclip, 
  Search,
  Filter,
  CheckCircle,
  Clock,
  XCircle,
  MessageSquare,
  Phone,
  Calendar
} from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';

const messageSchema = z.object({
  sessionId: z.string().min(1, 'Please select a session'),
  phone: z.string().min(10, 'Enter a valid phone number'),
  message: z.string().min(1, 'Message cannot be empty'),
  type: z.enum(['text', 'image', 'document'])
});

type MessageForm = z.infer<typeof messageSchema>;

interface Message {
  id: string;
  sessionName: string;
  phone: string;
  message: string;
  type: 'text' | 'image' | 'document';
  status: 'sent' | 'delivered' | 'read' | 'failed';
  timestamp: string;
}

// Mock sessions for dropdown
const sessions = [
  { id: '1', name: 'Business Main', phone: '+1 (555) 123-4567' },
  { id: '2', name: 'Support Team', phone: '+1 (555) 987-6543' },
  { id: '3', name: 'Marketing Bot', phone: '+1 (555) 456-7890' }
];

// Mock messages
const initialMessages: Message[] = [
  {
    id: '1',
    sessionName: 'Business Main',
    phone: '+1 (555) 555-0123',
    message: 'Hello! Thank you for contacting us. How can we help you today?',
    type: 'text',
    status: 'read',
    timestamp: '2024-01-15 14:30:00'
  },
  {
    id: '2',
    sessionName: 'Support Team',
    phone: '+1 (555) 555-0456',
    message: 'Your order #12345 has been shipped and will arrive tomorrow.',
    type: 'text',
    status: 'delivered',
    timestamp: '2024-01-15 13:45:00'
  },
  {
    id: '3',
    sessionName: 'Marketing Bot',
    phone: '+1 (555) 555-0789',
    message: 'Check out our new product catalog!',
    type: 'image',
    status: 'sent',
    timestamp: '2024-01-15 12:15:00'
  }
];

export default function Messages() {
  const [messages, setMessages] = useState<Message[]>(initialMessages);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const { toast } = useToast();

  const {
    register,
    handleSubmit,
    formState: { errors },
    reset,
    setValue,
    watch
  } = useForm<MessageForm>({
    resolver: zodResolver(messageSchema),
    defaultValues: {
      sessionId: '',
      phone: '',
      message: '',
      type: 'text'
    }
  });

  const selectedSession = watch('sessionId');
  const messageType = watch('type');

  const getStatusColor = (status: Message['status']) => {
    switch (status) {
      case 'sent': return 'bg-status-info text-white';
      case 'delivered': return 'bg-status-success text-white';
      case 'read': return 'bg-whatsapp-primary text-white';
      case 'failed': return 'bg-destructive text-white';
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
      case 'document': return <Paperclip className="h-4 w-4" />;
    }
  };

  const onSubmit = (data: MessageForm) => {
    const sessionName = sessions.find(s => s.id === data.sessionId)?.name || '';
    
    const newMessage: Message = {
      id: Date.now().toString(),
      sessionName,
      phone: data.phone,
      message: data.message,
      type: data.type,
      status: 'sent',
      timestamp: new Date().toISOString().slice(0, 19).replace('T', ' ')
    };

    setMessages([newMessage, ...messages]);
    reset();
    
    toast({
      title: "Message Sent",
      description: `Message sent to ${data.phone} via ${sessionName}`
    });

    // Simulate delivery status updates
    setTimeout(() => {
      setMessages(prev => prev.map(m => 
        m.id === newMessage.id ? { ...m, status: 'delivered' } : m
      ));
    }, 2000);

    setTimeout(() => {
      setMessages(prev => prev.map(m => 
        m.id === newMessage.id ? { ...m, status: 'read' } : m
      ));
    }, 5000);
  };

  const filteredMessages = messages.filter(message => {
    const matchesSearch = 
      message.phone.toLowerCase().includes(searchTerm.toLowerCase()) ||
      message.message.toLowerCase().includes(searchTerm.toLowerCase()) ||
      message.sessionName.toLowerCase().includes(searchTerm.toLowerCase());
    
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
              <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
                <div className="grid gap-4 md:grid-cols-2">
                  <div className="space-y-2">
                    <Label htmlFor="sessionId">Session</Label>
                    <Select onValueChange={(value) => setValue('sessionId', value)}>
                      <SelectTrigger>
                        <SelectValue placeholder="Select a session" />
                      </SelectTrigger>
                      <SelectContent>
                        {sessions.map(session => (
                          <SelectItem key={session.id} value={session.id}>
                            <div className="flex items-center gap-2">
                              <Phone className="h-4 w-4" />
                              {session.name}
                            </div>
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                    {errors.sessionId && (
                      <p className="text-sm text-destructive">{errors.sessionId.message}</p>
                    )}
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="phone">Phone Number</Label>
                    <Input
                      id="phone"
                      placeholder="+1 (555) 123-4567"
                      {...register('phone')}
                      className={errors.phone ? 'border-destructive' : ''}
                    />
                    {errors.phone && (
                      <p className="text-sm text-destructive">{errors.phone.message}</p>
                    )}
                  </div>
                </div>

                <div className="space-y-2">
                  <Label htmlFor="type">Message Type</Label>
                  <Select onValueChange={(value) => setValue('type', value as 'text' | 'image' | 'document')}>
                    <SelectTrigger>
                      <SelectValue placeholder="Select message type" />
                    </SelectTrigger>
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
                          <Paperclip className="h-4 w-4" />
                          Document
                        </div>
                      </SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                <div className="space-y-2">
                  <Label htmlFor="message">Message</Label>
                  <Textarea
                    id="message"
                    placeholder={
                      messageType === 'text' 
                        ? "Type your message here..." 
                        : "Caption or description (optional)"
                    }
                    rows={4}
                    {...register('message')}
                    className={errors.message ? 'border-destructive' : ''}
                  />
                  {errors.message && (
                    <p className="text-sm text-destructive">{errors.message.message}</p>
                  )}
                </div>

                {messageType !== 'text' && (
                  <div className="space-y-2">
                    <Label>File Upload</Label>
                    <div className="border-2 border-dashed border-muted rounded-lg p-6 text-center">
                      <div className="flex flex-col items-center gap-2">
                        {messageType === 'image' ? (
                          <Image className="h-8 w-8 text-muted-foreground" />
                        ) : (
                          <Paperclip className="h-8 w-8 text-muted-foreground" />
                        )}
                        <p className="text-sm text-muted-foreground">
                          Click to upload {messageType === 'image' ? 'image' : 'document'}
                        </p>
                        <Button type="button" variant="outline" size="sm">
                          Choose File
                        </Button>
                      </div>
                    </div>
                  </div>
                )}

                <Button 
                  type="submit" 
                  className="w-full bg-gradient-primary hover:bg-gradient-primary/90 shadow-whatsapp"
                >
                  <Send className="mr-2 h-4 w-4" />
                  Send Message
                </Button>
              </form>
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
                      placeholder="Search messages, phone numbers, or sessions..."
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
              <div className="space-y-4">
                {filteredMessages.map((message) => (
                  <div key={message.id} className="border rounded-lg p-4 hover:bg-muted/50 transition-colors">
                    <div className="flex items-start justify-between gap-4">
                      <div className="flex-1">
                        <div className="flex items-center gap-2 mb-2">
                          {getTypeIcon(message.type)}
                          <span className="font-medium">{message.sessionName}</span>
                          <span className="text-muted-foreground">→</span>
                          <span className="text-muted-foreground">{message.phone}</span>
                          <Badge className={`ml-auto ${getStatusColor(message.status)}`}>
                            {getStatusIcon(message.status)}
                            <span className="ml-1 capitalize">{message.status}</span>
                          </Badge>
                        </div>
                        <p className="text-sm mb-2">{message.message}</p>
                        <div className="flex items-center gap-2 text-xs text-muted-foreground">
                          <Calendar className="h-3 w-3" />
                          {new Date(message.timestamp).toLocaleString()}
                        </div>
                      </div>
                    </div>
                  </div>
                ))}

                {filteredMessages.length === 0 && (
                  <div className="text-center py-8">
                    <MessageSquare className="h-12 w-12 mx-auto mb-4 text-muted-foreground" />
                    <h3 className="text-lg font-semibold mb-2">No messages found</h3>
                    <p className="text-muted-foreground">
                      {searchTerm || statusFilter !== 'all' 
                        ? 'Try adjusting your search or filters.' 
                        : 'Send your first message to get started.'}
                    </p>
                  </div>
                )}
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}