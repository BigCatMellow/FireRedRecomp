# Phase 4 variable-power V3 Local Worker Bridge route configuration

- Task: [`P4-VARIABLE-POWER-V3-ROUTE-CONFIG`](../tasks/local-worker-bridge-phase4-variable-power-v3-route-configuration.md).
- Status: worker configuration evidence; independent exact review pending.
- Base: `c435521` (plan merge, PR #67).
- Authority: reviewed [V3 route plan](../tasks/local-worker-bridge-phase4-variable-power-v3-route-plan.md),
  [delta PASS `a2752f4`](../reviews/2026-11-15-variable-power-v3-route-plan-delta-review.md);
  operator approval 2026-11-15 for the `LOCAL_RUNNER_BRIDGE.md` edit.

## Exact configuration

Six insertion hunks in `.github/workflows/local-worker-bridge.yml`, each
placed after the matching `phase4-recoil-if-miss-effect` arm or, for the
pre-evidence step, after the roadblock pre-evidence step:

```text
@@ -136,0 +137,3 @@   selector
@@ -271,0 +275,2 @@   8-path target validation
@@ -316,0 +322,22 @@  pre-evidence step (all 8 regular files)
@@ -439,0 +467,6 @@   focused commands
@@ -566,0 +600,3 @@   literal no-replay echo
@@ -777,0 +814,21 @@  require-all-then-stage publication
```

Proof that the diff is additions only: `git diff --numstat origin/main --
.github/workflows/local-worker-bridge.yml` gives `57 0`, and
`git diff -U0 origin/main -- .github/workflows/local-worker-bridge.yml | grep -c '^-[^-]'`
gives `0`. Every existing route is therefore byte-unchanged. The new selector
prefix `phase4-variable-power-v3-effect` is not a prefix of any existing
selector, and no existing selector is a prefix of it.

`work/coordination/LOCAL_RUNNER_BRIDGE.md` gains one route bullet after the
Magnitude bullet. It is also an insertion only.

## Offline stub validation

Run `python3 -I <scratch>/harness.py .github/workflows/local-worker-bridge.yml
<scratch>/v3pkg.patch <repo>`, where `v3pkg.patch` is `git diff 49d0f45 fbe5b6f`.

- **What it uses:** a temporary directory outside the repository, made with
  `tempfile.mkdtemp` and removed at exit. The tree comes from
  `git archive origin/main`.
- **What it does not use:** GitHub Actions dispatch, the runner, a ROM or LÖVE.
  Each workflow step's `run` script is executed with `bash` and stub
  environment variables. `lua5.1` is a logging stub on `PATH`.
- **Outcome:** exit status 0, 29/29 checks PASS.

Results:

```text
PASS select phase4-variable-power-v3-effect-20261115.patch -> phase4-variable-power-v3-effect
PASS select phase4-variable-power-v3-effect-route-20261115.probe -> phase4-variable-power-v3-effect
PASS unknown phase4-variable-power-v2-effect-x.patch rejected
PASS unknown phase4-variable-power-v3.patch rejected
PASS unknown variable-power-v3-effect.patch rejected
PASS real 8-path package passes target validation + apply --check
PASS forbidden target BattleSceneController.lua rejected
PASS forbidden target main.lua rejected
PASS empty patch rejected
PASS pre-evidence step gated on route
PASS pre-evidence: all 8 present -> pass
PASS pre-evidence missing <each of 8 paths> -> fail        (8 checks)
PASS publish missing <each of 8 paths> -> fail before staging  (8 checks)
PASS focused arm runs exactly the 4 commands in order
PASS replay arm prints literal no-replay text only
OVERALL PASS
```

The harness is not kept as a repository artifact. Its complete source:

```python
# Offline stub harness for phase4-variable-power-v3-effect route. No network, no ROM, no runner.
import yaml, subprocess, sys, os, tempfile, shutil
WF, PATCH, REPO = sys.argv[1], sys.argv[2], sys.argv[3]
R='phase4-variable-power-v3-effect'
PATHS=['src/core/BattleEngine.lua','tests/battle_variable_power_v3_test.lua','tests/phase4_move_effect_inventory_test.lua','tests/phase4_variable_power_v3_effect_rom_test.lua','work/reports/phase4-move-effect-inventory.md','work/reviews/2026-10-28-variable-power-v3-implementation-review.md','work/reviews/2026-10-30-variable-power-v3-final-head-review.md','work/tasks/phase4-variable-power-v3.md']
steps={s['name']:s for j in yaml.safe_load(open(WF))['jobs'].values() for s in j['steps'] if 'name' in s}
def run(name, env, cwd):
    out=tempfile.mktemp(); e=dict(os.environ, GITHUB_OUTPUT=out, **env)
    p=subprocess.run(['bash','-c',steps[name]['run']],env=e,cwd=cwd,capture_output=True,text=True)
    o=open(out).read() if os.path.exists(out) else ''
    return p.returncode, p.stdout+p.stderr, o
ok=True
def check(label, cond):
    global ok; ok&=cond; print(('PASS ' if cond else 'FAIL ')+label)
tmp=tempfile.mkdtemp(prefix='v3route-')
# selector
for f,exp in [(f'{R}-20261115.patch',R),(f'{R}-route-20261115.probe',R)]:
    rc,_,o=run('Select explicit task route',{'REQUEST_FILE':'work/local-runner/x/'+f},tmp); check(f'select {f} -> {R}', rc==0 and f'route={R}' in o)
for f in ['phase4-variable-power-v2-effect-x.patch','phase4-variable-power-v3.patch','variable-power-v3-effect.patch']:
    rc,_,o=run('Select explicit task route',{'REQUEST_FILE':f},tmp); check(f'unknown {f} rejected', rc!=0)
# target validation on a clean origin/main tree
tree=os.path.join(tmp,'tree'); subprocess.run(f'git -C {REPO} archive origin/main | tar -x -C {tmp} --one-top-level=tree',shell=True,check=True)
subprocess.run('git init -q && git add -A && git -c user.name=h -c user.email=h@h commit -qm base',shell=True,cwd=tree,check=True)
rc,out,_=run('Validate bounded patch targets',{'PATCH_FILE':PATCH,'ROUTE':R},tree); check('real 8-path package passes target validation + apply --check', rc==0)
bad=os.path.join(tmp,'bad.patch')
open(bad,'w').write('--- a/src/core/BattleSceneController.lua\n+++ b/src/core/BattleSceneController.lua\n@@ -1 +1 @@\n-x\n+y\n')
rc,out,_=run('Validate bounded patch targets',{'PATCH_FILE':bad,'ROUTE':R},tree); check('forbidden target BattleSceneController.lua rejected', rc!=0 and 'not authorized' in out)
bad2=os.path.join(tmp,'bad2.patch'); open(bad2,'w').write('--- a/main.lua\n+++ b/main.lua\n@@ -1 +1 @@\n-x\n+y\n')
rc,out,_=run('Validate bounded patch targets',{'PATCH_FILE':bad2,'ROUTE':R},tree); check('forbidden target main.lua rejected', rc!=0 and 'not authorized' in out)
empty=os.path.join(tmp,'empty.patch'); open(empty,'w').write('')
rc,_,_=run('Validate bounded patch targets',{'PATCH_FILE':empty,'ROUTE':R},tree); check('empty patch rejected', rc!=0)
# apply then pre-evidence artifact check
subprocess.run(['git','apply',PATCH],cwd=tree,check=True)
V='Verify variable-power V3 artifacts before evidence'
check('pre-evidence step gated on route', R in steps[V]['if'] and "mode == 'patch'" in steps[V]['if'])
rc,_,_=run(V,{},tree); check('pre-evidence: all 8 present -> pass', rc==0)
for p in PATHS:
    fp=os.path.join(tree,p); b=fp+'.bak'; os.rename(fp,b)
    rc,out,_=run(V,{},tree); check(f'pre-evidence missing {p} -> fail', rc!=0 and p in out)
    rc2,out2,_=run('Publish verified bounded implementation',{'PATCH_FILE':PATCH,'ROUTE':R},tree)
    check(f'publish missing {p} -> fail before staging', rc2!=0 and 'before staging' in out2)
    os.rename(b,fp)
# focused + replay wiring via stub lua/bash on PATH
stub=os.path.join(tmp,'bin'); os.makedirs(stub)
for n in ['lua5.1','bash_replay']: pass
open(os.path.join(stub,'lua5.1'),'w').write('#!/bin/sh\necho "LUA $*" >> "$STUBLOG"\n'); os.chmod(os.path.join(stub,'lua5.1'),0o755)
log=os.path.join(tmp,'log'); open(log,'w').close()
rc,out,_=run('Run task-focused test',{'ROUTE':R,'PATH':stub+':'+os.environ['PATH'],'STUBLOG':log},tree)
got=open(log).read().splitlines()
exp=['LUA tests/battle_engine_test.lua','LUA tests/battle_variable_power_v3_test.lua','LUA tests/phase4_move_effect_inventory_test.lua','LUA tests/phase4_variable_power_v3_effect_rom_test.lua']
check('focused arm runs exactly the 4 commands in order', rc==0 and got==exp)
rc,out,_=run('Run task runtime replay',{'ROUTE':R,'POKEPORT_ROM':''},tree)
check('replay arm prints literal no-replay text only', rc==0 and out.strip()=='No runtime replay is authorized: the accepted V3 design specifies none; focused and verified-ROM suite results are the evidence.')
print('OVERALL', 'PASS' if ok else 'FAIL'); shutil.rmtree(tmp); sys.exit(0 if ok else 1)
```

## Checks (2026-11-15, at this revision)

```text
python3 -c "import yaml;yaml.safe_load(open('.github/workflows/local-worker-bridge.yml'))"  -> OK
lua5.1 scripts/check_repository.lua  -> PASS
git diff --check origin/main         -> clean
env -u POKEPORT_ROM -u POKEPORT_RUNTIME_REPLAY bash scripts/test_all.sh
  -> PASS: 205 test files (no-ROM mode; ROM-dependent checks skip cleanly)
```

## Exclusions

This configuration creates no probe or request and touches no package path.
It edits no `STATE.json`, `HANDOFF.md` or `TASK_REGISTER.md`, matching
`57d6b05`. It does not change runner, ROM or SHA policy, or any existing
route. It proves no runner readiness, gameplay or V3 acceptance. The
non-skipped verified-ROM evidence comes only at gate 6, and live LÖVE
observation is never claimed.
