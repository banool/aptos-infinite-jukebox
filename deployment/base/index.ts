import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

const cfg = new pulumi.Config()

// Get the deployment location.
const location = gcp.config.region!;

// Set up Artifact Registry if necessary.
const artifactRegistry = new gcp.artifactregistry.Repository("myrepo", {
    location,
    repositoryId: "myrepo",
    description: "Image Repository",
    format: "DOCKER",
});
