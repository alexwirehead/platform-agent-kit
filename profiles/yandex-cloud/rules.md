## Yandex Cloud

- Yandex Cloud API facts follow `yc-fact-check`; verified general facts are in its `facts.md`.
- A service account key is read only from the path given in config; it is never logged, committed or
  put into `repr` and exception messages. Monitoring needs read-only roles (`auditor` level), never
  `viewer` or `editor`.
