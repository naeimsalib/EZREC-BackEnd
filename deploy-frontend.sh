#!/bin/bash

# Exit on error
set -e

echo "🚀 Starting frontend deployment process..."

# Navigate to frontend directory
cd frontend

echo "📦 Installing dependencies..."
npm install

echo "🏗️ Building frontend..."
npm run build

echo "📤 Syncing to S3 bucket..."
aws s3 sync dist/ s3://soccer-cam-website --delete

echo "🔄 Creating CloudFront invalidation..."
aws cloudfront create-invalidation --distribution-id E3GZAK3FXYZ2F6 --paths "/*"

echo "✅ Deployment completed successfully!" 