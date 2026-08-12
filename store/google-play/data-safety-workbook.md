# Google Play Data Safety workbook

This is an engineering prefill, not a submission. The launch owner must reconcile
it with the production deployment, every SDK's current disclosure, the approved
privacy policy, and Play Console wording before submission.

| Data category | Collected off device | Shared with processor | Purpose | Required | Deletion/export |
| --- | --- | --- | --- | --- | --- |
| Account identifier | Yes | Auth0 and configured identity provider | Authentication, security | Yes for an account | In-app export and account deletion |
| Email address | When authorized by identity provider | Auth0 and identity provider | Account identity | Optional | In-app export and account deletion |
| User-provided confirmed conversation text | Yes, after explicit review/save | OpenRouter and the plan-selected model provider only after separate consent | App functionality: requested coaching | Optional feature input | Conversation deletion, export, account deletion |
| Raw screenshot/image bytes | No | No | On-device OCR only | No | Cleared after save or abandoned import |
| Communication preferences/private reflections | Preferences: backend; reflections: device only | No advertising or data brokers | Personalization and app functionality | Optional | Export/deletion controls; device journal can be cleared |
| Purchase/subscription metadata | Yes, pseudonymous references | Google Play and backend verifier | Purchases, fraud prevention, account management | Only for Plus | Account export; retention follows approved legal schedule |
| App activity and diagnostics | Content-free counts/status/correlation metadata | Production infrastructure operators | Security, reliability, quota enforcement | Yes when service is used | Bounded retention; account export where linked |
| AI safety report metadata | Opaque response ID and bounded category only | Production infrastructure operators | Safety, moderation, abuse prevention | Optional | Account export and deletion cascade |

No advertising SDK is approved. No data may be sold. No raw message, prompt,
screenshot, credential, token, or generated response may enter logs or analytics.

Before Console submission, verify:

- the exact Google Play Billing, Auth0, OpenRouter, selected model-provider, crash
  reporting, and analytics disclosures for the shipped binary;
- encryption in transit and at rest;
- the published privacy-policy URL and in-app policy link;
- the in-app deletion path and external HTTPS deletion resource;
- retention periods, subprocessors, regions, and deletion timelines approved by
  counsel; and
- that the Play Console answers match the final production build, not this draft.
