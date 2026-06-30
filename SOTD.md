# Starring SOTD Messages with wacli

Commands to find and star all messages containing the keyword `SOTD` in a WhatsApp group, using [wacli](../wacli).

## Prerequisites

Build the binary first:

```bash
cd ../wacli
make build
```

The `messages star` command requires a local build — it is not yet in an upstream release.

---

## Step 1 — Authenticate (first time only)

```bash
wacli auth
```

Scan the QR code. This links the device and bootstraps an initial message sync automatically.

---

## Step 2 — Find the group JID

```bash
wacli groups list --query "SOTD"
```

The JID appears in the output and looks like `120363XXXXXXXXXX@g.us`. Copy it — you will use it in every subsequent command.

---

## Step 3 — Pull message history

For recent messages a regular sync is enough:

```bash
wacli sync
```

For older messages not yet on this device, run backfill. Each call fetches another batch from your primary phone:

```bash
wacli history backfill --chat 120363XXXXXXXXXX@g.us
```

Re-run backfill until the reported message count stops growing.

---

## Step 4 — Search for SOTD messages

```bash
wacli messages search "SOTD" --chat 120363XXXXXXXXXX@g.us --limit 500 --json
```

Increase `--limit` if the group has more than 500 SOTD messages.

---

## Step 5 — Star the messages

Star a single message:

```bash
wacli messages star --chat 120363XXXXXXXXXX@g.us --id <msg_id>
```

Or star all results from the search in one pipeline:

```bash
wacli messages search "SOTD" --chat 120363XXXXXXXXXX@g.us --limit 500 --json \
  | jq -r '.messages[].msg_id' \
  | xargs -I{} wacli messages star --chat 120363XXXXXXXXXX@g.us --id {}
```

---

## Notes

- `wacli sync` only pulls messages the linked device has already received. On a freshly linked device, older history arrives gradually — run `history backfill` several times if needed.
- To unstar a message, add `--unstar` to the `messages star` command.
- Replace `120363XXXXXXXXXX@g.us` with the actual JID from Step 2 throughout.
