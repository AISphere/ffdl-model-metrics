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

include ../ffdl-commons/ffdl-commons.mk

protoc: protoc-trainer protoc-lcm      ## Build gRPC .proto files into vendor directory

install-deps: install-deps-base protoc ## Remove vendor directory, rebuild dependencies

docker-build-log-collectors:                        ## Make docker-build for all log-collectors
	$(MAKE) -C ./log_collectors/emetrics_file docker-build
	$(MAKE) -C ./log_collectors/regex_extractor docker-build
	$(MAKE) -C ./log_collectors/simple_log_collector docker-build
	$(MAKE) -C ./log_collectors/tensorboard docker-build

docker-push-log-collectors:                        ## Make docker-push for all log-collectors
	$(MAKE) -C ./log_collectors/emetrics_file docker-push
	$(MAKE) -C ./log_collectors/regex_extractor docker-push
	$(MAKE) -C ./log_collectors/simple_log_collector docker-push
	$(MAKE) -C ./log_collectors/tensorboard docker-push

log-collectors: docker-build-log-collectors docker-push-log-collectors 	## Make all log-collectors

docker-build-service: docker-build-base        ## Install deps if needed, build go code and docker image

docker-build: docker-build-service docker-build-log-collectors        ## Install deps if needed, build go docker, log-collectors.

docker-push: docker-push-base  docker-push-log-collectors        ## Push docker and log-collector images to a docker hub

build-service-only: docker-build-service docker-push  ## Only build service, not log-collectors

clean: clean-base                      ## Clean all build artifacts
	rm -rf certs