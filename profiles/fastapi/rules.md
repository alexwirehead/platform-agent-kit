## FastAPI

- Code follows the official `fastapi` skill. It describes the latest FastAPI: before using a feature,
  check that the version in `uv.lock` has it (FastAPI docs via `ctx7`); if not, do not use it.
- Deviations from `fastapi`: deploy is Kubernetes through the project's chart, never FastAPI Cloud
  (`fastapi deploy`). Its library advice (SQLModel, Asyncer and others) is not a rule: a new library is
  the user's decision. There is no database layer yet; adding one is the user's decision.
- The API is a Temporal client only: it starts workflows and reads their results; a Temporal worker
  never runs in the API process. The client is a dependency (`Annotated[..., Depends(...)]`) and tests
  replace it with `app.dependency_overrides`.
- Endpoint tests: `httpx.AsyncClient` with `ASGITransport(app=app)` or `TestClient`.
- The OpenAPI schema is the contract with Backstage. A change that breaks existing clients needs the
  user's approval; after any schema change tell the user to regenerate the client in Backstage.
