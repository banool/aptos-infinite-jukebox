import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

const cfg = new pulumi.Config()

// Get the deployment location.
const region = gcp.config.region!;

// Create a GCP resource (Storage Bucket)
const webBucket = new gcp.storage.Bucket("web-bucket", {
    location: "US",
    forceDestroy: true,
    website: {
        mainPageSuffix: "index.html"
    },
    uniformBucketLevelAccess: true,
});

// Let anyone view the content.
const bucketIAMBinding = new gcp.storage.BucketIAMBinding("web-IAMBinding", {
    bucket: webBucket.name,
    role: "roles/storage.objectViewer",
    members: ["allUsers"],
});

// Upload a dummy index.html.
let assetDummyIndex = new pulumi.asset.StringAsset("Waiting for CI to copy across web files...");

// Create a bucket object with the dummy index.html file.
const bucketObject = new gcp.storage.BucketObject("index.html", {
    bucket: webBucket.name,
    contentType: "text/html",
    source: assetDummyIndex,
    name: "index.html",
});

// Export the bucket name.
export const bucketUrl = webBucket.url;

// Export the URL of endpoint from the bucket.
export const bucketEndpoint = pulumi.concat("http://storage.googleapis.com/", webBucket.name, "/", bucketObject.name);

// Create a backend bucket, so we can hook up the load balancer to the bucket.
const backendBucket = new gcp.compute.BackendBucket("web-backend-bucket", {
    description: "Backend bucket for Aptos Infinite Jukebox web bucket",
    bucketName: webBucket.name,
    enableCdn: false,
});

// LB backend hostpath and rules.
const urlMap = new gcp.compute.URLMap("web-url-map", {
    defaultService: backendBucket.id,
    hostRules: [{
        hosts: ["dport.stream"],
        pathMatcher: "allpaths",
    }],
    pathMatchers: [{
        name: "allpaths",
        defaultService: backendBucket.id,
        pathRules: [{
            paths: ["/*"],
            service: backendBucket.id,
        }]
    }],
});

// Create a static IP address.
const staticIpAddress = new gcp.compute.GlobalAddress("web-static-ip", {});

export const glbIpAddress = staticIpAddress.address;

// Create a Google managed SSL certificate.
const webManagedSslCertificate = new gcp.compute.ManagedSslCertificate("web-managed-ssl-certificate", {
    managed: {
        domains: ["dport.stream"],
    }
});

// Route to bucket backend.
const targetHttpsProxy = new gcp.compute.TargetHttpsProxy("web-target-https-proxy", {
    urlMap: urlMap.id,
    sslCertificates: [webManagedSslCertificate.id],
});

// Setup a global load balancer (confusingly called a forwarding rule here).
const defaultForwardingRule = new gcp.compute.GlobalForwardingRule("web-glb", {
    target: targetHttpsProxy.id,
    portRange: "443",
    ipProtocol: "TCP",
    loadBalancingScheme: "EXTERNAL_MANAGED",
    ipAddress: staticIpAddress.id,
});

// Map to https glb.
const httpToHttpsMap = new gcp.compute.URLMap("web-http-to-https-url-map", {
    hostRules: [{
        hosts: ["dport.stream"],
        pathMatcher: "allpaths",
    }],
    defaultUrlRedirect: {
        httpsRedirect: true,
        stripQuery: false,
    },
    pathMatchers: [{
        name: "allpaths",
        defaultUrlRedirect: {
            httpsRedirect: true,
            stripQuery: false,
        },
    }],
});

// Route to https glb.
const targetHttpProxy = new gcp.compute.TargetHttpProxy("web-target-http-proxy", {
    urlMap: httpToHttpsMap.id,
});

// Setup a partial glb to route http to https.
const httpToHttpsForwardingRule = new gcp.compute.GlobalForwardingRule("web-http-to-https-glb", {
    target: targetHttpProxy.id,
    portRange: "80",
    ipProtocol: "TCP",
    loadBalancingScheme: "EXTERNAL_MANAGED",
    ipAddress: staticIpAddress.id,
});

pulumi.log.warn("Make sure you setup the domain to point to the GLB IP", staticIpAddress);