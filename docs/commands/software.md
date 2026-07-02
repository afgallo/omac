# omac software

Install curated software groups (brew + mise).

```
omac software install [group]   install all groups, or one
omac software list              list groups and their status
```

Groups: `ai`, `shell`, `ides`, `tuis`, `guis`, `fonts`. Each group is a Brewfile under
`software/groups/`; language runtimes come from `software/runtimes.manifest` via `mise`. See
[Software](../software/index.md) for what each group contains and the opt-in / opt-out model.
