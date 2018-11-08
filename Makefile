#
# Copyright 2017-2018 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

DOCKER_IMG_NAME = training-data-service

#####################################################
# Dynamically get the commons makefile for shared
# variables and targets.
#####################################################
CM_REPO ?= raw.githubusercontent.com/ffdl-commons
CM_VERSION ?= master
CM_MK_LOC ?= .
CM_MK_NM ?= "ffdl-commons.mk"

# If the .mk file is changed on commons, and the file already exists here, it seems to update, but might take a while.
# Delete the file and try again to make sure, if you are having trouble.
CM_MK=$(shell wget -N https://${CM_REPO}/${CM_VERSION}/${CM_MK_NM} -P ${CM_MK_LOC} > /dev/null 2>&1 && echo "${CM_MK_NM}")

include $(CM_MK)

## show variable used in commons .mk include mechanism
show_cm_vars:
	@echo CM_REPO=$(CM_REPO)
	@echo CM_VERSION=$(CM_VERSION)
	@echo CM_MK_LOC=$(CM_MK_LOC)
	@echo CM_MK_NM=$(CM_MK_NM)

#####################################################

build-x86-64-tds:
	(CGO_ENABLED=0 GOOS=linux go build -ldflags "-s" -a -installsuffix cgo -o bin/main)

build-x86-64: build-x86-64-tds

docker-build-base:
	cd vendor/github.com/AISphere/ffdl-commons/grpc-health-checker && make build-x86-64

docker-build:       ## Build the Docker image
docker-build: build-x86-64-tds docker-build-base
	(docker build --label git-commit=$(shell git rev-list -1 HEAD) -t "$(DOCKER_BX_NS)/$(DOCKER_IMG_NAME):$(DLAAS_IMAGE_TAG)" .)

docker-push:       ## Push the Docker images to the registry
docker-push: docker-push-tds

docker-push-tds-only:
	docker push "$(DOCKER_BX_NS)/$(DOCKER_IMG_NAME):$(DLAAS_IMAGE_TAG)"

docker-push-tds: docker-push-tds-only


# Define environment variables for unit and integration testing
DLAAS_MONGO_PORT ?= 27017

#these credentials should be the same as what are present in lcm-secrets
DLAAS_ETCD_ADDRESS=https://watson-dev3-dal10-10.compose.direct:15232,https://watson-dev3-dal10-9.compose.direct:15232
DLAAS_ETCD_USERNAME=root
DLAAS_ETCD_PASSWORD=RHDACXYDLMIXXPEE
DLAAS_ETCD_PREFIX=/dlaas/jobs/local_hybrid/

test-start-deps:   ## Start test dependencies
	docker run -d -p $(DLAAS_MONGO_PORT):27017 --name mongo mongo:3.0

# Stop test dependencies
test-stop-deps:
	-docker rm -f mongo

TEST_PKGS ?= $(shell go list ./... | grep -v /vendor/)

test-unit:         ## Run all unit tests (short tests)
	DLAAS_LOGLEVEL=debug DLAAS_ENV=local go test $(TEST_PKGS) -v -short

test-integration:  ## Run all integration tests (non-short tests with Integration in the name)
	DLAAS_LOGLEVEL=debug DLAAS_DNS_SERVER=disabled DLAAS_ENV=local  go test $(TEST_PKGS) -run "Integration" -v

test-lcm:
	DLAAS_LOGLEVEL=debug DLAAS_HOST=$(DLAAS_HOST) $(DEPLOYMENT_ARGS) go test github.ibm.com/deep-learning-platform/ffdl-lcm/service/lcm -v

# Runs unit and integration tests
test: test-unit test-integration


RESTAPI_SERVICE = ../dlaas-restapi-service
TRAINER_SERVICE = ../dlaas-trainer-service
TRAINING_DATA_SERVICE = ../dlaas-training-metrics-service
RATELIMITER_SERVICE = ../dlaas-ratelimiter

DLAAS_LOCAL_ARGS = DLAAS_LOGLEVEL=debug DLAAS_HOST=$(DLAAS_HOST) \
		$(DEPLOYMENT_ARGS) \
		DLAAS_ENV=local \
		DLAAS_LCM_DEPLOYMENT=local \
		DLAAS_DNS_SERVER=disabled

serve-local:
ifndef FSWATCH
	@echo "ERROR: fswatch not found. Please install it to use this target."
	@exit 1
endif
	make kill-services-local
	make run-services-local
	fswatch -r -o cmd config logger services storage util *.yml | xargs -n1 -I{}  make run-services-local || make kill-services-local

serve-local-lcm:
ifndef FSWATCH
	@echo "ERROR: fswatch not found. Please install it to use this target."
	@exit 1
endif
	make kill-local-lcm
	make run-local-lcm
	fswatch -r -o cmd/lcm config logger services storage util *.yml | xargs -n1 -I{}  make run-local-lcm || make kill-local-lcm


# echo exact environment variables used to launch local services, for debugging and the like.
showrunlocalvars: showvars
	@echo "# =========== env grep dlaas vars ============"
	@for ln in $(shell $(DLAAS_LOCAL_ARGS) env | grep DLAAS_); do \
		echo "export $$ln"; \
	done

LOCALEXECCOMMAND ?= MUST_SET_LOCALEXECCOMMAND

# exec-local is a dev special for executing something with the same environment that run-services-local uses.
exec-local:
	$(shell $(DLAAS_LOCAL_ARGS) $(LOCALEXECCOMMAND))

kill-services-local:
	(cd $(RESTAPI_SERVICE) && make kill-local)
	(cd $(TRAINER_SERVICE) && make kill-local)
	(cd $(TRAINING_DATA_SERVICE) && make kill-local)
	-killall ffdl-lcm

kill-local-lcm:
	-killall ffdl-lcm

kube-artifacts:    ## Show the state of various Kubernetes artifacts
	kubectl $(KUBE_SERVICES_CONTEXT_ARGS) get pod,configmap,svc,ing,statefulset,job,pvc,deploy,secret -o wide --show-all
	#@echo; echo
	#kubectl $(KUBE_LEARNER_CONTEXT_ARGS) get deploy,statefulset,pod,pvc -o wide --show-all

kube-destroy:
	@echo "If you're sure you want to delete the $(DLAAS_SERVICES_KUBE_NAMESPACE)" namespace, run the following command:
	@echo "  kubectl $(KUBE_SERVICES_CONTEXT_ARGS) delete namespace $(DLAAS_SERVICES_KUBE_NAMESPACE)"

# This list is the union of needs for all services in this Makefile
DEPLOY_EXTRA_VARS = --extra-vars "service_version=$(DLAAS_IMAGE_TAG)" \
		--extra-vars "DLAAS_NAMESPACE=$(DLAAS_SERVICES_KUBE_NAMESPACE)" \
		--extra-vars "DLAAS_LEARNER_KUBE_NAMESPACE=$(DLAAS_LEARNER_KUBE_NAMESPACE)" \
		--extra-vars "DLAAS_LEARNER_KUBE_URL=$(DLAAS_LEARNER_KUBE_URL)" \
		--extra-vars "dlaas_learner_tag=$(DLAAS_LEARNER_TAG)" \
		--extra-vars "eureka_name=$(DLAAS_EUREKA_NAME)"

#devstack-start: sv-setup   ## Start up the local dev stack
#	-docker login -u token -p `cat certs/bluemix-cr-ng-token` registry.ng.bluemix.net
#	-kubectl create secret docker-registry bluemix-cr-ng --docker-username token --docker-password `cat certs/bluemix-cr-ng-token` --docker-server registry.ng.bluemix.net --docker-email wps@us.ibm.com
#	ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_ROLES_PATH=$(THIS_DIR)/ansible/roles \
#		ansible-playbook -b -i $(INVENTORY) ansible/plays/ffdl-devstack-k8s.yml \
#		-c local \
#		--extra-vars "service=mongo" \
#		$(DEPLOY_EXTRA_VARS)
#	bin/copy_learner_config.sh devwat-dal13-cruiser15-dlaas $(DLAAS_SERVICES_KUBE_CONTEXT)
##	(cd $(TRAINER_SERVICE) && make devstack-start)

devstack-stop:
	-kubectl $(KUBE_SERVICES_CONTEXT_ARGS) delete service mongo --ignore-not-found=true --now
	-kubectl $(KUBE_SERVICES_CONTEXT_ARGS) delete statefulset mongo-deployment --ignore-not-found=true --now
	-kubectl $(KUBE_SERVICES_CONTEXT_ARGS) delete configmap learner-config --ignore-not-found=true --now
#	(cd $(TRAINER_SERVICE) && make devstack-stop)

devstack-restart: devstack-stop devstack-start

# Add a route on OS X to access docker instances directly
#
route-add-osx:
ifeq ($(shell uname -s),Darwin)
	sudo route -n add -net 172.17.0.0 $(DOCKERHOST_HOST)
endif

# Function for generating a template
define render_template
	eval "echo \"$$(cat $(1))\""
endef

# Total reinstall of vendor directories in all services.
glide-reinstall-all:
	glide cache-clear
	rm -rf vendor && glide install
	(cd $(TRAINER_SERVICE) && rm -rf vendor && glide install)
	(cd $(TRAINING_DATA_SERVICE) && rm -rf vendor && glide install)
	(cd $(RESTAPI_SERVICE) && rm -rf vendor && glide install)
	(cd $(RATELIMITER_SERVICE) && rm -rf vendor && glide install)



show-inventory-file:
	(echo $(INVENTORY))

#deploy-fluentd:
#	DLAAS_KUBE_CONTEXT=$(DLAAS_LEARNER_KUBE_CONTEXT) ./bin/create-secret.sh $(DLAAS_LEARNER_KUBE_SECRET)
#	ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_ROLES_PATH=$(THIS_DIR)/ansible/roles \
#		ansible-playbook -b -i $(INVENTORY) ansible/plays/ffdl-fluentd-k8s.yml \
#		-c local \
#		--verbose \
#		--extra-vars "operation=apply" \
#		--extra-vars "DLAAS_LEARNER_KUBE_SECRET=$(DLAAS_LEARNER_KUBE_SECRET)" \
#		$(DEPLOY_EXTRA_VARS)
#
#undeploy-fluentd:
#	DLAAS_KUBE_CONTEXT=$(DLAAS_LEARNER_KUBE_CONTEXT) ./bin/create-secret.sh $(DLAAS_LEARNER_KUBE_SECRET)
#	ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_ROLES_PATH=$(THIS_DIR)/ansible/roles \
#		ansible-playbook -b -i $(INVENTORY) ansible/plays/dlaas-fluentd-k8s.yml \
#		-c local \
#		--verbose \
#		--extra-vars "operation=delete" \
#		--extra-vars "DLAAS_LEARNER_KUBE_SECRET=$(DLAAS_LEARNER_KUBE_SECRET)" \
#		$(DEPLOY_EXTRA_VARS)
#
#
#ansible-setup-ubuntu:
#	sudo apt-add-repository -y ppa:ansible/ansible
#	sudo apt-get update
#	sudo apt-get install -y ansible
#
## Will only execute tasks tagged (flag -t) 'setup' in Ansible role
#sv-setup:
#	DLAAS_KUBE_CONTEXT=$(DLAAS_LEARNER_KUBE_CONTEXT)
#	ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_ROLES_PATH=$(THIS_DIR)/ansible/roles \
#			ansible-playbook -b -i $(INVENTORY) -t setup $(THIS_DIR)/ansible/plays/dlaas-static-pvc-k8s.yml \
#			-c local \
#			--verbose \
#			--extra-vars "DLAAS_LEARNER_KUBE_SECRET=$(DLAAS_LEARNER_KUBE_SECRET)" \
#			$(DEPLOY_EXTRA_VARS)
#
## Will only execute tasks tagged (flag -t) 'delete' in Ansible role
#sv-delete:
#	DLAAS_KUBE_CONTEXT=$(DLAAS_LEARNER_KUBE_CONTEXT)
#	ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_ROLES_PATH=$(THIS_DIR)/ansible/roles \
#			ansible-playbook -b -i $(INVENTORY) -t delete $(THIS_DIR)/ansible/plays/dlaas-static-pvc-k8s.yml \
#			-c local \
#			--verbose \
#			--extra-vars "DLAAS_LEARNER_KUBE_SECRET=$(DLAAS_LEARNER_KUBE_SECRET)" \
#			$(DEPLOY_EXTRA_VARS)

clean:
	if [ -d ./cmd/lcm/bin ]; then rm -r ./cmd/lcm/bin; fi

.PHONY: all clean doctor usage showvars test-unit
