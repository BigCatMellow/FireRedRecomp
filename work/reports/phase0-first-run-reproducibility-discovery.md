# First-run reproducibility — bounded discovery

Discovery complete; **independent review required**. P0-04 remains **BLOCK**.
The smallest proposed follow-up is documentation only, not an installer,
runtime fix or new desktop-evidence claim.

- Task: [P0-04-DISCOVERY](../tasks/phase0-first-run-reproducibility-discovery.md).
- Inspection/public pin: `1a7c9958ab4ba42a8efac1fab42a8913e97acf36`.
- Accepted observations: [P0-04 report](phase0-clean-clone-verification.md),
  `d0e0bad7985e6797487ac339147a8e13d9c50369`, and its
  [independent review](../reviews/2026-10-01-clean-clone-verification-review.md).
- Original fresh-clone pin: `7a2e7ad7f6eec1a41c97f613143598b5de9c5a10`.

## Recovered evidence and blocker map

Public main independently matched the inspection pin. README, `conf.lua`,
main, ROM verifier, test runner, runtime smoke script and public test workflow
are unchanged between the original fresh-clone pin and this inspection pin.
The accepted 151-file no-ROM PASS, checker counts and two CLI refusal results
remain historical evidence for that original environment, not new results.
No fresh clone, game suite or desktop experiment was run for this discovery.

Read-only command discovery still finds Git, Bash, `sha1sum`, Xvfb,
`xvfb-run`, `xauth`, timeout and capture utilities, but no `lua5.1`, `lua` or
`love` on default PATH. Host identity remains Linux Mint 22.2/x86_64; Git
2.43.0 and Bash 5.2.21. A DISPLAY variable exists, which proves neither a
reachable display nor a visible app. No display value, machine path, private
ROM location or credential is retained here. The earlier isolated toolchain is
not promoted to a documented default prerequisite or newly installed here.

| P0-04 blocker | Exact current owner/evidence | Classification and minimum resolution |
| --- | --- | --- |
| Named first-run guide absent | No tracked `docs/FIRST_RUN.md`; [README](../../README.md) Running section gives `love .`, while prerequisites, verification, ROM environment and replay notes are dispersed below it. | Demonstrated documentation gap against the assigned verification contract, not a runtime defect. A guide plus a README entry link can consolidate existing commands, outcomes and stop conditions. |
| Default-PATH tools absent | README requires installed Git/Bash/Lua 5.1 and LÖVE 11.x; [test runner](../../scripts/test_all.sh):8 checks specifically `lua5.1` and exits 127 with an installation-required diagnostic. [conf.lua](../../conf.lua):7 declares 11.5. Prior desktop-tool evidence used LÖVE 11.5 through a pre-existing isolated wrapper. | Unmet/underspecified host preparation, not a demonstrated discovery bug. Document command/version preflight and declared prerequisites; do not fall back to arbitrary `lua` or assume the local wrapper exists elsewhere. |
| Desktop/refusal observation absent | Accepted Xvfb attempt failed at capture-display access; no usable capture or independently observed screen. [main](../../main.lua):3381 loads normally, :3400 adds the unset-ROM instruction, :2985 verifies configured input before decode, and :4831 draws status lines. | Missing observation and a failed capture attempt; runtime/display root cause is UNKNOWN. A later clean-target observation needs an already usable display; documentation cannot prove it repaired. |

No tracked host-bootstrap installer, package/dependency manifest or environment
lock declaring workstation setup was found in the inspected repository paths.
`tests/fresh_save_bootstrap_test.lua` concerns game save state, not host setup.
[Public CI](../../.github/workflows/test.yml) installs `lua5.1` through apt on
`ubuntu-latest`; that is not a Mint/macOS/Windows/mobile installation or support
contract. No package source or installer is selected by this research.

## Existing entry points and desktop-proof options

- `lua5.1 scripts/check_repository.lua` checks tracked Lua syntax and local
  Markdown targets. It is not an installer or documentation truth validator.
- `bash scripts/test_all.sh`, with ROM/replay unset, is the documented no-ROM
  suite. Configuring a nonexistent relative input or separately authored small
  ASCII file reaches production verification and must fail before decoding.
  Such negative runs are refusal evidence, not a passing ROM suite.
- [RomImporter](../../import/RomImporter.lua):29 uses external `sha1sum` for
  standalone-Lua hashing; LÖVE uses `love.data.hash`. The CLI invalid-input
  case therefore also needs `sha1sum`, not a valid ROM or new crypto package.
- [rom_importer_test](../../tests/rom_importer_test.lua) stubs LÖVE hashing
  under plain Lua and checks the supported table plus a missing file. Its PASS
  does not prove real LÖVE hashing, invalid-input desktop refusal or visibility.
- Normal `love .` can be observed without a ROM on an existing usable display.
  With developer/replay/scene overrides absent, the unset-ROM expectation is
  the project instruction, not an implemented file picker or drag/drop flow.
  Missing/synthetic-invalid inputs should show verification failure without
  loading game content. These remain source-derived expectations until observed.

Two existing mechanisms do not fill the desktop evidence gap:

1. README's `POKEPORT_SCREENSHOT=1` is not a normal no-ROM first-run hook.
   `love.load` returns early with ROM unset. Its later screenshot dispatch at
   main:4238–4262 requires a capture scene or active game/viewer state; normal
   refusal/status-only output does not satisfy that gate. Do not force an
   unrelated developer view merely to manufacture a capture.
2. [runtime_replay_smoke.sh](../../scripts/runtime_replay_smoke.sh):8 requires
   `POKEPORT_ROM`, checks love/Xvfb/timeout and expects a gameplay replay marker.
   It is not a no-ROM readiness/refusal harness. Neither module tests nor an
   unrelated private-runner probe substitutes for target desktop observation.

Direct observation of the normal app on an already usable target display is
the smallest later option. An existing external capture tool may record the
same screen outside Git, but generated pixels still require inspection. Xvfb
is only a possible headless display, not proven usable by its presence. Without
an observable screen/capture, retain BLOCK rather than repair the host or accept
process liveness. No GUI case or display diagnosis was attempted here.

## One proposed follow-up and conditional host assumption

Recommend at most one later **documentation-only first-run contract** whose
exact project edit surface is `README.md` and `docs/FIRST_RUN.md`, plus its own
separately authorized task/evidence. It should consolidate:

1. Prerequisite-ready host assumptions: Git/Bash, discoverable Lua 5.1 as
   `lua5.1`, `sha1sum` for CLI hash refusal, and LÖVE 11.5 for the observed
   desktop profile with an already usable graphics/display session.
2. Read-only command/version preflight, repository-root commands, ROM/replay
   isolation, user-supplied supported-US-v1.0 policy, and honest no-ROM versus
   configured-invalid outcomes, without implying a file-picker implementation.
3. A clean re-verification procedure and aggregate evidence template matching
   the matrix below, with stop-on-missing-prerequisite/display failure.

This is not a new platform support choice. The only measured workstation is
Linux Mint 22.2/x86_64; repeating that already provisioned profile would bound
verification, not prove clean-OS installation or all Linux support. Public CI's
`ubuntu-latest` host is separate. README's broad desktop/mobile language is not
tested host coverage. Do not convert these observations into a support policy.

Keep the work distinct: documentation is the proposed edit; tool discovery is
a prerequisite check, not a bootstrap change; desktop proof is later execution
evidence, not documentation acceptance. This proposal requires no installer,
PATH wrapper, manifest, workflow, test or runtime screenshot-hook change.
If a platform guarantee, fresh-OS bootstrap, dependency acquisition or desktop
repair is required, that is a missing product/host decision: stop for scope
selection, without choosing a package source or changing the environment.

## Proposed clean re-verification matrix

Only after independent discovery PASS and a separately authorized/reviewed
documentation change should fresh P0-04 verification occur. Use a newly cloned
exact public revision and declared target environment, not the old clone
relabeled as repaired. Preserve the accepted historical baseline.

| Check | Required observation / refusal boundary | Existing public CI coverage |
| --- | --- | --- |
| Prerequisites / clean target | Record OS/architecture and actual versions; no unstated local wrapper/state. Missing tools or unusable display are BLOCK, not install authority. | CI proves its own Lua installation/runner only, not workstation or pristine-OS setup. |
| No-ROM CLI | From clone root with ROM/replay unset, checker and full suite exit 0; dynamic counts and explicit ROM skips recorded. | Yes, both commands; local fresh-clone proof remains distinct. |
| Configured missing CLI input | Documented environment-variable entrypoint exits nonzero at production verification for a deliberately nonexistent relative path, before decode. | Not as this standalone configured-input case; current module assertion is narrower. Feasible without ROM in future CI, but no workflow change proposed. |
| Synthetic invalid CLI input | Fresh small ASCII input outside clone; unrecognized-hash refusal, nonzero exit, no game data/decode. | Not explicitly covered by current workflow as this production entrypoint; no private ROM is needed. |
| Unset-ROM desktop | Normal `love .` visibly shows project instruction, no game content/fatal error; observe then close the owned process normally. | No LÖVE/display installation or desktop launch in current workflow; clean-target/local for this proposal. |
| Missing / synthetic-invalid desktop | Separate fresh processes visibly show verification failure, no game scene/crash. Do not require nonzero GUI exit: current app reports refusal as status text. | No; CLI/module refusal does not prove visible refusal or real LÖVE hashing. |
| Isolation / final state | External fresh XDG/TMP directories, cleared inherited developer overrides, no old save/cache. Record tracked/untracked/ignored clone cleanliness and absence of game save/cache; distinguish transient graphics cache. Do not remove user files. | CI checkout is not local desktop isolation or cleanup evidence. |

Only a future verification task may create its disposable inputs/XDG/logs or
launch these processes. Publish aggregate outcomes, exact revision, versions,
exit statuses, visible-message category and evidence method, not absolute
machine/private paths, environment dumps, credentials, ROMs, saves, game caches
or screenshots. This matrix needs no valid ROM. Positive-ROM, gameplay,
persistence and retail visual-parity proof remain separate.

## Handoff

Only this report and the assigned task handoff are authored. No installation,
download, persistent environment/session change, GUI retry, ROM access,
runtime/test/workflow/documentation repair or Phase 0 advancement occurred.
Source inspection and tool discovery support a proposal, not repaired behavior.

Independent review must assess the exact discovery before any repair task is
created. If accepted, parent may choose the single documentation-only follow-up
with the conditional profile above. If the intended product promise exceeds
it, retain the host/support decision blocker. P0-04 and broader save safety
remain open.
