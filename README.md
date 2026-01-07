# Spanish Sentence App (Spanish -> English + Voice)

This app generates endless Spanish practice sentences using the 100 most common verbs.
It shows Spanish first, then reveals English, and can speak both.

## Quickstart

1) Create and activate a venv
```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

2) Install Docker if not installed

3) Run these commands
```bash
# Build the image
docker build -t spanish-sentence-app:latest .

# Run the container
docker run --rm -it \
  -p 8501:8501 \
  -e OPENAI_API_KEY="<YOUR_OPENAI_API_KEY>" \
  -e OPENAI_MODEL="gpt-5-mini" \
  -e OPENAI_REASONING_EFFORT="low" \
  spanish-sentence-app:latest
```

4) Connect here: http://localhost:8501/