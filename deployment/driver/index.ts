import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";

const cfg = new pulumi.Config()

const region = gcp.config.region!;

// Build the run command.
let runCommand = pulumi.all(
    [
        cfg.requireSecret("account_private_key"),
        cfg.requireSecret("spotify_client_id"),
        cfg.requireSecret("spotify_client_secret")
    ]).apply(([account_private_key, spotify_client_id, spotify_client_secret]) => [
    "docker",
    "run",
    "--pull", "always",
    "-v", "/tmp:/hostcache",
    "ghcr.io/banool/aptos-infinite-jukebox-driver:main",
    "--account-private-key", account_private_key,
    "--spotify-client-id", spotify_client_id,
    "--spotify-client-secret", spotify_client_secret,
    "--cache-path", "/hostcache/cache.json",
].join(" "));

// Create a Compute Engine instance.
const driverInstance = new gcp.compute.Instance("driver-instance", {
    machineType: "f1-micro",
    zone: `${region}-c`,
    bootDisk: {
        initializeParams: {
            // I used https://console.cloud.google.com/compute/images to find the
            // family and name to use here. This is the Container Optimized OS.
            image: "projects/cos-cloud/global/images/cos-stable-97-16919-29-21",
        },
    },
    allowStoppingForUpdate: true,
    deletionProtection: false,
    networkInterfaces: [{
        network: "default",
        accessConfigs: [{}],
    }],
    metadataStartupScript: runCommand
});

export const driverInstanceId = driverInstance.id;
