---
layout: article
title: Circuit Breaking
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

[//]: # (Circuit Breaking)

Circuit breaking is a great feature of Envoy, as it's always better for your
services to fail quickly at the network level, and gracefully prioritize
important requests.

## Configuring circuit breaking

Envoy provides a simple configuration option for circuit breaking. Consider the
specifics of your system as you set up circuit breaking.

Circuit breaking is specified as part of a cluster definition by adding a
circuit-breakers field. In the API, this would be returned from the Cluster
Discovery Service (CDS).

## A typical Envoy circuit breaker policy

Here's what a simple circuit breaking configuration looks like:

```yaml
circuit_breakers:
      thresholds:
        - priority: DEFAULT
          max_connections: 1
          max_requests: 1
        - priority: HIGH
          max_connections: 2
          max_requests: 2
```

In this example, there are a few fields that allow for a lot of service
flexibility:

`threshholds` allows us to define priorities and limits to the type of traffic
that our service is responding to.

`priority` can be set to either `DEFAULT` or `HIGH` which allows certain types
of traffic to be treated differently. Using the settings above, we would want
to set any requests that we don't want to wait in a long queue to HIGH, for
example, POST requests in a service where a user wants to make a purchase, or
save a state.

`max_connections` are the maximum number of connections that Envoy will make to
our service clusters. The default for these is 1024, but in real-world
instances we may drastically lower them.

`max_requests` are the maximum number of parallel retries that Envoy makes to
our service clusters. The default is also 1024.

## Advanced circuit breaking

- Break on latency. With Envoy, you essentially do this by reducing the latency
threshold for retries and breaking on lots of retries. If you set this too low,
you can DoS your services. Start higher than you think you need, and lower it
over time. This is the primary failure mode of over-engineered circuit breakers.

- Configure breaking based on a long queue of retries. This can be done in
conjunction with latency tuning or as a separate exercise (e.g. if you’re
retrying based on errors only). When you turn on retries, add a retries-based
breaker for the number of requests in a typical 10-second period.
Justification: if you have as many retries outstanding as the typical number of
requests, it’s broken.

 - Add fallbacks. Try/catch at the organizational level. This almost mandates
 failure / chaos testing, because you are introducing code paths that won’t be
 run in production until an incident. Make sure they’re good before you’re in a
 panic. Prefer locally computable data, or stale cache.

- Consider adding client checks. Circuit breaking is a pattern that fixes “as a
service how do I degrade gracefully in the face of downstream pressure?” Even
if the service is health enough that the global breaker doesn’t open, it’s
possible a particular client consumes its own thread pool. Consider combining
with a client-side breaker library.

## Next Steps

Global Circuit Breaking helps prepare your service for using
[automatic retries](automatic-retries.html).
Retrying error requests 3x can triple the volume of error traffic, making Envoy
an amplifier for a misconfigured calling service. With circuit breaking
configured, your service is equipped to helps selectively shed load when this
sort of failure occurs, preventing it from cascading to multiple services.
Combining these tools makes for robust services, able to handle common service
issues at the network level.
