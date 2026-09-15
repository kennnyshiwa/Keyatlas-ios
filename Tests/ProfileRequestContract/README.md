# Profile request contract

Run from the repository root on macOS with Xcode/Swift 6:

```sh
python3 Tests/ProfileRequestContract/run.py /tmp/keyatlas-profile-contract-unique
```

The destination must not exist. The runner stages byte-for-byte copies of the
production `ProfileViewModel`, `APIClient`, profile/project models and their
Foundation dependencies, recording SHA-256 hashes. Swift Testing executes 9 test
definitions / 14 cases, including parameterized anonymous, bearer, cookie and
combined-credential requests and follow/unfollow round trips.

Only `KeychainService` is replaced by a lock-protected, memory-only double (no
Security import). Tests inject an ephemeral URLSession with no cookie storage,
credential storage or cache and a catch-all URLProtocol that never forwards to
network. The app host and AuthService are not compiled or launched. All account
names, credentials and responses are fixtures. There are no external packages.
Production shared-client behavior and default initializers remain unchanged.

Optional iOS simulator execution of the same staged source/test files:

```sh
xcodegen generate --spec /tmp/keyatlas-profile-contract-unique/project.yml
xcodebuild -project /tmp/keyatlas-profile-contract-unique/ProfileRequestContract.xcodeproj \
  -scheme ProfileRequestContract -destination 'platform=iOS Simulator,id=YOUR_ISOLATED_SIMULATOR_UUID' \
  -derivedDataPath /tmp/keyatlas-profile-contract-unique/DerivedData \
  -resultBundlePath /tmp/keyatlas-profile-contract-unique/Tests.xcresult \
  CODE_SIGNING_ALLOWED=NO test
```

The generated iOS project is hostless. Do not substitute production KeychainService
or use a real signed-in app host. The ordinary app project/build configuration is
not changed by these tests.

These are client wire/decoding/state tests, not server authorization tests. A
fixture omitting email/private projects checks decoding compatibility, not actual
server privacy filtering. UI settings/avatar editing/draft submission behavior
requires independent app QA; the production files for those flows are untouched.
