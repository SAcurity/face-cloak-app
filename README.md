# Face Cloak App
Web Application for Face Cloak, a privacy controls for detected faces in images.

This is the **server-rendered web frontend**. It is a thin presentation layer over [SAcurity/face-cloak-api](https://github.com/SAcurity/face-cloak-api); the API holds the database and enforces all authorization. The app is responsible for sessions, login flow, form validation, signed client requests, Google OAuth handoff, and rendering Slim templates.


## Install

Install this application by cloning the relevant branch and using Bundler to install the specified gems:

```shell
bundle install
```

Copy `config/secrets-example.yml` to `config/secrets.yml` and fill in the values for the environment you are running:

```shell
cp config/secrets-example.yml config/secrets.yml
bundle exec rake generate:session_secret
bundle exec rake newkey:msg
bundle exec rake newkey:signing
# paste SESSION_SECRET, MSG_KEY, and SIGNING_KEY into config/secrets.yml
# give the printed VERIFY_KEY to the API
```

`SESSION_SECRET` is kept in the secrets template and can be generated with the command above. The current runtime session configuration uses server-side Rack sessions; encrypted sensitive session values use `MSG_KEY`.

Local development defaults to:

- `API_URL=http://localhost:3000/api/v1`
- `APP_URL=http://localhost:9292`
- `GOOGLE_REDIRECT_URI=http://localhost:9292/auth/sso/google/callback`
- `GOOGLE_OAUTH_SCOPE=openid email profile`
- `REDISCLOUD_URL=redis://localhost:6379/0`

Set `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` from the Google OAuth console if you want to exercise the Google SSO flow locally.

## Test

Run the specs:

```shell
bundle exec rake spec
```

Service specs use WebMock, so they do not require a live API.

## Execute

The web app expects the Face Cloak API to be running at the `API_URL` configured in `config/secrets.yml`; the development default is `http://localhost:3000/api/v1`. From a checkout of [SAcurity/face-cloak-api](https://github.com/SAcurity/face-cloak-api), start the API first:

```shell
bundle exec rake run:dev
```

Then, from this repo, launch the web app on port 9292:

```shell
bundle exec rake run:dev
```

Visit `http://localhost:9292/` in your browser.

## Secure Sessions

The App stores sensitive session values through `FaceCloak::SecureSession`, which encrypts each value with `FaceCloak::SecureMessage` and a NaCl key from `MSG_KEY`.

Development and test use Rack's in-memory session pool. Production uses `Rack::Session::Redis` with `REDISCLOUD_URL` or `REDIS_URL`, secure cookies, `httponly`, and `same_site: :lax`.

Signed client requests use `SIGNING_KEY` in this app. The matching `VERIFY_KEY` must be configured in the API.

## Deploy to Heroku

Deploy the App separately from the API. This project is intended to be connected to Heroku's GitHub deployment flow, so pushing to the configured GitHub branch triggers the Heroku deploy.

Create the Heroku app once, then connect it to this GitHub repository in the Heroku dashboard:

```shell
heroku create <face-cloak-app-name>
heroku addons:create rediscloud:<plan> --app <face-cloak-app-name>
```

Configure the App's Heroku config vars:

```shell
heroku config:set API_URL=https://<face-cloak-api-name>.herokuapp.com/api/v1 \
  APP_URL=https://<face-cloak-app-name>.herokuapp.com \
  GOOGLE_CLIENT_ID=<google-client-id> \
  GOOGLE_CLIENT_SECRET=<google-client-secret> \
  GOOGLE_REDIRECT_URI=https://<face-cloak-app-name>.herokuapp.com/auth/sso/google/callback \
  GOOGLE_OAUTH_SCOPE="openid email profile" \
  SESSION_SECRET=<generated-session-secret> \
  MSG_KEY=<generated-msg-key> \
  SIGNING_KEY=<generated-signing-key> \
  --app <face-cloak-app-name>
```

If you use Heroku Redis instead of Redis Cloud, configure `REDIS_URL`; Redis Cloud sets `REDISCLOUD_URL`.

After the Heroku app is connected to GitHub, push changes to the configured branch to deploy.

Configure the matching [SAcurity/face-cloak-api](https://github.com/SAcurity/face-cloak-api) deployment with the app URL, Google OAuth settings, and the `VERIFY_KEY` generated from this app's signing key. Verify login/logout, registration, Google SSO, image upload, image views, and face assignment against the deployed API.
