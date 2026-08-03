# Built and hosted by LiveKit Cloud (`lk agent create`). Nothing here runs on
# our own infrastructure.
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Downloads any model weights the plugins need at build time rather than on the
# first call, so a cold session is not paying for them.
RUN python agent.py download-files || true

CMD ["python", "agent.py", "start"]
