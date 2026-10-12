# UI harness (`ccm-harness`)

A repository opts in by committing `.ccmagic/harness.compose.yml`: a Compose file for the app and what it needs, plus a top-level `x-ccm-harness` key that tells ccmagic how to use it. Without the file, auto-ticket lists visual criteria on the run summary's UAT checklist.

    services:
      app: { build: { context: .., dockerfile: .ccmagic/harness.Dockerfile } }
    x-ccm-harness:
      version: 1
      app:
        service: app            # the service the runner talks to
        port: 9030              # its container port
        health: /actuator/health/readiness
        health_timeout_seconds: 900
      runner:
        image: mcr.microsoft.com/playwright:v1.61.1-noble   # must equal the locked @playwright/test
        workdir: e2e            # copied into the runner (regular files only)
        setup: [npm, ci]        # optional
      seed:                     # optional
        sql: { service: pgvector, file: .ccmagic/harness-seed.sql, user: aimail, database: aimail }
        command: [node, harness/seed.js]   # runs in the runner, from the workdir
      evidence: auto            # auto (push on a private repository) | push | off
      env:                      # literal values set in the runner
        DEV_TEST_EMAIL: seed@test.dev

Paths in `x-ccm-harness` are relative to the repository root; paths in `services` follow Compose (relative to `.ccmagic/`). The runner image needs `node` (18 or newer). `ccm-harness` sets `APP_BASE_URL` (`http://<service>:<port>`) and `OUT_DIR` (`/out`) in the runner.

Rules (`ccm-harness check`): every value literal in the merged model, included and extended files too (no `${...}` or `$VAR`, however written; `$$` is a literal `$`; a comment is ignored), no `env_file`, no bare `environment` key, no `privileged`, `cap_add`, `devices`, `restart`, `network_mode: host`, `pid: host`, no published port, no bind mount when `CCM_HARNESS_NO_BIND_MOUNTS=1`, and a Playwright runner image equal to the workdir's committed lockfile.

Commands: `check`, `up` (with `--prepare`, `--attach RUN`, `--wait [SECONDS]` for runs longer than one tool call), `seed`, `shoot TICKET SCRIPT`, `down`, `sweep [HOURS]`, `evidence TICKET HEAD PNG...`. Each prints one JSON object; the script's header has the details.
