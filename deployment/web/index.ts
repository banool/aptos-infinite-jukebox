import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

// Create a GCP resource (Storage Bucket)
const bucket = new gcp.storage.Bucket("web", {
    location: "US",
    website: {
        mainPageSuffix: "index.html"
    },
    uniformBucketLevelAccess: true,
});

// Let anyone view the content.
const bucketIAMBinding = new gcp.storage.BucketIAMBinding("web-IAMBinding", {
    bucket: bucket.name,
    role: "roles/storage.objectViewer",
    members: ["allUsers"],
});

// Upload a dummy index.html.
let assetDummyIndex = new pulumi.asset.StringAsset("Waiting for CI to copy across web files...");

// Create a bucket object with the dummy index.html file.
const bucketObject = new gcp.storage.BucketObject("index.html", {
    bucket: bucket.name,
    contentType: "text/html",
    source: assetDummyIndex,
});

// Export the bucket name.
export const bucketUrl = bucket.url;

// Export the URL of endpoint from the bucket.
export const bucketEndpoint = pulumi.concat("http://storage.googleapis.com/", bucket.name, "/", bucketObject.name);
