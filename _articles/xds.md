---
layout: article
title: An xDS Overview
---

xDS is a suite of configuration service APIs that allow for dynamic
configuration of an Envoy proxy. It's possible to configure Envoy with a few or
all of these services. This overview will describe what each service does, and
why you would use it.

## CDS

The Cluster Discovery Service tells Envoy about your clusters. In Envoy’s
vernacular, a “cluster” is a named group of host/ports, over which it will
load-balance traffic. CDS also allows configuration health checks, and TLS, and
other connection types. Cluster instances can be listed statically in CDS or,
more commonly, dynamically managed using EDS

Read more about CDS configuration [here](https://www.envoyproxy.io/docs/envoy/latest/configuration/cluster_manager/cds).

## EDS

The Endpoint Discovery Service tells Envoy about the instances (endpoints) of
your clusters. EDS produces a list of instances for each cluster, and some
metadata about each instance.

Read more about EDS configuration [here](https://www.envoyproxy.io/docs/envoy/latest/api-v2/api/v2/eds.proto.html#envoy-api-file-envoy-api-v2-eds-proto).

## LDS

The Listener Discovery Service tells Envoy what ports to listen on, and what
protocols to terminate on those ports. You can also configure TLS and request
logging with this service.

Read more about LDS configuration [here](https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/lds).

## RDS

The Route Discovery Service tells Envoy about the routes for each HTTP Listener
configured in the LDS. You can partition the URL-space in to multiple paths,
each potentially backed by a different services. You can also add redirects,
request and response headers, timeouts, and retry policies.

Read more about RDS configuration [here](https://www.envoyproxy.io/docs/envoy/latest/configuration/http_conn_man/rds).

## Learn More

For the full xDS configuration reference, read more [here](https://www.envoyproxy.io/docs/envoy/latest/configuration/configuration.html#config).
