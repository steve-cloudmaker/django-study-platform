# API load test (Python + Textual TUI)

Generates **writes** (create study + create submission) and **reads** (list studies, get study, get submission) against the Django API. Submission bodies are JSON strings from **100 cached surveys** in `data/surveys/` (smartphone-usage themed, five questions each).

## Setup

```bash
cd loadtest
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
# If surveys are missing:
python3 generate_surveys.py
```

## Run

```bash
.venv/bin/python main.py \
  --base-url https://api.charliesystems.ai \
  --read-qps 5 \
  --write-qps 1 \
  --duration 120 \
  --ramp-up 20
```

- **`q`**: quit early.
- **`--duration SEC`**: stop after this many seconds (**default 300**). Use **`0`** to run until you press `q`.
- **`--ramp-up SEC`**: linear ramp — effective read and write QPS start at 0 and reach the targets over this window (**default 30**). Use **`0`** for full rate from the start.
- **`--insecure`**: skip TLS verify (lab only).

If **`--ramp-up`** is greater than **`--duration`**, the tool exits with an error so you never reach full target QPS.

## Caveats

- **DRF throttling** (`API_RATE_LIMIT` on the API) is per IP per replica; high QPS will return **429** unless you raise the limit for the test.
- Each **write** is two HTTP calls (study + submission); `--write-qps` is **pairs** per second (both calls issued back-to-back, then pacing).
- **Reads** before any write only hit `GET /api/studies/`; after writes, the tool mixes in study and submission GETs using its in-memory ID pool.
- Surveys are sized **under 2k** for `Submission.content`.
