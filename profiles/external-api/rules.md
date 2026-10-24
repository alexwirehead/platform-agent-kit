## External API

- Agents never call the real system's API with credentials and never ask for its keys or tokens.
  Everything is checked on fixtures, fake clients and the local stand; acceptance on the real system is
  done by a person with access by the acceptance checklist.
- Public vendor material without authentication — documentation, spec repositories, a public endpoint
  registry — is a source of facts and may be downloaded.
- The only source of API facts is the facts document (path in the project section, default
  `docs/api-facts.md`). A missing fact — `api-fact-check`; library APIs — `source-driven-development`.
- Mounted credential files are never read.
