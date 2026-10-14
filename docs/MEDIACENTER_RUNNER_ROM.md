# MediaCenter self-hosted runner: private FireRed ROM configuration

This is operator-side setup documentation, **not** an instruction to change the supported-ROM policy or rerun a previously exhausted probe. The workflow in `.github/workflows/local-worker-bridge.yml` already reads `POKEPORT_ROM` in its `Locate and verify private FireRed ROM` step, then verifies FireRed US v1.0 SHA-1 before any ROM-backed work. No workflow change is necessary just to configure the path.

## Diagnose without publishing the path

On MediaCenter, identify the systemd runner service and the account/environment it uses. Do not paste private home paths or ROM contents into issues, pull requests, logs or chat. The unit name varies by installation.

```bash
systemctl list-units 'actions.runner*' --all
```

Read the unit metadata locally to identify its service account, and check whether that account can access an existing legally obtained ROM. If the runner is a **user service** rather than system service, use `systemctl --user` and the corresponding user manager. This guide does not assume which setup is installed.

## Persistent configuration

If the ROM already exists on MediaCenter and the service account can read it, configure `POKEPORT_ROM` as an **absolute filename** in the runner **service environment**. Prefer an operator-managed, access-restricted systemd environment file or drop-in appropriate for the actual unit. Do not commit that environment file, embed the absolute path in this repository, or put the ROM in GitHub.

For a *system* service, an administrator can use `sudo systemctl edit <actual-service-unit>` to set an environment-file reference in the unit override:

```ini
[Service]
EnvironmentFile=/etc/firered-runner.env
```

The locally created `/etc/firered-runner.env` should contain one line of the form `POKEPORT_ROM=/absolute/private/path/to/owned-rom.gba` (substitute the actual path locally; this text is only a placeholder), with file permissions restricting readers. Because `EnvironmentFile` uses systemd parsing, quote/escape paths when needed; do not use shell variable expansion. Avoid sending its contents anywhere. This example is for a system service; adapt to a user service if relevant.

After changing service configuration, reload systemd and restart **only the runner service** in a safe maintenance window, then check that it returned online. Existing or queued jobs can be interrupted by a restart; coordinate first. Do not blindly restart a runner with active work.

## What proves the repair

A newly authorized, independently reviewed readiness check should prove: the correct trusted runner/check-out/route, Lua 5.1, private ROM file existence/readability, and the existing exact supported SHA-1. It must not print the path, expose ROM bytes, publish derived assets, or skip the hash. Public no-ROM CI does **not** prove this private check. Do not rerun exhausted `RUNNER-LUA5-RECOVERY`, Restore HP, or P5 probe jobs under old authority; separately bound and independently review any successor execution.

## Operator checklist

- Confirm the *service account* and existing ROM file privately on MediaCenter.
- Persist `POKEPORT_ROM` in the correct service environment, keeping the file private.
- Arrange a safe runner-service restart and confirm it is online.
- Obtain a separate scoped authorization and independent review for one new private readiness check.
- Only after readiness passes, separately authorize the bounded P4/P5 jobs; do not infer gameplay evidence from infrastructure readiness.
