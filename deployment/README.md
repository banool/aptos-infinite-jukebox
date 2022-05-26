# Deployment

This repo provide a Pulumi program to configure the necessary pieces for running a full jukebox yourself. I just use GCP for now.

## Setting up

First, follow the steps here to get the necessary tooling set up: https://www.pulumi.com/docs/get-started/gcp/begin/. Below is a summary of those steps.

Make a project in GCP. In this example, it's called `personaltest`.

Set up tooling:
```
brew install pulumi/tap/pulumi
brew install google-cloud-sdk

# Login with the Pulumi CLI.
# For this personal project I'm just using the Pulumi service.
pulumi login

# Login with the gcloud CLI.
gcloud init
gcloud auth application-default login
```

## Setting configuration / secrets
You'll want to set up your config values something like this:
```
$ pulumi config
KEY                    VALUE
account_private_key    [secret]
spotify_client_id      e02b0452a18948a9a963b35bd4a4f743
spotify_client_secret  [secret]
gcp:project            aptos-infinite-jukebox-351118
gcp:region             us-west1
```

You can do that with commands like these:
```
pulumi config set gcp:region us-west1
pulumi config set account_private_key --secret 0x342423432432babaffabababff
```

You need to do this for each of the three programs within this directory. Only `driver` needs those additional secrets, for `web` and `base` you only need the `gcp:.*` keys.

You need to do this for CI to work. In short, when CI runs, it runs `pulumi up` in each of these projects. This first logs in to the Pulumi service, where the secrets are held.
