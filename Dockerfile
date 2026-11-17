# ---------- Étape 1 : build (dépendances isolées dans un venv) ----------
FROM python:3.13-slim AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build
COPY requirements.lock .

# Versions figées (pinning), aucun outil de compilation : wheels officiels uniquement
RUN python -m venv /opt/venv \
 && /opt/venv/bin/pip install --upgrade pip setuptools wheel \
 && /opt/venv/bin/pip install --only-binary=:all: -r requirements.lock

# ---------- Étape 2 : image finale minimale ----------
FROM python:3.13-slim

LABEL org.opencontainers.image.title="breakableflask-secure" \
      org.opencontainers.image.version="1.2"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# Utilisateur sans privilèges (pas d'apt : rien à installer dans l'image finale)
RUN groupadd --system app \
 && useradd --system --gid app --no-create-home --shell /usr/sbin/nologin app

WORKDIR /app

# Uniquement le venv et le code nécessaire, propriété root, lecture seule pour "app"
COPY --from=builder /opt/venv /opt/venv
COPY --chown=root:root --chmod=0644 main.py /app/

USER app

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:4000/').status==200 else 1)"

CMD ["python", "main.py"]
