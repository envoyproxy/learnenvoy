---
layout: article
title: Setting Up SSL in Envoy
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

[//]: # (Setting Up SSL with Envoy)

When serving any kind of traffic over the public internet, it’s best to secure
it. When used as either a front proxy or a service mesh proxy, Envoy supports
TLS and SSL to encrypt all communication between clients and the proxy.

In this article, we’ll show how to set up Envoy as a front proxy that
terminates TLS. It builds off the code in On Your Laptop, which balances a
single domain over two services. We’ll extend this to secure traffic to both
services.

There are three steps to get this running:

1. Specifying the certificate for Envoy to use
2. Envoy for TLS
3. Configuring Envoy to redirect insecure traffic

## Certificate Files

To deploy this to production, you’ll need the certificate for the site you own.
If you don’t already have this, [Let’s Encrypt](https://letsencrypt.org)
provides free and automatable certificates. For testing, you can generate a
private key file `key.pem` and self-signed certificate `cert.pem` using
OpenSSL. The only important detail it will as you for is the Common Name. We’ll
use `example.com`:

```console
$ openssl req -x509 -newkey rsa:4096 -keyout example-com.key -out example-com.crt -days 365
```

```shell
Generating a 2048 bit RSA private key
...........................+++
...............+++
writing new private key to 'mine2.key'
-----
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) []:US
State or Province Name (full name) []:CA
Locality Name (eg, city) []:SF
Organization Name (eg, company) []:Turbine Labs
Organizational Unit Name (eg, section) []:Envoy Division
Common Name (eg, fully qualified host name) []:example.com
Email Address []:you@example.com
```

You’ll have to put these somewhere that Envoy can get to them. Since we’re
using Docker and docker-compose in this example, we’ll just add these to our
Envoy container by modifying `Dockerfile-frontenvoy`:

```console
ADD ./key.pem /etc/key.pem
ADD ./cert.pem /etc/cert.pem
```

Since TLS configured via Envoy listeners, we’ll add a `tls_context` block next to our list of filters with the locations of these files in `front-envoy.yaml`:

```yaml
tls_context:
  common_tls_context:
    tls_certificates:
      - certificate_chain:
          filename: "/etc/example-com.crt"
        private_key:
          filename: "/etc/example-com.key"
```

This will affect all traffic, and while this will work on any port, we should also change this listener to the standard TLS port, 443.

```yaml
  - address:
      socket_address:
        address: 0.0.0.0
        port_value: 443
```

Finally, we also have to specify the domain to serve traffic on instead of using a wildcard match.

```yaml
domains:
- "example.com"
```

Note that Envoy supports SNI for multiple domains (e.g. example.com and
www.example.com) by essentially repeating this configuration across several
filter chains within the same listener. You can see an example
[in the Envoy docs](https://www.envoyproxy.io/docs/envoy/latest/faq/sni). At
the moment (Envoy v1.6), these filter chains must be identical across domains.
Copy/paste away!

You can test that this works with curl. Two notes if you’re using the
self-signed certs from above:

 - To get curl to successfully validate the certificate, we have to pass the certificate file to Envoy. We do this with the `--cacert` option.
 - To get curl to connect to our Envoy instead of asking the system to resolve example.com, we have to explicitly specify that we’re connecting to localhost. We do this with the `--connect-to` option.

```console
$ docker-compose build
$ docker-compose up
$ curl --cacert example-com.crt --connect-to localhost -H 'Host: example.com' https://example.com/service/1
Hello from behind Envoy (service 1)! hostname: 56e8a5bff6bd resolvedhostname: 172.18.0.2
```

## Redirecting Insecure Traffic

We’re now serving TLS traffic in a narrow sense, but we’re not serving anything
on plain old HTTP/80, which would confuse most clients. We could duplicate our
routing configuration to serve both versions, but it’s better to redirect all
insecure traffic to the TLS version of our site. We can do this with a separate
listener and static routing configuration:

The whole thing looks like:

```yaml
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
            virtual_hosts:
            - name: backend
              domains:
              - "example.com"
              routes:
              - match:
                  prefix: "/"
                redirect:
                  path_redirect: "/"
                  https_redirect: true
          http_filters:
          - name: envoy.router
            config: {}
```

You can test this with curl, and it will return a 301:

```console
$ docker-compose build
$ docker-compose up
```

```console
$ curl -I -H 'Host: example.com' http://localhost/service/1
```

```shell
HTTP/1.1 301 Moved Permanently
location: https://example.com/
date: Fri, 25 May 2018 22:17:24 GMT
server: envoy
content-length: 0
```

That’s it, you’re done! The front-envoy.yaml file is included here:

```yaml
static_resources:
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
            virtual_hosts:
            - name: backend
              domains:
              - "example.com"
              routes:
              - match:
                  prefix: "/"
                redirect:
                  path_redirect: "/"
                  https_redirect: true
          http_filters:
          - name: envoy.router
            config: {}
  - address:
      socket_address:
        address: 0.0.0.0
        port_value: 443
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
              - "example.com"
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
      tls_context:
        common_tls_context:
          tls_certificates:
            - certificate_chain:
                filename: "/etc/example-com.crt"
              private_key:
                filename: "/etc/example-com.key"
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
admin:
  access_log_path: "/dev/null"
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 8001
```
