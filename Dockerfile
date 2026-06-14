FROM python:3.10-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV JANEWAY_SETTINGS_MODULE=core.settings

# Set working directory
WORKDIR /vol/janeway

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    libxml2-dev \
    libxslt-dev \
    libssl-dev \
    libffi-dev \
    libjpeg-dev \
    zlib1g-dev \
    libpq-dev \
    default-libmysqlclient-dev \
    pkg-config \
    gettext \
    pylint \
    curl \
    libmagic1 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements files first for caching
COPY requirements.txt dev-requirements.txt ./

# Install python dependencies
RUN pip3 install --no-cache-dir -r requirements.txt --src /tmp/src \
    && pip3 install --no-cache-dir -r dev-requirements.txt --src /tmp/src \
    && pip3 install --no-cache-dir mysqlclient gunicorn

# Copy project files
COPY . .

# Run find plugins and install requirements if any
RUN find "/vol/janeway/src/plugins/" -print -iname "*requirements.txt" -exec pip3 install -r {} --src /tmp/src \; || true

# Copy library packages if any and install them
RUN if [ -n "$(ls -A ./lib 2>/dev/null)" ]; then pip3 install -e lib/*; fi || true

# Setup settings.py if not present
RUN cp src/core/janeway_global_settings.py src/core/settings.py

# Create directory for sqlite database and logs
RUN mkdir -p /db /vol/janeway/logs /vol/janeway/src/media /vol/janeway/src/collected-static

# Copy and prepare entrypoint
RUN chmod +x dockerfiles/entrypoint.sh && cp dockerfiles/entrypoint.sh /entrypoint.sh

# Expose port
EXPOSE 8000

# Stop signal
STOPSIGNAL SIGINT

ENTRYPOINT ["/entrypoint.sh"]
CMD ["python3", "src/manage.py", "runserver", "0.0.0.0:8000", "--insecure"]
