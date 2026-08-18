<!-- Keep it simple. Fill the sections, tick the boxes, delete lines that don't apply. -->

## What does this change do?
<!-- One or two sentences in plain language. e.g. "Adds the isclaims API with two operations." -->

## Type of change
- [ ] New API
- [ ] Update to an existing API (spec / policy / operation)
- [ ] Shared change (named value / backend / tag / policy fragment) — platform team
- [ ] Pipeline or docs

## Checklist
- [ ] I only changed files inside my own API folder (`apimartifacts/apis/<my-api>/`), unless I'm on the platform team.
- [ ] My API has both `apiInformation.json` and `specification.json` (or `.yaml`).
- [ ] Operation policy folders match the `operationId`s in my spec.
- [ ] If my backend URL differs in production, I added an override in `configuration.prod.yaml`.
- [ ] I ran **APIOps: Validate artifacts** (VS Code task) and it passed.

## How I tested
<!-- e.g. "Ran the Validate task — passed." or "Verified the spec opens in Swagger Editor." -->

## Anything reviewers should know?
<!-- Optional. Links, screenshots, breaking changes, rollout notes. -->
