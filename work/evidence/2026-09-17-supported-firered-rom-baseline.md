# Supported FireRed ROM baseline evidence

- Record role: `EVIDENCE`
- Primary information class: `RUNTIME BASELINE`
- Status: `PASS`
- Lifecycle: `CLOSED`
- Authority: confirms availability and baseline compatibility only; it does not
  validate the balance mod or replace independent review
- Supported-ROM identity: FireRed US v1.0 SHA-1
  `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`

## Evidence

On 2026-09-17, the locally configured candidate at the project-adjacent
FireRed source tree hashed to the supported identity above. No ROM bytes were
copied, modified, or committed.

With that path supplied through `POKEPORT_ROM`, `bash scripts/test_all.sh`
passed all 142 test files in ROM mode. This establishes that the supported ROM
and current runtime test harness are available for the separately dispatched
representative balance-validation task after package review. It proves neither
package correctness nor gameplay balance by itself.
