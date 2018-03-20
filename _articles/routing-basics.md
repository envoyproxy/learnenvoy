---
layout: article
title: Routing Basics
---

[//]: # ( Copyright 2018 Turbine Labs, Inc.                                   )
[//]: # ( we may not use this file except in compliance with the License.    )
[//]: # ( we may obtain a copy of the License at                             )
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
but now you can see more of how routes are defined for simple round-robin
load-balancing. We will also cover how listeners are configured for your
services, both through static files, and dynamically.

## Defining Routes

Envoy’s routing definitions map a domain + URL to a clusters — a named group of
host/posts. From our previous tutorial On Your Laptop, we defined a simple
setup with 2 clusters (service1 and service2), each of which lived at a
separate URL (/service1 and /service2).

```
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

The clusters pull their membership data from DNS and use a round-robin load balancing over all hosts.


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

## LDS

In Envoy, LDS is the listener discovery service, which allows for dynamic
configuration of listeners.

### What is a listener?

A listener is a named network location (e.g., port, unix domain socket, etc.)
that can accept connections from  downstream clients. Envoy exposes one or more
listeners.

## Static listener configuration

Listener configuration can be declared statically in the bootstrap config, or
dynamically via LDS. The following static configuration defines one listener,
with some filters that map to two different services.

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

## Dynamic LDS configuration

It's also possible to obtain listener configuration dynamically. For example,
adding the following to your bootstrap config declares an LDS-based dynamic
listener configuration.

```json
dynamic_resources:
 lds_config:
    api_config_source:
      api_type: GRPC
      cluster_names: [xds_cluster]
```

The responses from the management server will look very similar to the previous
static definition for listeners:

```yaml
version_info: "0"
resources:
- "@type": type.googleapis.com/envoy.api.v2.Listener
  name: listener_0
  address:
    socket_address:
      address: 127.0.0.1
      port_value: 10000
  filter_chains:
  - filters:
    - name: envoy.http_connection_manager
      config:
        stat_prefix: ingress_http
        codec_type: AUTO
        rds:
          route_config_name: local_route
          config_source:
            api_config_source:
              api_type: GRPC
              cluster_names: [xds_cluster]
        http_filters:
        - name: envoy.router
```

Defining routes and listeners is crucial for using Envoy to connect traffic to
your services. Now that you understand basic configurations, you can see how more complex traffic-shifting works in Envoy during [incremental deploys and releases](incremental-deploys.html)
