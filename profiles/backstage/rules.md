## Backstage

- Plugins follow `frontend-plugin-development` and `backend-plugin-development`. Docs come from
  backstage.io for the version in `backstage.json`.
- Find the plugin system from the code and follow it: `createFrontendPlugin` is the new frontend system,
  `createPlugin` the old one; backend plugins use `createBackendPlugin`. A new plugin in an app still on
  the old frontend system — ask the user.
- Backstage holds no infrastructure logic: a plugin calls the project's API, and the API starts Temporal
  workflows. Stock scaffolder templates are not used for this.
- The API client is generated from the API's OpenAPI schema with the generator the project already
  uses; no generator yet — ask the user. Never edit generated files.
- Checks: `yarn tsc`, `yarn lint`, `yarn test`. They miss most wiring problems: after a change tell the
  user to open the plugin's dev app (`yarn start` in the plugin directory) and check that the page
  renders and the browser console has no `App startup encountered warnings:` block.
