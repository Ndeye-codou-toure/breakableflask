# ---------- Étape 1 : build (dépendances isolées dans un venv) ----------
FROM python:3.13-slim AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build
COPY requirements.lock .

# Versions figées, wheels officiels uniquement,
# puis suppression de pip/setuptools/wheel du venv (inutiles à l'exécution)
RUN python -m venv /opt/venv \
 && /opt/venv/bin/pip install --only-binary=:all: -r requirements.lock \
 && /opt/venv/bin/python -m pip uninstall -y pip setuptools wheel || true

# ---------- Étape 2 : image finale minimale ----------
FROM python:3.13-slim

LABEL org.opencontainers.image.title="breakableflask-secure" \
      org.opencontainers.image.version="1.3"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# Retire les outils d'installation de l'image de base (pip embarque urllib3, msgpack...)
# puis crée un utilisateur sans privilèges
RUN python -m pip uninstall -y pip setuptools wheel || true \
 && rm -rf /usr/local/lib/python3*/ensurepip /root/.cache \
 && groupadd --system app \
 && useradd --system --gid app --no-create-home --shell /usr/sbin/nologin app

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
COPY --chown=root:root --chmod=0644 main.py /app/

USER app

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:4000/').status==200 else 1)"

CMD ["python", "main.py"]
