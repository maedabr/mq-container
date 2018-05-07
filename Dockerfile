# © Copyright IBM Corporation 2015, 2018
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

ARG BASE_IMAGE=ubuntu:16.04

###############################################################################
# Build stage to build Go code
###############################################################################
FROM golang:1.10 as builder 
WORKDIR /go/src/github.com/ibm-messaging/mq-container/
COPY cmd/ ./cmd
COPY internal/ ./internal
COPY vendor/ ./vendor
RUN go build ./cmd/runmqserver/
RUN go build ./cmd/chkmqready/
RUN go build ./cmd/chkmqhealthy/
# Run all unit tests
RUN go test -v ./cmd/runmqserver/
RUN go test -v ./cmd/chkmqready/
RUN go test -v ./cmd/chkmqhealthy/
RUN go test -v ./internal/...

###############################################################################
# Main build stage, to build MQ image
###############################################################################
FROM $BASE_IMAGE

# The URL to download the MQ installer from in tar.gz format
# This assumes an archive containing the MQ Debian (.deb) install packages
ARG MQ_URL

# The MQ packages to install - see install-mq.sh for default value
ARG MQ_PACKAGES

COPY install-mq.sh /usr/local/bin/

# Install MQ.  To avoid a "text file busy" error here, we sleep before installing.
RUN chmod u+x /usr/local/bin/install-mq.sh \
  && sleep 1 \
  && install-mq.sh

# Create a directory for runtime data from runmqserver
RUN mkdir -p /run/runmqserver \
  && chown mqm:mqm /run/runmqserver

COPY --from=builder /go/src/github.com/ibm-messaging/mq-container/runmqserver /usr/local/bin/
COPY --from=builder /go/src/github.com/ibm-messaging/mq-container/chkmq* /usr/local/bin/
COPY NOTICES.txt /opt/mqm/licenses/notices-container.txt

RUN chmod ug+x /usr/local/bin/runmqserver \
  && chown mqm:mqm /usr/local/bin/*mq* \
  && chmod ug+xs /usr/local/bin/chkmq*

# Always use port 1414
EXPOSE 1414

ENV LANG=en_US.UTF-8 AMQ_DIAGNOSTIC_MSG_SEVERITY=1 AMQ_ADDITIONAL_JSON_LOG=1 LOG_FORMAT=basic

ENTRYPOINT ["runmqserver"]
