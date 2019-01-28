fuzeops
=========

An implementation of the "Fuse Devops Automation Engineering Kata".

Find the following directories:

- chef-repo: required cookbooks
- docker: required Dockerfile
- terraform: optional AWS scaffolding

## Demo

Open http://34.205.170.135:8080/ in your browser; you will be redirected by dockerized nginx to apache site.

SSH to 34.205.170.135 from your whitelisted IP with user `fuze` and password communicated elseware ;)

## Running Tools


### Terraform

1. `terraform apply`

### Docker

1. `docker build -t nginx-redirector .`
2. `docker run --name redirector --detach --publish "8080:8080" nginx-redirector`

### Chef

- Locally:
   1. `cd chef-repo`
   1. `tar zcvf chef-cookbooks.tar.gz cookbooks`
   1. `scp chef-cookbooks.tar.gz user@server:~/`
   1. `scp solo.rb user@server:~/`
   1. `scp solo.json user@server:~/`
- Server:
   1. `wget https://packages.chef.io/files/stable/chefdk/3.6.57/ubuntu/14.04/chefdk_3.6.57-1_amd64.deb`
   1. `sudo dpkg -i chefdk_3.6.57-1_amd64.deb`
   1. `tar zxvf chef-cookbooks.tar.gz`
   1. `sudo chef-solo -c solo.rb -j solo.json > /var/www/html/chef-client.log`
