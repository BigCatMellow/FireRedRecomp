# Viridian C0 roadblock bridge route — Worker evidence

- Task: `P5-06-VIRIDIAN-ROADBLOCK-ROUTE-CONFIG`.
- Status: `CONFIGURATION IMPLEMENTED; INDEPENDENT REVIEW REQUIRED`.
- Base: `72a18e903164f3f2f8532676a94c610a9da241c2` (`origin/main`).
- Branch: `work/p5-viridian-roadblock-route-config-20261018`.
- Worktree: `/tmp/firered-roadblock-route-config.8esU8V`.
- Configuration implementation commit: `PENDING_FIRST_COMMIT`.
- Exact published review head: `PENDING_PUBLICATION`.

The accepted design prerequisite is the independent `PASS` at
`1199a74db8dbbeb1528b171159096bd7d90767c5`; design PR 45 merged as
`6006ab6fbc7b9f1dd60a88dcbf6a8b0a08692947`. The current authority/base
contains no workflow or bridge-procedure delta from that design merge requiring
reconciliation.

## Result

The workflow now maps only
`phase5-viridian-roadblock*.patch|phase5-viridian-roadblock*.probe` to
`phase5-viridian-roadblock`. Its patch target allowlist and publish staging
surface are the same exact nine paths required by the task. A dedicated
post-application gate requires all nine regular files before focused or shared
evidence. The publish arm independently requires all nine before staging any
path, then stages only the nine literal paths.

The focused arm contains the required six `$LUA` commands in order. Existing
shared suite steps remain unchanged:
`env -u POKEPORT_ROM bash scripts/test_all.sh`, then
`bash scripts/test_all.sh` in the already-gated verified-ROM environment.
The route's replay arm contains only
`bash scripts/runtime_viridian_roadblock_replay.sh`. Existing selectors,
routes, target guards, suite steps, replay meaning, and publication behavior
were preserved byte-for-byte; the workflow change is additive.

Changed paths are exactly:

1. `.github/workflows/local-worker-bridge.yml`
2. `work/coordination/LOCAL_RUNNER_BRIDGE.md`
3. `work/tasks/local-worker-bridge-phase5-viridian-roadblock-route-configuration.md`
4. `work/reports/local-worker-bridge-phase5-viridian-roadblock-route-configuration.md`

## Baseline evidence

With `PATH=/home/home/.local/share/firered-toolchain/bin:$PATH` and both
`POKEPORT_ROM` and `POKEPORT_RUNTIME_REPLAY` unset:

```bash
env -u POKEPORT_ROM bash scripts/test_all.sh
lua5.1 scripts/check_repository.lua
git diff --check
```

Exit status was 0. The suite reported `PASS: 193 test files (no-ROM mode; ROM-dependent checks skip cleanly)`.
The checker reported `PASS: repository checks (321 tracked Lua, 374 tracked Markdown, 1258 local targets)`.
`git diff --check` produced no output.

## Safe offline harness evidence

The harness was created outside the repository at
`/tmp/viridian-roadblock-route-config-harness.py`. Every synthetic fixture
was created under a `/tmp/firered-roadblock-route-config-*` temporary
directory and automatically removed by `TemporaryDirectory`. The harness
cleared both ROM-related variables from every child environment. It did not
dispatch Actions, contact a runner, locate/request/read a ROM, execute tests or
the configured replay, stage repository content, commit, or push. Lua, replay
`bash`, and mutating Git operations were inert temporary stubs; its only real
Git operation was a read-only diff against the base.

Command:

```bash
python3 /tmp/viridian-roadblock-route-config-harness.py /tmp/firered-roadblock-route-config.8esU8V 72a18e903164f3f2f8532676a94c610a9da241c2
```

Exit status: 0. Output:

```text
PASS: YAML parsed; 13 Bash blocks passed bash -n
PASS: existing workflow lines preserved; patch/probe selectors and unknown rejection verified
PASS: exact nine-target allowlist; forbidden/empty/targetless/unknown-route rejection verified
PASS: all 9 pre-evidence and all 9 pre-staging missing-artifact cases failed before execution
PASS: exact six focused commands, shared suites, dedicated replay, literal staging, and probe separation verified
```

The executed harness SHA-256 was
`74d4fe6f41ef3a2f3c5bab9466ab7978c810ef923354aaad6528dd85e7a72585`.
Complete reproducible source:

```python
#!/usr/bin/env python3
import os
import re
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml


REPO = Path(sys.argv[1]).resolve()
BASE = sys.argv[2]
WORKFLOW = REPO / ".github/workflows/local-worker-bridge.yml"
ROUTE = "phase5-viridian-roadblock"
REQUIRED = [
    "src/core/ViridianRoadblock.lua",
    "src/core/PlayerMovement.lua",
    "main.lua",
    "tests/phase5_viridian_roadblock_test.lua",
    "tests/phase5_viridian_roadblock_integration_test.lua",
    "tests/phase5_viridian_roadblock_rom_test.lua",
    "tests/player_movement_test.lua",
    "scripts/runtime_viridian_roadblock_replay.sh",
    "work/tasks/phase5-viridian-roadblock-implementation.md",
]
FOCUSED = [
    "tests/phase5_viridian_roadblock_test.lua",
    "tests/phase5_viridian_roadblock_integration_test.lua",
    "tests/player_movement_test.lua",
    "tests/phase5_player_elevation_input_test.lua",
    "tests/early_story_test.lua",
    "tests/phase5_viridian_roadblock_rom_test.lua",
]


def check(ok, message):
    if not ok:
        raise AssertionError(message)


def run_shell(source, cwd, extra_env=None):
    env = os.environ.copy()
    env.pop("POKEPORT_ROM", None)
    env.pop("POKEPORT_RUNTIME_REPLAY", None)
    if extra_env:
        env.update(extra_env)
    return subprocess.run(
        ["/bin/bash", "-c", source], cwd=cwd, env=env,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )


def write_executable(path, source):
    path.write_text(source)
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def make_patch(path, targets):
    chunks = []
    for target in targets:
        chunks.extend([
            f"--- a/{target}", f"+++ b/{target}", "@@ -1 +1 @@",
            "-old", "+new",
        ])
    path.write_text("\n".join(chunks) + "\n")


def materialize(root, paths):
    for relative in paths:
        target = root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("fixture\n")


workflow_text = WORKFLOW.read_text()
document = yaml.safe_load(workflow_text)
steps = document["jobs"]["local-worker"]["steps"]
by_name = {step.get("name"): step for step in steps if step.get("name")}

names = [step.get("name") for step in steps]
selector = by_name["Select explicit task route"]
validation = by_name["Validate bounded patch targets"]
pre_evidence = by_name["Verify Viridian roadblock artifacts before evidence"]
focused = by_name["Run task-focused test"]
no_rom = by_name["Run no-ROM suite"]
verified_rom = by_name["Run verified-ROM suite"]
replay = by_name["Run task runtime replay"]
publish = by_name["Publish verified bounded implementation"]
probe = by_name["Probe complete"]

# YAML and every Bash run block must parse; the new step ordering must gate all
# package evidence, and publication must remain last.
shell_count = 0
for step in steps:
    if step.get("shell") == "bash" and "run" in step:
        shell_count += 1
        parsed = subprocess.run(
            ["/bin/bash", "-n"], input=step["run"], text=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        check(parsed.returncode == 0, f"bash -n failed for {step.get('name')}: {parsed.stderr}")
check(names.index("Apply bounded patch") < names.index(pre_evidence["name"]) < names.index(focused["name"]),
      "pre-evidence artifact gate ordering")
check(names.index(focused["name"]) < names.index(no_rom["name"]) < names.index(verified_rom["name"]) < names.index(replay["name"]) < names.index(publish["name"]),
      "focused/full/replay/publish ordering")
check(pre_evidence["if"] == "steps.request.outputs.mode == 'patch' && steps.route.outputs.route == 'phase5-viridian-roadblock'",
      "route-specific pre-evidence predicate")
for step in (validation, focused, no_rom, verified_rom, replay, publish):
    check(step["if"] == "steps.request.outputs.mode == 'patch'", f"patch-only predicate changed: {step['name']}")
check(probe["if"] == "steps.request.outputs.mode == 'probe'", "probe predicate changed")

# Existing workflow text is preserved byte-for-byte: this configuration may
# add route-specific lines but may not remove or alter an existing line.
diff = subprocess.run(
    ["git", "diff", "--unified=0", BASE, "--", str(WORKFLOW.relative_to(REPO))],
    cwd=REPO, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
).stdout
removed = [line for line in diff.splitlines() if line.startswith("-") and not line.startswith("---")]
check(not removed, f"existing workflow line removed/altered: {removed}")

with tempfile.TemporaryDirectory(prefix="firered-roadblock-route-config-", dir="/tmp") as temp_name:
    temp = Path(temp_name)
    bin_dir = temp / "bin"
    bin_dir.mkdir()
    output = temp / "github-output"
    log = temp / "stub.log"
    stub_env = {
        "PATH": f"{bin_dir}:{os.environ['PATH']}",
        "STUB_LOG": str(log),
    }

    write_executable(bin_dir / "git", """#!/bin/bash
printf '%s\\n' "$*" >> "$STUB_LOG"
if [[ "${1:-}" == diff && "${2:-}" == --cached && "${3:-}" == --quiet ]]; then
  exit 1
fi
exit 0
""")
    write_executable(bin_dir / "lua5.1", """#!/bin/bash
printf '%s\\n' "$*" >> "$STUB_LOG"
""")

    # Exact selector positives and representative fail-closed negatives.
    for filename in (
        "phase5-viridian-roadblock.patch",
        "phase5-viridian-roadblock-20261018.patch",
        "phase5-viridian-roadblock.probe",
        "phase5-viridian-roadblock-route-20261018.probe",
    ):
        output.write_text("")
        result = run_shell(selector["run"], temp, {"REQUEST_FILE": filename, "GITHUB_OUTPUT": str(output)})
        check(result.returncode == 0, f"selector rejected {filename}: {result.stderr}")
        check(output.read_text().splitlines() == [f"route={ROUTE}"], f"selector output for {filename}")
    for filename in ("unknown.patch", "xphase5-viridian-roadblock.patch", "phase5-viridian-roadblock.patch.bak"):
        output.write_text("")
        result = run_shell(selector["run"], temp, {"REQUEST_FILE": filename, "GITHUB_OUTPUT": str(output)})
        check(result.returncode != 0 and output.read_text() == "", f"selector accepted {filename}")

    # Target validation accepts exactly the nine paths and rejects forbidden,
    # empty, targetless, and unknown-route inputs before any git operation.
    patch = temp / "request.patch"
    make_patch(patch, REQUIRED)
    log.write_text("")
    result = run_shell(validation["run"], temp, {**stub_env, "PATCH_FILE": str(patch), "ROUTE": ROUTE})
    check(result.returncode == 0, f"nine-target validation failed: {result.stderr}")
    check(log.read_text().splitlines() == [f"apply --check {patch}"], "unexpected validation git calls")

    for targets in (["README.md"], ["work/coordination/STATE.json"]):
        make_patch(patch, targets)
        log.write_text("")
        result = run_shell(validation["run"], temp, {**stub_env, "PATCH_FILE": str(patch), "ROUTE": ROUTE})
        check(result.returncode != 0 and log.read_text() == "", f"forbidden target accepted: {targets[0]}")
    make_patch(patch, [REQUIRED[0]])
    log.write_text("")
    result = run_shell(validation["run"], temp, {**stub_env, "PATCH_FILE": str(patch), "ROUTE": "unknown-route"})
    check(result.returncode != 0 and log.read_text() == "", "unknown route reached git")
    for content in ("", "not a unified patch\n"):
        patch.write_text(content)
        log.write_text("")
        result = run_shell(validation["run"], temp, {**stub_env, "PATCH_FILE": str(patch), "ROUTE": ROUTE})
        check(result.returncode != 0 and log.read_text() == "", "empty/targetless patch accepted")

    # Both gates require every regular file. Each of the 18 missing-artifact
    # cases must stop before focused evidence or any staging/git operation.
    for gate_name, source in (("pre-evidence", pre_evidence["run"]), ("pre-staging", publish["run"])):
        for missing in REQUIRED:
            fixture = temp / gate_name / re.sub(r"[^A-Za-z0-9]", "_", missing)
            materialize(fixture, [path for path in REQUIRED if path != missing])
            log.write_text("")
            result = run_shell(source, fixture, {**stub_env, "PATCH_FILE": str(patch), "ROUTE": ROUTE})
            check(result.returncode != 0, f"{gate_name} accepted missing {missing}")
            check(log.read_text() == "", f"{gate_name} executed git with missing {missing}")

    # All-present pre-evidence succeeds; all-present publication stages exactly
    # nine literal paths in order before only stubbed diff/commit/push calls.
    fixture = temp / "all-present"
    materialize(fixture, REQUIRED)
    result = run_shell(pre_evidence["run"], fixture, stub_env)
    check(result.returncode == 0, f"all-present pre-evidence failed: {result.stderr}")
    log.write_text("")
    result = run_shell(publish["run"], fixture, {**stub_env, "PATCH_FILE": str(patch), "ROUTE": ROUTE})
    check(result.returncode == 0, f"all-present publication failed: {result.stderr}")
    staged = [line.removeprefix("add -- ") for line in log.read_text().splitlines() if line.startswith("add -- ")]
    check(staged == REQUIRED, f"staging mismatch: {staged}")

    # Focused and replay commands are dispatched to inert executables only.
    log.write_text("")
    result = run_shell(focused["run"], temp, {**stub_env, "ROUTE": ROUTE})
    check(result.returncode == 0, f"focused dispatch failed: {result.stderr}")
    check(log.read_text().splitlines() == FOCUSED, "focused command order mismatch")
    write_executable(bin_dir / "bash", """#!/bin/bash
printf '%s\\n' "$*" >> "$STUB_LOG"
""")
    log.write_text("")
    result = run_shell(replay["run"], temp, {**stub_env, "ROUTE": ROUTE})
    check(result.returncode == 0, f"replay dispatch failed: {result.stderr}")
    check(log.read_text().splitlines() == ["scripts/runtime_viridian_roadblock_replay.sh"], "replay command mismatch")

target_match = re.search(r"^\s+(phase5-viridian-roadblock:[^\n]+)\)$", validation["run"], re.MULTILINE)
check(target_match is not None, "roadblock allowlist branch missing")
allowed = [entry.removeprefix(f"{ROUTE}:") for entry in target_match.group(1).split("|")]
check(allowed == REQUIRED, "allowlist is not the exact nine paths")
check(no_rom["run"].strip().endswith("env -u POKEPORT_ROM bash scripts/test_all.sh"), "no-ROM suite changed")
check(verified_rom["run"].strip().endswith("bash scripts/test_all.sh"), "verified-ROM suite changed")

print(f"PASS: YAML parsed; {shell_count} Bash blocks passed bash -n")
print("PASS: existing workflow lines preserved; patch/probe selectors and unknown rejection verified")
print("PASS: exact nine-target allowlist; forbidden/empty/targetless/unknown-route rejection verified")
print("PASS: all 9 pre-evidence and all 9 pre-staging missing-artifact cases failed before execution")
print("PASS: exact six focused commands, shared suites, dedicated replay, literal staging, and probe separation verified")
```

## Final evidence

With the same toolchain path and both ROM-related variables unset, the final
commands were:

```bash
python3 /tmp/viridian-roadblock-route-config-harness.py /tmp/firered-roadblock-route-config.8esU8V 72a18e903164f3f2f8532676a94c610a9da241c2
env -u POKEPORT_ROM bash scripts/test_all.sh
lua5.1 scripts/check_repository.lua
git diff --check
git diff --cached --check
```

The harness and no-ROM suite exited 0 with the results above. The first final
checker invocation followed the suite and rejected the task-to-report link
because the new report was not yet tracked: `321 tracked Lua, 374 tracked
Markdown, 1259 local targets`. This was an expected evidence-packaging
interruption, not a product/test failure. It occurred only after all nine
pre-staging negative cases had passed. The report was then marked
intent-to-add, making it visible to the checker; the checker passed with `321
tracked Lua, 375 tracked Markdown, 1259 local targets`.

The first whitespace retry identified one blank line at the report EOF. That
line was removed. The final checker, `git diff --check`, and
`git diff --cached --check` all exited 0 with no whitespace diagnostics.

## Exclusions and handoff

No source, elevation, or design retracing occurred. No implementation artifact,
probe, request, workflow dispatch, private-runner/ROM access, focused gameplay
test, verified-ROM suite, runtime replay, staging, or publication through the
bridge occurred. This configuration does not prove runner readiness, gameplay,
implementation success, or Phase 5/7 completion and supplies no authority for
those actions.

The exact published head requires independent Reviewer verification. Only an
independent `PASS` allows the Orchestrator to reconcile this configuration and
compile a distinct fresh readiness-probe task. A probe proves no gameplay,
consumes no implementation authority, and remains separate from later reviewed
implementation authority.
