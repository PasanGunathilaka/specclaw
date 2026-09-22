# Status: {{title}}

**Change:** {{change_name}}
**Started:** {{date}}
**Last Updated:** {{updated}}

## Progress

| Phase | Status | Notes |
|-------|--------|-------|
| Proposal | {{proposal_status}} | {{proposal_notes}} |
| Spec | {{spec_status}} | {{spec_notes}} |
| Design | {{design_status}} | {{design_notes}} |
| Tasks | {{tasks_status}} | {{tasks_notes}} |
| Build | {{build_status}} | {{build_notes}} |
| Verify | {{verify_status}} | {{verify_notes}} |

## Task Progress

**Completed:** {{completed}} / {{total}}
**Failed:** {{failed}}
**Deferred:** {{deferred}}

{{task_details}}

## Agent Runs

| Task | Agent | Model | Status | Duration | Review |
|------|-------|-------|--------|----------|--------|
{{agent_runs}}

<!--
  Review column (build.task_review):
    —            the gate was off for this build
    PASS         the task-scoped reviewer raised nothing
    WARN(n)      n non-blocking findings, recorded in reviews/<task>.md
    BLOCK→retry  the task was marked failed and re-dispatched

  A BLOCK shares the task's normal retry budget rather than getting one of its
  own: a task that fails review and a task that fails its tests are both "this
  task is not done", and two counters would let a task alternate between them
  and exhaust neither.
-->

## Issues

{{issues}}
