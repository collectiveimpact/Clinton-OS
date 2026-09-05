# Clinton-OS v0.2.0

First Clinton-OS release, forked from Baalda 0.1.47 (upstream commit 8e261b3, Apache 2.0).

- Rebranded to Clinton-OS under docs/BRANDING.md Layer 1. Storage identifiers, the context codename and the com.baalda.context bundle id are unchanged, so an existing Baalda install keeps its vaults and keychain entry.
- Fuse5 design system: near black base, orange accent with ink text, cyan data signal, Poppins.
- Text wordmark replaces the image logo.
- Updater now follows the collectiveimpact/Clinton-OS GitHub releases with a new signing key.
- Deploy kit for AWS ca-central-1 in deploy/aws-ca-central-1, plus the operations console.

- Folder badges now count only the notes that actually need syncing (for example "1/2" for two new files), instead of the folder's whole population ("186/187")
- A fully synced vault shows its synced dots right after connecting, without waiting for a sync run
- Editing while a sync is running no longer re-reads every note title on each change, so the sidebar stays responsive on large vaults
- A file added to a folder that a teammate had moved on the server no longer fails to sync forever ("1 not synced"): the folder is re-created at its old path and the file registers normally
- Empty leftover files of notes deleted on the server are now cleaned up instead of lingering as unsyncable stubs
- After a teammate moves a folder, the emptied old folder is removed on your device instead of coming back for everyone as an empty duplicate
