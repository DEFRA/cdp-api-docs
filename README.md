# cdp-api-docs

Serves the CDP API docs site. On start-up and then on a timer, it copies the api docs S3 bucket to local disk and
serves it with nginx. The bucket is the complete static site; tenant builds publish their docs into it under
`api/<service>/<version>/`.

- [How it works](#how-it-works)
- [Configuration](#configuration)
- [Logs](#logs)
- [Local development](#local-development)
  - [Serve a local folder](#serve-a-local-folder)
  - [Sync from local S3](#sync-from-local-s3)
  - [Sync from the real bucket](#sync-from-the-real-bucket)
- [Licence](#licence)

## How it works

1. `scripts/entrypoint.sh` runs one sync before nginx starts. If it fails (no bucket, no access) the container exits.
2. `scripts/sync.sh loop` then re-syncs every `SYNC_INTERVAL_SECONDS` in the background.
3. Each sync goes into `/srv/staging`. When something changed, it is hard-linked into a new folder under
   `/srv/releases` and the `/srv/site` symlink is switched to it in one step, so nginx never serves a half-finished
   sync. The previous release is kept; older ones are deleted.
4. If a later sync fails, the error is logged and the last good copy keeps being served.

nginx (`nginx.conf.template`) listens on `PORT`, answers `/health` for the platform healthcheck, serves `index.html` for
folder URLs and redirects `/folder` to `/folder/` with a relative `Location`.

## Configuration

| Variable                | Default | Description                                                    |
|-------------------------|---------|----------------------------------------------------------------|
| `BUCKET`                |         | Bucket holding the docs site. Required unless sync is disabled |
| `SYNC_INTERVAL_SECONDS` | `60`    | Seconds between syncs                                          |
| `SYNC_ENABLED`          | `true`  | `false` serves whatever is already in `/srv/site`              |
| `PORT`                  | `8085`  | Port nginx listens on                                          |
| `AWS_ENDPOINT_URL`      |         | S3 endpoint override, for local S3                             |

Deployed values live in [cdp-app-config](https://github.com/DEFRA/cdp-app-config/tree/main/services/cdp-api-docs).
The service's role needs `s3:ListBucket` and `s3:GetObject` on the bucket.

## Logs

Sync and access logs go to stdout as ECS JSON. Health checks aren't logged. To see what OpenSearch would store:

```bash
docker compose logs --no-log-prefix cdp-api-docs | npx @defra/cdp-log-pipeline --explain
```

## Local development

Needs Docker.

### Serve a local folder

`test-site/` holds one fake service. Serve it without S3:

```bash
docker build -t cdp-api-docs .
docker run --rm -p 8085:8085 -v "$PWD/test-site:/srv/site:ro" -e SYNC_ENABLED=false cdp-api-docs
```

Then open http://localhost:8085/api/test-service/latest/ and check `curl -i localhost:8085/health`.

### Sync from local S3

`compose.yml` starts [Floci](https://github.com/hectorvent/floci) as local S3, creates `cdp-local-api-docs`, uploads
`test-site/` into it, and runs the service with a 10 second sync interval:

```bash
docker compose up --build
```

Change the bucket and watch the change appear within one interval:

```bash
printf '<h1>v2</h1>' | docker compose exec -T floci aws s3 cp - s3://cdp-local-api-docs/api/test-service/0.2.0/index.html
curl localhost:8085/api/test-service/0.2.0/
```

### Sync from the real bucket

With credentials for the management account (e.g. `aws sso login`):

```bash
docker run --rm -p 8085:8085 \
  -e BUCKET=cdp-management-api-docs \
  -e AWS_REGION=eu-west-2 -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_SESSION_TOKEN \
  cdp-api-docs
```

Then open http://localhost:8085/api/cdp-example-node-backend/latest/.

## Licence

THIS INFORMATION IS LICENSED UNDER THE CONDITIONS OF THE OPEN GOVERNMENT LICENCE found at:

<http://www.nationalarchives.gov.uk/doc/open-government-licence/version/3>

The following attribution statement MUST be cited in your products and applications when using this information.

> Contains public sector information licensed under the Open Government license v3

### About the licence

The Open Government Licence (OGL) was developed by the Controller of Her Majesty's Stationery Office (HMSO) to enable
information providers in the public sector to license the use and re-use of their information under a common open
licence.

It is designed to encourage use and re-use of information freely and flexibly, with only a few conditions.
