#!/bin/bash

# translateMd Setup Script
echo "🏥 translateMd Clinical Interpreter Setup"
echo "========================================="

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js 18+ first."
    exit 1
fi

echo "✅ Node.js found: $(node --version)"

# Setup server
echo ""
echo "📦 Setting up development server..."
cd server

if [ ! -f package.json ]; then
    echo "❌ Server files not found. Make sure you're in the right directory."
    exit 1
fi

# Install dependencies
npm install

# Check if .env exists
if [ ! -f .env ]; then
    echo ""
    echo "⚠️  Creating .env file from template..."
    cp .env.example .env
    echo "📝 Please edit server/.env and add your OpenAI API key:"
    echo "   OPENAI_API_KEY=sk-your-openai-api-key-here"
    echo ""
else
    echo "✅ .env file already exists"
fi

# Check if OpenAI API key is set
if grep -q "sk-your-openai-api-key-here" .env 2>/dev/null; then
    echo "⚠️  Please update your OpenAI API key in server/.env"
elif grep -q "OPENAI_API_KEY=sk-" .env 2>/dev/null; then
    echo "✅ OpenAI API key appears to be configured"
else
    echo "⚠️  Please add your OpenAI API key to server/.env"
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "1. Edit server/.env with your OpenAI API key if you haven't already"
echo "2. Start the dev server: cd server && npm start"
echo "3. Open translateMd/translateMd.xcodeproj in Xcode"
echo "4. Build and run on a physical iOS device"
echo ""
echo "⚠️  IMPORTANT: This is a prototype using public OpenAI API."
echo "   Do NOT use with PHI/PII - not HIPAA compliant!"
echo ""