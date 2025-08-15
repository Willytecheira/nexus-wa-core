import { useState } from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Checkbox } from '@/components/ui/checkbox';
import { Loader2, MessageCircle } from 'lucide-react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';

const loginSchema = z.object({
  username: z.string().min(1, 'Username is required'),
  password: z.string().min(1, 'Password is required'),
  rememberMe: z.boolean().default(false)
});

type LoginForm = z.infer<typeof loginSchema>;

export default function Login() {
  const { login, isAuthenticated, loading: authLoading } = useAuth();
  const [isLoading, setIsLoading] = useState(false);

  const {
    register,
    handleSubmit,
    formState: { errors },
    setValue,
    watch
  } = useForm<LoginForm>({
    resolver: zodResolver(loginSchema),
    defaultValues: {
      username: '',
      password: '',
      rememberMe: false
    }
  });

  const rememberMe = watch('rememberMe');

  if (authLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-bg">
        <Loader2 className="h-8 w-8 animate-spin" />
      </div>
    );
  }

  if (isAuthenticated) {
    return <Navigate to="/" replace />;
  }

  const onSubmit = async (data: LoginForm) => {
    setIsLoading(true);
    try {
      const success = await login(data.username, data.password, data.rememberMe);
      if (!success) {
        setIsLoading(false);
      }
    } catch (error) {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-bg p-4">
      <Card className="w-full max-w-md shadow-lg-custom">
        <CardHeader className="space-y-4 text-center">
          <div className="mx-auto w-16 h-16 bg-gradient-primary rounded-2xl flex items-center justify-center shadow-whatsapp">
            <MessageCircle className="h-8 w-8 text-white" />
          </div>
          <div>
            <CardTitle className="text-2xl font-bold">WhatsApp API</CardTitle>
            <CardDescription className="text-base">
              Multi-Session Management Portal
            </CardDescription>
          </div>
        </CardHeader>
        
        <CardContent>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="username">Username</Label>
              <Input
                id="username"
                type="text"
                placeholder="Enter your username"
                {...register('username')}
                className={errors.username ? 'border-destructive' : ''}
                disabled={isLoading}
              />
              {errors.username && (
                <p className="text-sm text-destructive">{errors.username.message}</p>
              )}
            </div>

            <div className="space-y-2">
              <Label htmlFor="password">Password</Label>
              <Input
                id="password"
                type="password"
                placeholder="Enter your password"
                {...register('password')}
                className={errors.password ? 'border-destructive' : ''}
                disabled={isLoading}
              />
              {errors.password && (
                <p className="text-sm text-destructive">{errors.password.message}</p>
              )}
            </div>

            <div className="flex items-center space-x-2">
              <Checkbox
                id="rememberMe"
                checked={rememberMe}
                onCheckedChange={(checked) => setValue('rememberMe', !!checked)}
                disabled={isLoading}
              />
              <Label 
                htmlFor="rememberMe" 
                className="text-sm font-normal cursor-pointer"
              >
                Remember me for 24 hours
              </Label>
            </div>

            <Button
              type="submit"
              className="w-full bg-gradient-primary hover:bg-gradient-primary/90 shadow-whatsapp"
              disabled={isLoading}
            >
              {isLoading ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Signing in...
                </>
              ) : (
                'Sign in'
              )}
            </Button>
          </form>

          <div className="mt-6 p-4 bg-muted rounded-lg">
            <p className="text-sm font-medium mb-2">Demo Credentials:</p>
            <div className="space-y-1 text-xs text-muted-foreground">
              <div><strong>Admin:</strong> admin / admin123</div>
              <div><strong>Operator:</strong> operator / operator123</div>
              <div><strong>Viewer:</strong> viewer / viewer123</div>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}