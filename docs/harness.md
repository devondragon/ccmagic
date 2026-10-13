# UI harness (`ccm-harness`)

A repository opts in by committing `.ccmagic/harness.compose.yml`: a Compose file for the app and what it needs, plus a top-level `x-ccm-harness` key that tells ccmagic how to use it. Without the file, auto-ticket lists visual criteria on the run summary's UAT checklist.

    services:
      web: { build: { context: .., dockerfile: .ccmagic/harness.Dockerfile } }
    x-ccm-harness:
      version: 1
      app:
        service: web            # the service the runner talks to
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

The `app.service` name becomes a bare hostname in the browser's URL (`http://web:9030`), and Chromium forces HTTPS for a bare name that is a preloaded top-level domain, such as `app` or `dev`. `ccm-harness check` refuses those names (rule `service-name`); name the service `web` or `<name>-web`.

Paths in `x-ccm-harness` are relative to the repository root; paths in `services` follow Compose (relative to `.ccmagic/`). The runner image needs `node` (18 or newer). `ccm-harness` sets `APP_BASE_URL` (`http://<service>:<port>`) and `OUT_DIR` (`/out`) in the runner.

Rules (`ccm-harness check`): every value literal in the merged model, included and extended files too (no `${...}` or `$VAR`, however written; `$$` is a literal `$`; a comment is ignored), no `env_file`, no bare `environment` key, no `privileged`, `cap_add`, `devices`, `restart`, `network_mode: host`, `pid: host`, no published port, no bind mount when `CCM_HARNESS_NO_BIND_MOUNTS=1`, and a Playwright runner image equal to the workdir's committed lockfile.

`ccm-harness` runs Docker and Compose with an emptied environment: only `PATH`, `HOME`, `DOCKER_HOST`, `DOCKER_CONFIG`, `TMPDIR`, the proxy variables (`HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`, `ALL_PROXY`, and their lowercase forms), and the CA bundle paths (`SSL_CERT_FILE`, `SSL_CERT_DIR`) pass through. The last two groups let image builds reach a registry from a sandboxed session whose network goes through a proxy; none of them hold secrets.

`ccm-harness` needs Docker Compose 2.30 or newer. Its `check` tests were run on Compose 2.30.0, 2.38.2, and 5.6.0; older versions are untested.

Commands: `check`, `up` (with `--prepare`, `--attach RUN`, `--wait [SECONDS]` for runs longer than one tool call), `seed`, `shoot TICKET SCRIPT`, `down`, `sweep [HOURS]`, `evidence TICKET HEAD PNG...`. Each prints one JSON object; the script's header has the details.
