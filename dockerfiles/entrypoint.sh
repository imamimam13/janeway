#!/bin/bash
set -e

# Wait for DB if vendor is postgres or mysql/mariadb
if [ "$DB_VENDOR" = "postgres" ] || [ "$DB_VENDOR" = "mysql" ] || [ "$DB_VENDOR" = "mariadb" ]; then
  echo "Waiting for database ($DB_HOST:$DB_PORT)..."
  python3 -c "
import socket, time, sys
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(2)
for i in range(30):
    try:
        s.connect(('$DB_HOST', int('$DB_PORT')))
        sys.exit(0)
    except Exception as e:
        time.sleep(2)
sys.exit(1)
"
  echo "Database is ready!"
fi

# Run migrations
echo "Running database migrations..."
python3 src/manage.py migrate --noinput

# Compile translations
echo "Compiling translation files..."
python3 src/manage.py compilemessages || echo "Failed to compile messages (non-critical)"

# Run install_janeway if not already installed
echo "Checking if Janeway is installed..."
if python3 src/manage.py shell -c "from press.models import Press; exit(0 if Press.objects.exists() else 1)" 2>/dev/null; then
    echo "Janeway is already installed."
else
    echo "Janeway is not installed. Running installation..."
    python3 src/manage.py install_janeway --use-defaults
fi

# Create superuser if env vars are present
if [ -n "$DJANGO_SUPERUSER_USERNAME" ] && [ -n "$DJANGO_SUPERUSER_PASSWORD" ] && [ -n "$DJANGO_SUPERUSER_EMAIL" ]; then
    echo "Checking if superuser exists..."
    if python3 src/manage.py shell -c "from django.contrib.auth import get_user_model; User = get_user_model(); exit(0 if User.objects.filter(is_superuser=True, username='$DJANGO_SUPERUSER_USERNAME').exists() else 1)" 2>/dev/null; then
        echo "Superuser '$DJANGO_SUPERUSER_USERNAME' already exists."
    else
        echo "Creating superuser '$DJANGO_SUPERUSER_USERNAME'..."
        python3 src/manage.py createsuperuser --noinput || echo "Failed to create superuser"
    fi
fi

# Execute CMD
echo "Starting Janeway..."
exec "$@"
