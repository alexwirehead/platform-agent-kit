## Yandex Cloud

- Yandex Cloud API facts follow `yc-fact-check`. Its `facts.md` holds verified general facts: a fact
  from there is copied into the project facts document with its source before code relies on it.
- A service account key is read only from the path given in config; it is never logged, committed or
  put into `repr` and exception messages. Monitoring needs read-only roles: `auditor` or service
  roles like `*.auditor`, `k8s.viewer`; never the primitive `viewer` or `editor`.
