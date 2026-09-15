# Discovery request/auth contract

Run from the iOS repository:

```sh
DISCOVERY_CONTRACT_INPUT=/absolute/path/to/recommended-response.json \
  python3 Tests/DiscoveryContract/run.py /absolute/path/to/new-output-directory
```

`run.py` copies the actual APIClient, AuthService, DiscoverViewModel, ProjectListViewModel, models and extensions byte-for-byte into a disposable Swift package. It records their SHA-256 hashes. Only Keychain storage and peripheral push/OAuth dependencies are test doubles; URLProtocol intercepts every request, with a real URLSession/URLCache and real production decoding. It never accesses real credentials, push services or users.

The optional JSON input is the exact NextResponse emitted by the web real-PostgreSQL suite with `DISCOVERY_CONTRACT_OUTPUT` set. Without it, that one artifact check returns early; the other request/decoding/lifecycle tests still run. CI/QA should supply it for cross-repository verification.

Tests cover endpoint/headers/snake_case, no-follow/401/signout empty states, both rails, account replacement before profile resolution, delayed restore after logout, in-flight credential changes, newer requests superseding older failures, list sort/filter/load-more, and cache-bypass policy (including anonymous list requests).

For iOS Simulator, in the output directory run `xcodegen generate --spec project.yml`, then `xcodebuild -project DiscoveryContract.xcodeproj -scheme DiscoveryContract -destination 'platform=iOS Simulator,id=AVAILABLE_DEVICE_ID' CODE_SIGNING_ALLOWED=NO test`. No changes to the app project or shared Xcode installation are required. macOS Swift tests do not claim device UI verification.

## Exact-SHA CI gate

`.github/workflows/ios-contracts.yml` (`iOS Contracts`, job `ios-contracts`) checks
out and verifies `github.sha`, runs both actual-source Swift packages and submission
contracts, builds unsigned generic iOS, then runs both hostless contract schemes
on an available iPhone simulator. Missing simulators fail the gate; no device UI
verification is implied. The artifacts bind logs and production-source hashes to
that SHA. PR runs test GitHub's merge SHA; release validation must use a successful
push-to-main or dispatch run whose **head SHA equals the release candidate**, not
a PR merge SHA or a staged tree. Dispatch on the candidate ref; there is no mutable
checkout override. Review this workflow independently alongside candidate source
before publishing. No signing, build-number change, upload, or deployment occurs.
The optional cross-repository HTTP fixture remains a separate QA check; CI without
`DISCOVERY_CONTRACT_INPUT` does not claim it was replayed.

Regressions include the exact independent QA same-account hidden-state, stale
same-credential response and pending-signout restore repros. Additional cases
cover both success/error completions, response cookies, visible labels/errors,
new-lifetime results, public trending and lifetime-triggered page reset. These
exercise actual AuthService transitions, not just view task timing.
