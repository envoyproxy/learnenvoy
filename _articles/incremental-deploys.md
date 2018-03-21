---
layout: article
title: Incremental Deploys
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

[//]: # (Incremental Deploys)

# Incremental Blue/Green Deploys

Now that we've configured
[Envoy on our laptop](on-our-laptop.html)
and understand the basics of using Envoy, there are a few routing exercises we
can explore.

While Envoy can route traffic like a conventional web server, much of its power
comes from its ability to modify its routing rules on the fly. Starting with
the simple routes we set up previously
[on your laptop](on-your-laptop.html),
we’ll extend that config to release a new version of one of the services using
traffic shifting. We’ll also cover header-based routing and weighted load
balancing to show how to use traffic management to canary a release, first to
special requests (e.g. requests from your laptop), then to a small fraction of
all requests.

## The setup

For this guide, we’ll need:

- [Docker](https://docs.docker.com/install/)
- [Docker Compose](https://docs.docker.com/compose/install/)
- [Git](https://help.github.com/articles/set-up-git/)
- [curl](https://curl.haxx.se/)

## Header-based Routing

First, we'll create a new version of service1 to illustrate the power of
header-based routing for our services. Still following along with the
[front-proxy](https://github.com/envoyproxy/envoy/tree/master/examples/front-proxy) example from the Envoy repo, modify the
[docker-compose.yml](https://github.com/envoyproxy/envoy/blob/master/examples/front-proxy/docker-compose.yml) to spin up a new service, called `service1a`.

```yaml
  service1a:
    build:
      context: .
      dockerfile: Dockerfile-service
    volumes:
      - ./service-envoy.yaml:/etc/service-envoy.yaml
    networks:
      envoymesh:
        aliases:
          - service1a
    environment:
      - SERVICE_NAME=1a
    expose:
      - "80"
```

To make sure Envoy can discover this service, we’ll also add it to the
`clusters’ section of our configuration file.

```yaml
  - name: service1a
    connect_timeout: 0.25s
    type: strict_dns
    lb_policy: round_robin
    http2_protocol_options: {}
    hosts:
    - socket_address:
        address: service1a
        port_value: 80
```

To make this routable, we can add a new route with a `headers` field in the
match. Since routing rules are applied in order, we’ll add this rule to the top
of the `routes` key. Requests with a header that matches our new rule will be
sent to our new service, while requests that don't include this header will
still get service 1.

```yaml
routes:
- match:
    prefix: "/service/1"
    headers:
      - name: "x-canary-version"
        value: "service1a"
  route:
    cluster: service1a
- match:
    prefix: "/service/1"
  route:
    cluster: service1
- match:
    prefix: "/service/2"
  route:
    cluster: service2
```

Shut down and then relaunch our example services with:

`docker-compose down --remove-orphans`

`docker-compose up --build -d`

If we make a request to our service with no headers, we'll get a response
from service 1:

```console
> curl localhost:8000/service/1
Hello from behind Envoy (service 1)! hostname: d0adee810fc4 resolvedhostname: 172.18.0.2
```

However if we include the `x-canary-version` header, Envoy will route our
request to service 1a:

```console
> curl -H 'x-canary-version: service1a' localhost:8000/service/1
Hello from behind Envoy (service 1a)! hostname: 569ee89eebc8 resolvedhostname: 172.18.0.6
```

Header-based routing in Envoy is a powerful feature. By employing it, we're
able to handle complex workflows in order to
[separate the deploy and release phases](https://blog.turbinelabs.io/deploy-not-equal-release-part-one-4724bc1e726b)
of our application, paving the way for canary releases and
[testing in production](https://opensource.com/article/17/8/testing-production).

## Weighted Load Balancing

Next, let's modify our config further to enable an incremental release to our
new service version. The following config should look familiar, but we've
swapped out the `cluster` key for `clusters` array under the default
routing rule, which moves 25% of the traffic pointed at our service to this
new version.

```yaml
- match:
    prefix: "/service/1"
  route:
    weighted_clusters:
      clusters:
      - name: service1a
        weight: 25
      - name: service1
        weight: 75
```

With this in place, shut down your previous example services by running:

`docker-compose down --remove-orphans`

Then, start it again with:

`docker-compose up --build -d`

Now, if we make a request to our service with no headers we should see
responses from service 1a about 25% of the time, or when the appropriate header
is loaded.

This example illustrates the power of an incremental release of your service,
and in the wild would also be paired with monitoring to ensure the delta
between versions of services, or between heterogeneous backends was trending
well before increasing or completing a release.

If we wanted to simulate a successful release, we could set the value of our
rule to 100, which would ensure all traffic is now sent to service 1a instead
of service 1. Similarly, by setting this value to 0, we could roll-back a bad
Release.

## Best practices

With the basics of using header-based routing and incremental weighted release,
you can now take advantage of a few best-practice patterns of software deploy
and release.

To start, separate the deploy and release processes . For most teams, this
means using CI/CD to get new versions of software onto your infrastructure.
Release is when that software begins serving production traffic using the
traffic shifting tools above. This can either be automated through CI/CD (after
the deploy step), or run as a manual process. By separating these steps, you
can limit the damage of a bad release, by ensuring software on production
infrastructure isn’t immediately production taking traffic.

While not every release will require all of these capabilities, you can use
Envoy’s routing tools to build a process to release software slowly while
gaining confidence in it. Once your new service is deployed, routing all
internal traffic to it with a header will let your teams verify a PR, or
internally dogfood it. Once you think it’s ready for users, you can then use
weighted incremental release patterns to gracefully release your new version to
them. A good pattern for weights as you approach 100% of traffic starts small
and takes progressively large leaps 1%, 5%, 10%, 50%. This pattern gives you
actionable feedback on your release (watch the metrics after each adjustment!),
with only small portions of your users affected.

With deploy and release as separate steps, using header-based routing to test
production deploys before release, and building incremental release slowly,
your teams will greatly benefit from the powerful benefits to using Envoy.

## Wrap-up

Now that you've seen a few examples of incremental and header-based routing
using Envoy, you may want to investigate more advanced features of Envoy, like
[automatic retries](automatic-retries.html)
or learn how to
[dynamically configure routing](https://www.learnenvoy.io/articles/routing-configuration.html)
