#!/bin/bash
set -e

echo "=== Checking Flutter SDK ==="
if [ ! -d "$HOME/flutter" ]; then
  echo "Installing Flutter..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
fi
export PATH="$PATH:$HOME/flutter/bin"

if [ -d "apps/user_app" ]; then
  cd apps/user_app
fi

SUPA_URL="${SUPABASE_URL:-https://iyylimmyuqlgrmsclvqp.supabase.co}"
SUPA_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml5eWxpbW15dXFsZ3Jtc2NsdnFwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcxNTc4NDAsImV4cCI6MjA4MjczMzg0MH0.5Fo43YPkOrxbrSUBCfQwqj8AE7FaLgGFDzAf9S8QBrY}"

echo "=== Building Flutter Web ==="
flutter build web --dart-define=SUPABASE_URL="$SUPA_URL" --dart-define=SUPABASE_ANON_KEY="$SUPA_KEY"
