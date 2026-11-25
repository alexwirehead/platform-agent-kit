## Python exporter

- Exporter code, metrics, logs and tests follow `python-exporter`; general Python rules — profile `python`.
- Local stand: `uv run python dev/run_fake.py --scenario <name> --port 8080`.
- The polled system is never called from tests or the stand: fixtures and fake clients only.
