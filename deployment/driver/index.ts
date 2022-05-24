import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

const cfg = new pulumi.Config()

// Get the deployment location.
const location = gcp.config.region!;

// Set up Artifact Registry if necessary.
const artifactRegistry = new gcp.artifactregistry.Repository("artifact-registry", {
    location,
    repositoryId: "my-repository",
    description: "Image Repository",
    format: "DOCKER",
});

// Confirm the image exists.
// todo

// Enable cloud run.
const enableCloudRun = new gcp.projects.Service("EnableCloudRun", {
    service: "run.googleapis.com",
});

// Create the Cloud Run container.
const driverService = new gcp.cloudrun.Service("driver-container", {
    location,
    template: {
        spec: {
            containers: [
                {
                    image: "ghcr.io/banool/aptos-infinite-jukebox-driver:main",
                    args: [
                        "--account-private-key", cfg.requireSecret("account_private_key"),
                        "--spotify-client-id", cfg.requireSecret("spotify_client_id"),
                        "--spotify-client-secret", cfg.requireSecret("spotify_client_secret"),
                    ],
                },
            ]
        }
    }
},
    { dependsOn: enableCloudRun });
