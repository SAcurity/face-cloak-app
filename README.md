# Face Cloak App
Web Application for Face Cloak, a privacy controls for detected faces in images.

This is the **server-rendered web frontend**. It is a thin presentation layer over the Face Cloak API (`face-cloak-api`); the API holds the database and enforces all authorization. The app is responsible for sessions, login flow, form validation, and rendering Slim templates.


## Install

Install this application by cloning the relevant branch and using bundler to install specified gems:

```shell
bundle install
```

You will also need to copy `config/secrets-example.yml` to `config/secrets.yml` and fill in real `SESSION_SECRET` and `MSG_KEY` values:

```shell
cp config/secrets-example.yml config/secrets.yml
bundle exec rake generate:session_secret
bundle exec rake newkey:msg
# paste the printed values into config/secrets.yml under development/test
```

## Test

Run the specs:

```shell
bundle exec rake spec
```

Service specs use WebMock, so they do not require a live API.

## Execute

The web app expects the Face Cloak API to be running on `http://localhost:3000`. From `face-cloak-api/`, start the API first:

```shell
bundle exec rake run:dev
```

Then, from this repo, launch the web app on port 9292:

```shell
bundle exec rake run:dev
```

Visit `http://localhost:9292/` in your browser.

## Secure Sessions

The App stores session values through `FaceCloak::SecureSession`, which encrypts each value with `FaceCloak::SecureMessage` and a NaCl `SimpleBox` key from `MSG_KEY`.

Production still uses Rack cookie sessions for this milestone. The Rack cookie is signed/encrypted with `SESSION_SECRET`, and sensitive values are also encrypted before being placed in the session hash.

## Deploy to Heroku

Create and deploy the App separately from the API:

```shell
heroku create <face-cloak-app-name>
git push heroku main
```

Configure the App:

```shell
heroku config:set API_URL=https://<face-cloak-api-name>.herokuapp.com/api/v1 \
  APP_URL=https://<face-cloak-app-name>.herokuapp.com \
  SESSION_SECRET=<generated-session-secret> \
  MSG_KEY=<generated-msg-key> \
  --app <face-cloak-app-name>
```

Verify login/logout, registration, image upload, image views, and face assignment against the deployed API.
