# Design: Staged-files auditor

**Change:** 029-staged-files-auditor
**Created:** 2026-08-01

## Two layers, and the second one is optional

**Layer 1 — `specclaw-check-staged`.** Deterministic, fast, no model. It classifies every changed
path into four buckets and exits non-zero on a BLOCK. **This layer alone catches every failure that
was actually reported** — a missing `spec.md`, a swept-in `.session-id.rotated-7` — at zero token
cost, which is why it is the layer `--strict` can be trusted with in CI.

**Layer 2 — `staged-files-auditor`.** A model seat for the one question a script cannot answer: is
this undeclared file a legitimate ripple (a barrel export updated for a new module) or scope creep?
It is spawned **only when there is something to judge** — a non-empty `required-missing` or
`suspicious`, or more than `pr.audit_undeclared_threshold` undeclared paths — because a reviewer
convened over a clean file list is a bill with no finding attached.

This mirrors `code-reviewer` exactly: same report shape, same verdict vocabulary, same config gate.
A reviewer for *content* already existed; this is the reviewer for *file set*.

## `undeclared` is a WARN, and that is a decision about false positives

A gate that blocks a correct PR is worse than the silent failure it replaces, because the silent
failure at least lets work ship. `tasks.md` file lists are a **scope signal, not a contract** — tasks
under-declare routinely, and a barrel export or a lockfile beside a real dependency change is a
legitimate ripple.

So `undeclared` never exits non-zero on its own. `--strict` exists for a CI caller that wants no
judgement calls at all, and it is opt-in.

`required-missing` and `suspicious` are the only default BLOCK buckets, and they are the two with
essentially no false-positive surface: a mandatory artifact is either in the branch diff or it is
not, and `.session-id.rotated-7` is never intentional.

## Layer 3 is the actual fix, and it is mostly a prohibition

A gate is worthless if `gh pr create` can still be hand-rolled — every guarantee in `specclaw-pr` is
unreachable when the PR is created by hand. The proposal assumed `specclaw-build` created PRs. **It
does not**: there is no `gh pr create` in it and its finalize summary names no PR. So the fix is a
documented prohibition plus a test that no `pr create` reappears in build, rather than a removal.

What *is* real code is the loop's `git add -A` (`specclaw-loop:1016`), which takes whatever is in the
tree. It becomes:

```
git add -- <change dir>            the artifacts, always
git add -- <paths declared in tasks.md>
git add -u                          tracked modifications only
```

and **every remaining path is named in the escalation note** as left in the working tree. That
preserves the thing escalation exists for — work in progress on tracked files — without committing
the filesystem. With an unparseable `tasks.md` the fallback is the same, not `-A`: losing an
untracked scratch file is recoverable, and a PR full of junk on a branch somebody merges is not.

## Test plan

`tests/run-staged-files-tests.sh` builds a real git repo per case: the missing artifact, the clean
branch, the undeclared ripple under both default and `--strict`, the junk sweep, both escape
hatches, the change-dir rule, the size-aware `design.md` rule, `--json`'s shape, exit-code
separation, the loop's scoped add against an untracked junk file, and the no-PR-in-build assertion.
