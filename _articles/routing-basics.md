---
layout: article
title: Routing Basics
description: >
  In-depth tutorial on Envoy's routing on your laptop. See how to configure
  routes, clusters, and listeners with static files in this Docker-based
  example.
---

[//]: # ( Copyright 2018 Turbine Labs, Inc.                                   )
[//]: # ( we may not use this file except in compliance with the License.     )
[//]: # ( we may obtain a copy of the License at                              )
[//]: # (                                                                     )
[//]: # (     http://www.apache.org/licenses/LICENSE-2.0                      )
[//]: # (                                                                     )
[//]: # ( Unless required by applicable law or agreed to in writing, software )
[//]: # ( distributed under the License is distributed on an "AS IS" BASIS,   )
[//]: # ( WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or     )
[//]: # ( implied. See the License for the specific language governing        )
[//]: # ( permissions and limitations under the License.                      )

[//]: # (Routing Basics)

# Routing Basics

This article discusses Envoy's routing in more detail. You may have already
seen how routing works
[on your laptop](on-your-laptop.html)
but now you can see more of how routes, clusters, and listeners are configured
with static files.

## Routing components

### Route

A route is a set of rules that match virtual hosts to clusters and allow you to
create traffic shifting rules. Routes are configured either via static
definion, or via the route discovery service (RDS).

### Cluster

A cluster is a group of similar upstream hosts that accept traffic from Envoy.
Clusters allow for load balancing of homogenous service sets, and better
infrastructure resiliency. Clusters are configured either via static
definitions, or by using the cluster discovery service (CDS).

### Listener

A listener is a named network location (e.g., port, unix domain socket, etc.)
that can accept connections from  downstream clients. Envoy exposes one or more
listeners. Listener configuration can be declared statically in the bootstrap
config, or dynamically via the listener discovery service (LDS).

## Defining Routes

Envoy’s routing definitions map a domain + URL to a cluster. In our previous
tutorial
[On Your Laptop](on-your-laptop.html),
we defined a simple setup with 2 clusters (service1 and service2), each of
which lived at a separate URL (/service1 and /service2).

```yaml
virtual_hosts:
  - name: backend
    domains:
    - "*"
    routes:
    - match:
        prefix: "/service/1"
      route:
        cluster: service1
    - match:
        prefix: "/service/2"
      route:
        cluster: service2
```

Clusters pull their membership data from DNS and use a round-robin load
balancing over all hosts. This cluster definition is from the examples
[on your laptop](on-your-laptop.html).

```yaml
clusters:
  - name: service1
      connect_timeout: 0.25s
      type: strict_dns
      lb_policy: round_robin
      http2_protocol_options: {}
      hosts:
      - socket_address:
          address: service1
          port_value: 80
  - name: service2
      connect_timeout: 0.25s
      type: strict_dns
      lb_policy: round_robin
      http2_protocol_options: {}
      hosts:
      - socket_address:
          address: service2
          port_value: 80
```

While example uses DNS for load balancing, but Envoy can also be configured to
work with service discovery.

## Configuring listeners

The following static configuration defines one listener, with some filters that
map to two different services. These listeners are fairly simple, and also
match to the services in our cluster and route definitions.

```yaml
listeners:
  - address:
      socket_address:
        address: 0.0.0.0
        port_value: 80
    filter_chains:
    - filters:
      - name: envoy.http_connection_manager
        config:
          codec_type: auto
          stat_prefix: ingress_http
          route_config:
            name: local_route
            virtual_hosts:
            - name: backend
              domains:
              - "*"
              routes:
              - match:
                  prefix: "/service/1"
                route:
                  cluster: service1
              - match:
                  prefix: "/service/2"
                route:
                  cluster: service2
          http_filters:
          - name: envoy.router
            config: {}
```

## Dynamic configuration of routes, clusters, and listeners

The routes and clusters noted here are defined statically, but by using RDS and
CDS to define them dynamically, you can centralize the route tables and cluster
definitions, and listeners and apply the same rules to multiple envoys, easing
the propagation of your changes on a large scale across your infrastructure.


## Further Exploration

Defining routes and listeners is crucial for using Envoy to connect traffic to
your services. Now that you understand basic configurations, you can see how
more complex traffic-shifting works in Envoy during
[incremental deploys and releases](incremental-deploys.html),
or learn how to
[configure routing with RDS](routing-configuration.html),
the route discovery service.
