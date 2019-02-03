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

protoc:      ## Build gRPC .proto files into vendor directory
	$(NOOP)

install-deps:  ## Remove vendor directory, rebuild dependencies
	$(NOOP)

copy-local-tds-client:
	cp -r ../training_data_service_client .

uncopy-local-tds-client:
	cp -r ../training_data_service_client .

docker-build: copy-local-tds-client docker-build-only uncopy-local-tds-client

docker-push: docker-push-base          ## Push docker image to a docker hub

clean: clean-base                      ## Clean all build artifacts
