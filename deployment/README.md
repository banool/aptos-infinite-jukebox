# Deployment

## Deploying the driver
The image is built as part of CI. From there, this is currently handlded by banool/server-setup.

## Deploying the site
The website is configured to deploy to GitHub pages. For perpetuity, here is how I did this:
1. I added the `build_web` and `deploy_web` GitHub Actions jobs in `full_ci.yml`.
2. I went to the [GitHub Pages UI for the aclip repo](https://github.com/banool/aclip/settings/pages) (*not* the UI for banool.github.io) and set the custom domain to `aclip.app`.
3. I followed the steps [here](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site#configuring-an-apex-domain) (the apex domain option) that explain how to point your DNS name at GitHub's GitHub Pages servers. I used the A name option.
4. I made a CNAME record for the www subdomain, which GH Pages treats specially.

In the end I had these DNS records set up:
- A: @ 185.199.108.153
- A: @ 185.199.109.153
- A: @ 185.199.110.153
- A: @ 185.199.111.153
- CNAME: www banool.github.io (it automatically put a dot at the end)

This approach doesn't result in the build files appearing in the repos for banool.github.io or aclip, they just get put somewhere that GitHub hosts. I did not need to do anything to the GH Pages configuration of banool.github.io. If you did the DNS stuff properly, it should tell you so at the GitHub Pages UI.
