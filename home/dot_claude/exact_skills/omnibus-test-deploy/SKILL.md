---
name: omnibus-test-deploy
description: Deploy an Omnibus branch or PR to omnibus-test.sloan.cloud (the `applications` VM, port 3006) against a fresh copy of the prod database, replacing whatever build is there now. Use whenever the user asks to deploy, put up, or test a branch/PR "on omnibus-test", "on the test server", "against a prod copy", or to refresh omnibus-test with a new build or new prod data — even if they only say "test this on the server". Not for local dev servers (that's ui-validate) or for changing the home-lab repo.
---

# Deploy a build to omnibus-test

omnibus-test.sloan.cloud always serves **exactly one** Omnibus: the last build deployed, running on a copy of prod. Deploying means replacing that build. Nothing is torn down when testing finishes; the next deploy is what removes the old one. So a deploy is: tear down the previous build, build the new one, copy prod, start it, check it, and leave it running.

Hosts (ssh aliases, always `ssh -o BatchMode=yes`):

- `applications`: the VM. Docker; port `3006` is what `omnibus-test.sloan.cloud` proxies to. The NAS library is at `/mnt/nas/media/books/{ebooks,audiobooks}`.
- `omnibus`: the prod Pi. Its data is `~/config` (`omnibus.db`, `covers/`, `journal-images/`). **Read only, ever.** Nothing in this skill writes to it except a temp backup file in `/tmp` that is deleted after.

Leave `~/Repos/home-lab` alone unless the user asks: its notes may describe the VM differently, and the user keeps them as they are.

## 1. Find what's running now

```bash
ssh -o BatchMode=yes applications 'docker ps --format "{{.Names}} {{.Image}} {{.Ports}}" | grep -i omnibus; docker images --format "{{.Repository}}:{{.Tag}}" | grep -i "^omnibus"'
```

Note the container on `:3006`, its compose directory (`docker inspect -f '{{index .Config.Labels "com.docker.compose.project.working_dir"}}' <name>`), and its image. Anything else omnibus-shaped (an old `omnibus-pr`, `omnibus-main`, a stray watchtower) is a leftover to remove in §4 too. `~/omnibus-snapshots` is the user's and stays.

## 2. Build the new image on the VM

The VM builds from a `git archive`, which has no `.git`, so stamp the commit on the image or nobody can later tell what's deployed:

```bash
sha=$(git -C <worktree> rev-parse HEAD); tag=omnibus:pr-<n>   # or omnibus:<branch-slug>
git -C <worktree> archive --format=tar HEAD | ssh -o BatchMode=yes applications \
  "rm -rf ~/omnibus-test-src && mkdir -p ~/omnibus-test-src && tar -x -C ~/omnibus-test-src && cd ~/omnibus-test-src && \
   docker build --label org.opencontainers.image.revision=$sha -t $tag . > ~/omnibus-test-build.log 2>&1; echo build=\$?"
```

The build takes many minutes: run it in the background and wait for the notification. A failed build changes nothing that's live, so stop and report the log tail.

## 3. Copy prod

Take an online backup on the Pi (safe while prod runs), stream it with covers and journal images straight to the VM, then delete the Pi's temp file:

```bash
ssh -o BatchMode=yes omnibus 'rm -f /tmp/omnibus-prodcopy.db && sqlite3 ~/config/omnibus.db ".backup /tmp/omnibus-prodcopy.db"'
ssh -o BatchMode=yes omnibus 'tar -C /tmp -cf - omnibus-prodcopy.db -C ~/config covers journal-images' \
  | ssh -o BatchMode=yes applications 'rm -rf ~/omnibus-test-next && mkdir -p ~/omnibus-test-next/config ~/omnibus-test-next/cache && tar -xf - -C ~/omnibus-test-next/config && mv ~/omnibus-test-next/config/omnibus-prodcopy.db ~/omnibus-test-next/config/omnibus.db'
ssh -o BatchMode=yes omnibus 'rm -f /tmp/omnibus-prodcopy.db'
```

Check the copy: `pragma integrity_check` is `ok`, and `select count(*), sum(is_missing_files) from books` matches the same query run read-only on the Pi.

**QA account.** The release image ignores `OMNIBUS_DEV_SEED_USER`, and a fresh prod copy has no test user. Create a fresh `omnibus-qa` admin in the new copy before it starts, so no public window opens. Don't carry `koreader-qa` (or any other existing account) forward: it belongs to KOReader testing. The password lives only in `~/.config/omnibus-test/qa-credentials` (mode 0600), never in the transcript; reuse it when the file exists, otherwise generate one there:

```bash
umask 077; f=~/.config/omnibus-test/qa-credentials; mkdir -p "$(dirname "$f")"
[ -f "$f" ] || printf 'url=https://omnibus-test.sloan.cloud\nusername=omnibus-qa\npassword=%s\n' \
  "$(head -c 18 /dev/urandom | base64 | tr -d '/+=' | head -c 24)" > "$f"
. <(grep '^password=' "$f")
hash=$(printf '%s' "$password" | argon2 "$(head -c 12 /dev/urandom | base64 | tr -d '/+=')" -id -k 19456 -t 2 -p 1 -e)
# The SQL goes over stdin: inside a double-quoted remote command, the shell expands `$argon2id$v` and login 500s.
printf "insert into users (username, password_hash, is_admin, can_upload, can_edit, can_download) values ('omnibus-qa', '%s', 1, 1, 1, 1);\n" "$hash" \
  | ssh -o BatchMode=yes applications 'sqlite3 ~/omnibus-test-next/config/omnibus.db'
```

Never turn on `registration_enabled`: omnibus-test is public, so open registration is open to everyone. Once it's up (§5), check `POST /api/auth/login` with that file's credentials answers `200`.

To drive the UI, log in with curl, set the `__Host-omnibus_session` cookie in an **incognito** preview tab (`document.cookie = "__Host-omnibus_session=<token>; Secure; Path=/; SameSite=Lax"`), and `POST /api/auth/logout` with the same cookie when done, since the token passes through the transcript.

## 4. Swap: tear down the old build, start the new one

Write `~/omnibus-test-next/docker-compose.yml` (container `omnibus-test`, image the new tag, `restart: unless-stopped`, port `3006:3000`, `./config:/config`, `./cache:/cache`, the NAS paths mounted **`:ro`**, `PUID`/`PGID` `1000`, `OMNIBUS_PUBLIC_ORIGIN=https://omnibus-test.sloan.cloud,http://192.168.1.201:3006,http://localhost:3006`, `OMNIBUS_SECURE_COOKIES=1`, `OMNIBUS_TRUST_FORWARDED_FOR=1`, `EBOOK_LIBRARY_PATH=/books`, `AUDIOBOOK_LIBRARY_PATH=/audiobooks`, `OMNIBUS_REACT=1` so `/react/` serves the React client instead of falling through to Dioxus's "Not found"), with a header comment naming the branch, PR, commit and the date of the prod copy. Then, in one ssh call:

1. `docker compose down` in the old compose directory, and remove its directory, its image, and every leftover from §1.
2. `mv ~/omnibus-test-next ~/omnibus-test && cd ~/omnibus-test && docker compose up -d`.
3. `docker builder prune -af` and `docker image prune -f`, so old layers don't fill the disk.

Old builds are removed every time: only the new image should be left.

## 5. Check, and leave it running

- Wait for `docker inspect -f '{{.State.Health.Status}}' omnibus-test` to be `healthy`, and for `curl -s https://omnibus-test.sloan.cloud/api/_health` to answer `200`.
- `docker image inspect <tag> -f '{{index .Config.Labels "org.opencontainers.image.revision"}}'` equals the commit you meant to deploy.
- Report: the URL, the commit, the prod-copy time, the book and missing counts, and free disk (`df -h /`).

Then stop. **Don't tear anything down after testing**, whatever the tests found: the build stays up until the next deploy replaces it.
