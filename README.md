# .github

Org-wide **default community health files** for sparkweavers.

## `pull_request_template.md`
The default pull request template. It is automatically applied to every repository
in this organization that does **not** define its own
`.github/pull_request_template.md`. A repo-local template always overrides this one.

Edit the template here to change the default for all repos at once.

## `ISSUE_TEMPLATE/`
The default issue forms, offered in every repository that does not define its own
`.github/ISSUE_TEMPLATE/` directory. They are what the "New issue" button shows in
`sparkweavers/issues`, which is where all issues live.

| Form | Title prefix | Label | Issue type |
| --- | --- | --- | --- |
| New Project | `[Project]: ` | `Project` | Feature |
| Bug Report | `[Bug]: ` | `bug` | Bug |
| New Board Item | `[Board Item]: ` | `task` | Task |
| New Experiment | `[Experiment]: ` | `task` | Task |

Every form adds the new issue to the Sparkweaving Board (`sparkweavers/1`) and sets
the issue type, so a fresh issue arrives with label, type and board membership
already filled in. Status, Iteration or Quarter, and the parent issue still have to
be set by hand.

A "Project" is the top level of the tracking hierarchy: it is scheduled per Quarter
and holds sub-issues. Everything below it is a Board Item, Bug or Experiment,
scheduled per Iteration.

### Do not add per-repo issue templates
A repository that defines its own `.github/ISSUE_TEMPLATE/` shadows this directory
entirely, the same way a repo-local pull request template shadows the one above.
Change the forms here instead.
