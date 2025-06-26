#!/bin/bash

# Deploy the updated create-user-admin Edge function
# Run this script to deploy the updated function with agent email confirmation changes

echo "🚀 Deploying updated create-user-admin Edge function..."

# Navigate to the project directory
cd /Users/abdullahsaad/AL-Tijwal/myapp/myapp

# Deploy the Edge function
supabase functions deploy create-user-admin

echo "✅ Edge function deployed successfully!"
echo ""
echo "📧 Changes made:"
echo "   - Agents: Email confirmation DISABLED (auto-confirmed)"
echo "   - Managers: Email confirmation ENABLED (requires verification)"
echo "   - Admins: Email confirmation ENABLED (requires verification)"
echo ""
echo "🔧 Next steps:"
echo "   1. Run the manual_email_confirmation.sql to confirm user.manager@test.com"
echo "   2. Test creating new agents (should work without email verification)"
echo "   3. Test creating new managers (will need email verification)"