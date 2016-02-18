SHELL := /bin/bash

# Read options from config.json
GIT_HOST = $(shell jq -r ".git.hostname" shared/config.json)
GIT_DIR = $(shell jq -r ".docker.gitdir" shared/config.json)
WORK_DIR = $(shell jq -r ".docker.cwd" shared/config.json)
OCTAVE_SUFFIX = $(shell jq -r ".docker.images.octaveSuffix" shared/config.json)
FILES_SUFFIX = $(shell jq -r ".docker.images.filesystemSuffix" shared/config.json)

docker-octave:
	if [[ -e bundle ]]; then rm -rf bundle; fi
	mkdir bundle
	cat dockerfiles/base.dockerfile \
		>> bundle/Dockerfile
	cat dockerfiles/build-octave.dockerfile \
		>> bundle/Dockerfile
	cat dockerfiles/entrypoint-octave.dockerfile \
		>> bundle/Dockerfile
	cp -rL back-octave/* bundle
	docker build -t oo/$(OCTAVE_SUFFIX) bundle
	rm -rf bundle

docker-files:
	if [[ -e bundle ]]; then rm -rf bundle; fi
	mkdir bundle
	cat dockerfiles/base.dockerfile \
		>> bundle/Dockerfile
	cat dockerfiles/install-node.dockerfile \
		>> bundle/Dockerfile
	cat dockerfiles/filesystem.dockerfile \
		| sed -e "s;%GIT_DIR%;$(GIT_DIR);g" \
		| sed -e "s;%GIT_HOST%;$(GIT_HOST);g" \
		>> bundle/Dockerfile
	cat dockerfiles/entrypoint-filesystem.dockerfile \
		| sed -e "s;%GIT_DIR%;$(GIT_DIR);g" \
		| sed -e "s;%WORK_DIR%;$(WORK_DIR);g" \
		>> bundle/Dockerfile
	cp -rL back-filesystem bundle
	docker build -t oo/$(FILES_SUFFIX) bundle
	rm -rf bundle

docker-master-docker:
	echo "This image would require using docker-in-docker.  A pull request is welcome."

docker-master-selinux:
	echo "It is not currently possible to install SELinux inside of a Docker container."

install-selinux-policy:
	yum install -y selinux-policy-devel policycoreutils-sandbox selinux-policy-sandbox
	ln -s back-master/src/octave_online.te /etc/selinux/targeted/policy
	(
		cd /etc/selinux/targeted/policy
		make -f /usr/share/selinux/devel/Makefile octave_online.pp
		semodule -i octave_online.pp
	)
	semanage fcontext -a -t octave_site_t "/usr/local/lib/octave(/.*)?"
	restorecon -R -v /usr/local/lib/octave
	setenforce enforcing
	echo "For maximum security, make sure to put SELinux in enforcing mode by default in /etc/selinux/config."

docker: docker-octave docker-files

clean:
	if [[ -e bundle ]]; then rm -rf bundle; fi