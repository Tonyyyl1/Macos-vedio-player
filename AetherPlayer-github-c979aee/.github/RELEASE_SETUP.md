# Release automation setup

`.github/workflows/release-dmg.yml` builds, signs, notarizes, and uploads an `AetherPlayer-<version>.dmg` as a release asset on every published GitHub Release (and can be run manually against an existing tag via `workflow_dispatch`). To work, the runner needs a Developer ID Application certificate and Apple notarization credentials, provided as repository secrets.

This is a one-time setup. Once the six secrets below are populated, the workflow runs automatically on every release.

## Secrets

Add each at [Settings -> Secrets and variables -> Actions -> New repository secret](https://github.com/superuser404notfound/AetherPlayer/settings/secrets/actions/new).

These two are already set (low-sensitivity values, pre-populated):

- **`DEVELOPER_ID`** -- `Developer ID Application: Vincent Herbst (4NY63S72W9)`
- **`APPLE_TEAM_ID`** -- `4NY63S72W9`

You still need to add these four (same values you used for AetherEngine's release workflow):

### `APPLE_ID`
Apple ID email associated with the Developer Account.

### `APPLE_APP_PASSWORD`
App-specific password from [account.apple.com](https://account.apple.com) -> Sign-In and Security -> App-Specific Passwords (format `xxxx-xxxx-xxxx-xxxx`). The one used for AetherEngine works, or generate a new one labeled "AetherPlayer CI".

### `DEVELOPER_ID_P12_PASSWORD`
A password you pick when exporting the cert (see next). Any non-empty string; used only to decrypt the .p12 on the runner.

### `DEVELOPER_ID_P12_BASE64`
Base64 of the `.p12` export of your Developer ID Application certificate **and its private key**:

1. Keychain Access -> login keychain -> My Certificates.
2. Find `Developer ID Application: Vincent Herbst (4NY63S72W9)`, expand to show cert + private key.
3. Select both, right-click -> Export 2 items -> `Personal Information Exchange (.p12)`.
4. Set the export password to the same value as `DEVELOPER_ID_P12_PASSWORD`.
5. `base64 -i ~/Desktop/developerid.p12 | pbcopy`, paste into the secret, then `rm` the local .p12.

A .p12 with the private key is equivalent to your code-signing identity. The workflow imports it into a fresh disposable keychain torn down at job exit; never paste the base64 anywhere outside the secrets store.

## Smoke-test

Once all four remaining secrets are set:

1. [Actions](https://github.com/superuser404notfound/AetherPlayer/actions) -> `Release .dmg` -> `Run workflow` -> enter tag `0.1.0` -> Run.
2. It should reach "Upload .dmg to release" and finish green. The `.dmg` then appears under the `0.1.0` release's Assets (or `--clobber`s the existing one).

After that, every future `gh release create` triggers the workflow automatically on `release: published`.
