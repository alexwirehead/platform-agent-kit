## External API

- Agents never call the real external system and never ask for its keys or tokens. Everything is
  checked on fixtures, fake clients and the local stand; acceptance on the real system is done by a
  person with access by the acceptance checklist.
- The only source of API facts is the facts document (path in the project section, default
  `docs/api-facts.md`). A missing fact — `api-fact-check`; library APIs — `source-driven-development`.
- Mounted credential files are never read.
