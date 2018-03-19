---
layout: article
title: Routing Basics
---

[//]: # ( Copyright 2018 Turbine Labs, Inc.                                   )
[//]: # ( you may not use this file except in compliance with the License.    )
[//]: # ( You may obtain a copy of the License at                             )
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

Now that you've configured
[Envoy on your laptop](on-your-laptop.html)
and understand the basics of using Envoy, there are a few routing exercises you can explore.

We’ll cover header-based routing of Envoy and incremental release in a few steps, by modifying the service configuration files from the
[On Your Laptop](on-your-laptop.html)
article.


## The setup

The Envoy documentation provides a good overview of
[how to run the example](https://www.envoyproxy.io/docs/envoy/latest/start/sandboxes/zipkin_tracing)

For this guide, you’ll need:

- [Docker](https://docs.docker.com/install/)
- [Docker Compose](https://docs.docker.com/compose/install/)
- [Git](https://help.github.com/articles/set-up-git/)
- [curl](https://curl.haxx.se/)

## Header-based Routing

Using our cluster definitons from [on your laptop](on-your-laptop.html)

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

we'll create a new version of service1 to illustrate the power of header-based
routing for incremental release of your services.

```yaml
  - name: service1a
    connect_timeout: 0.250s
    type: strict_dns
    lb_policy: round_robin
    http2_protocol_options: {}
    circuit_breakers:
      thresholds:
        - priority: DEFAULT
          max_connections: 1
          max_requests: 1
        - priority: HIGH
          max_connections: 2
          max_requests: 2
    hosts:
    - socket_address:
         address: service1a
         port_value: 80
         priority: HIGH
                 decorator:
                   operation: updateAvailability
              - match:
                  prefix: "/"
                  headers:
                    - name: "x-canary-version"
                      value: "service1a"
                route:
                  cluster: service1a
                  retry_policy:
                    retry_on: 5xx
                    num_retries: 3
                    per_try_timeout: 0.300s
               - match:
                   prefix: "/"
                 route:
```

Shut down and then relaunch your example services with:

`docker-compose down --remove-orphans`

`docker-compose up --build -d`

If we make a request to our service with no headers, you'll get a response from
service 1.

```console
> curl localhost:8000/service/1
Hello from behind Envoy (service 1)! hostname: d0adee810fc4 resolvedhostname: 172.18.0.2
```

However if we include the `x-canary-version` header, Envoy will route our
request to service 1a.

```console
> curl -H 'x-canary-version: service1a' localhost:8000/service/1
Hello from behind Envoy (service 1a)! hostname: 569ee89eebc8 resolvedhostname: 172.18.0.6
```

This is a powerful feature. It allows you to
[separate the deploy and release phases](https://blog.turbinelabs.io/deploy-not-equal-release-part-one-4724bc1e726b)
of your application, paving the way for canary releases and
[testing in production](https://opensource.com/article/17/8/testing-production).


## Wrap-up

Now that you've seen a few examples of incremental and header-based routing
using Envoy, you may want to investigate
[automatic retries](automatic-retries.html)
or learn how to
[dynamically configure routing](https://www.learnenvoy.io/articles/routing-configuration.html)
