// Basic API testing for pre-deployment validation
const http = require('http');
const https = require('https');

class ApiTester {
  constructor(baseUrl = 'http://localhost:3000') {
    this.baseUrl = baseUrl;
    this.testResults = [];
  }

  // Make HTTP request
  async makeRequest(path, options = {}) {
    return new Promise((resolve, reject) => {
      const url = `${this.baseUrl}${path}`;
      const client = url.startsWith('https') ? https : http;
      
      const req = client.request(url, {
        method: options.method || 'GET',
        headers: {
          'Content-Type': 'application/json',
          ...options.headers
        },
        timeout: 10000
      }, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          try {
            const parsed = data ? JSON.parse(data) : {};
            resolve({
              status: res.statusCode,
              headers: res.headers,
              data: parsed
            });
          } catch (err) {
            resolve({
              status: res.statusCode,
              headers: res.headers,
              data: data
            });
          }
        });
      });

      req.on('error', reject);
      req.on('timeout', () => reject(new Error('Request timeout')));

      if (options.body) {
        req.write(JSON.stringify(options.body));
      }

      req.end();
    });
  }

  // Log test result
  logTest(name, success, message = '') {
    const status = success ? '✅' : '❌';
    console.log(`${status} ${name}${message ? ': ' + message : ''}`);
    this.testResults.push({ name, success, message });
  }

  // Test health endpoint
  async testHealth() {
    console.log('\n🔍 Testing Health Endpoint...');
    try {
      const response = await this.makeRequest('/health');
      
      if (response.status === 200) {
        this.logTest('Health Check', true, 'Server is responding');
        return true;
      } else {
        this.logTest('Health Check', false, `Status: ${response.status}`);
        return false;
      }
    } catch (error) {
      this.logTest('Health Check', false, error.message);
      return false;
    }
  }

  // Test API endpoints
  async testApiEndpoints() {
    console.log('\n🔍 Testing API Endpoints...');
    
    const endpoints = [
      { path: '/api', expected: [200, 404] }, // API root might not exist
      { path: '/api/auth/login', method: 'POST', expected: [400, 401, 422] }, // Should reject empty login
      { path: '/api/sessions', expected: [401] }, // Should require auth
      { path: '/api/users', expected: [401] }, // Should require auth
    ];

    for (const endpoint of endpoints) {
      try {
        const response = await this.makeRequest(endpoint.path, {
          method: endpoint.method || 'GET',
          body: endpoint.method === 'POST' ? {} : undefined
        });

        const expectedStatuses = endpoint.expected || [200];
        if (expectedStatuses.includes(response.status)) {
          this.logTest(`${endpoint.method || 'GET'} ${endpoint.path}`, true, `Status: ${response.status}`);
        } else {
          this.logTest(`${endpoint.method || 'GET'} ${endpoint.path}`, false, 
            `Expected ${expectedStatuses.join('|')}, got ${response.status}`);
        }
      } catch (error) {
        this.logTest(`${endpoint.method || 'GET'} ${endpoint.path}`, false, error.message);
      }
    }
  }

  // Test authentication flow
  async testAuthentication() {
    console.log('\n🔍 Testing Authentication...');
    
    try {
      // Test invalid login
      const loginResponse = await this.makeRequest('/api/auth/login', {
        method: 'POST',
        body: {
          username: 'invalid',
          password: 'invalid'
        }
      });

      if ([400, 401, 422].includes(loginResponse.status)) {
        this.logTest('Invalid Login Rejection', true, 'Properly rejected invalid credentials');
      } else {
        this.logTest('Invalid Login Rejection', false, `Status: ${loginResponse.status}`);
      }

      // Test login with default credentials (should work in development)
      const defaultLogin = await this.makeRequest('/api/auth/login', {
        method: 'POST',
        body: {
          username: 'admin',
          password: 'admin123'
        }
      });

      if (defaultLogin.status === 200 && defaultLogin.data.token) {
        this.logTest('Default Admin Login', true, 'Default credentials work (change in production!)');
        
        // Test authenticated request
        const authResponse = await this.makeRequest('/api/sessions', {
          headers: {
            'Authorization': `Bearer ${defaultLogin.data.token}`
          }
        });

        if (authResponse.status === 200) {
          this.logTest('Authenticated Request', true, 'Token authentication works');
        } else {
          this.logTest('Authenticated Request', false, `Status: ${authResponse.status}`);
        }
      } else {
        this.logTest('Default Admin Login', false, 'Default credentials rejected or no token returned');
      }

    } catch (error) {
      this.logTest('Authentication Flow', false, error.message);
    }
  }

  // Test CORS headers
  async testCors() {
    console.log('\n🔍 Testing CORS Configuration...');
    
    try {
      const response = await this.makeRequest('/health');
      const corsHeader = response.headers['access-control-allow-origin'];
      
      if (corsHeader) {
        this.logTest('CORS Headers', true, `Origin: ${corsHeader}`);
      } else {
        this.logTest('CORS Headers', false, 'No CORS headers found');
      }
    } catch (error) {
      this.logTest('CORS Test', false, error.message);
    }
  }

  // Test rate limiting
  async testRateLimit() {
    console.log('\n🔍 Testing Rate Limiting...');
    
    try {
      const requests = [];
      // Make 15 rapid requests
      for (let i = 0; i < 15; i++) {
        requests.push(this.makeRequest('/health'));
      }

      const responses = await Promise.all(requests);
      const rateLimited = responses.some(r => r.status === 429);

      if (rateLimited) {
        this.logTest('Rate Limiting', true, 'Rate limiting is active');
      } else {
        this.logTest('Rate Limiting', false, 'No rate limiting detected (may need configuration)');
      }
    } catch (error) {
      this.logTest('Rate Limiting Test', false, error.message);
    }
  }

  // Run all tests
  async runAllTests() {
    console.log('🚀 Starting API Testing Suite...');
    console.log(`📡 Testing against: ${this.baseUrl}`);
    
    const startTime = Date.now();
    
    // Basic connectivity
    const healthOk = await this.testHealth();
    
    if (!healthOk) {
      console.log('\n❌ Server is not responding. Stopping tests.');
      return false;
    }

    // Run all tests
    await this.testApiEndpoints();
    await this.testAuthentication();
    await this.testCors();
    await this.testRateLimit();

    // Summary
    const endTime = Date.now();
    const duration = endTime - startTime;
    const passed = this.testResults.filter(r => r.success).length;
    const total = this.testResults.length;

    console.log('\n📊 Test Summary');
    console.log('================');
    console.log(`✅ Passed: ${passed}/${total}`);
    console.log(`❌ Failed: ${total - passed}/${total}`);
    console.log(`⏱️  Duration: ${duration}ms`);

    if (passed === total) {
      console.log('\n🎉 All tests passed! API is ready for deployment.');
      return true;
    } else {
      console.log('\n⚠️  Some tests failed. Please review before deployment.');
      
      // Show failed tests
      const failed = this.testResults.filter(r => !r.success);
      if (failed.length > 0) {
        console.log('\nFailed tests:');
        failed.forEach(test => {
          console.log(`  ❌ ${test.name}: ${test.message}`);
        });
      }
      return false;
    }
  }
}

// CLI usage
if (require.main === module) {
  const baseUrl = process.argv[2] || 'http://localhost:3000';
  const tester = new ApiTester(baseUrl);
  
  tester.runAllTests()
    .then(success => {
      process.exit(success ? 0 : 1);
    })
    .catch(error => {
      console.error('Test suite error:', error);
      process.exit(1);
    });
}

module.exports = ApiTester;