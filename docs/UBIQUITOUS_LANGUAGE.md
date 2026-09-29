# Ubiquitous Language

## Handbook structure

| Term | Definition | Avoid |
| --- | --- | --- |
| Runbook | A guide with Prerequisites, numbered steps and Verify, followed once from top to bottom. | tutorial, how-to |
| Reference page | A lookup page of command tables or rule lists, scanned mid-task. | cheatsheet |
| Template | A file a project or server copies once and then owns. | boilerplate |
| Dotfile | A handbook file `install.sh` links live into `$HOME`. | template, config |
| Payload | Everything `install.sh` links into `~/.claude`. | agent config, setup |
| Journey | A README route through runbooks from a start state to a verified result. | path, flow |
| Frozen path | A file path fetched by raw URL from outside the repo, which never moves. | public script |
| Contract | A path something outside the file depends on: a raw URL, an install origin, a settings script path. | link |
