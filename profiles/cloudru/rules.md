## Cloud.ru Advanced

- Cloud.ru Advanced facts (Terraform provider `sbercloud`, OBS state backend, regions, API) follow
  `cloudru-fact-check`. Its `facts.md` holds verified general facts: a fact from there is copied into the
  project facts document with its source before code relies on it.
- Provider and backend credentials come only from the environment (`SBC_ACCESS_KEY`, `SBC_SECRET_KEY`,
  `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`), never from `access_key` or `secret_key` in a
  `provider` or `backend` block.
