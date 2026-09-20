# admin_core

Administration is done from two surfaces — the phone (`mobile`, the primary one
for school staff) and the desktop browser (`web_admin`) — against one API.
Before this package each app carried its own copy of the same models and
request code, so a field added to the API had to be mirrored twice and the two
copies drifted.

The package holds what is genuinely shared:

- **models** — one mapping per API schema, named after the API field names
- **repositories** — typed calls that take a configured `Dio`

Networking and authentication stay with each app: `mobile` uses `ApiClient`
with its refresh interceptor, `web_admin` uses `AdminApiClient`. Each passes
its own `Dio`, so neither app's session handling is duplicated here.

UI is deliberately not shared. A one-handed phone layout and a desktop table
are different products; merging them would make both worse.
