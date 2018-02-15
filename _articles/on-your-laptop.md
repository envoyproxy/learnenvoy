---
layout: article
title: On Your Laptop
time_to_complete: 5 minutes
---

Before you run Envoy in a production setting, you likely want to take a tour of
its capabilities. In this article we'll walk through how to run Envoy on your
laptop, test proxy configurations, and observe results.

# Requirements

While you can
[build Envoy from source](https://www.envoyproxy.io/docs/envoy/v1.5.0/install/install),
the easiest way to get started is by using the official [docker images](https://hub.docker.com/u/envoyproxy/).
So before starting out, you'll need a
working [Docker install](https://docs.docker.com/install/). We'll also use the
[examples](https://github.com/envoyproxy/envoy/tree/master/examples) in the
Envoy source repository, which require a
working [git installation](https://help.github.com/articles/set-up-git/) as well
as [Docker Compose](https://docs.docker.com/compose/install/). Finally, to send
test traffic to your proxy you can either use your browser, or a command line
tool like [curl](https://curl.haxx.se/).

# Running Envoy
Running `docker run -it envoyproxy/envoy:latest /bin/bash` from a terminal
should launch you into a shell in an Envoy container. Envoy is available at 
`/usr/local/bin/envoy`, but without a config file it won't do anything very
interesting. Check out
the [Envoy source repository](https://github.com/envoyproxy/envoy) in a
terminal, and go to the `examples/front-proxy` directory. This contains
Dockerfiles, config files and a docker-compose manifest for setting up a very
simple proxy topology. A single front proxy is used to send traffic to two
different service backends.

The services run a very simple flask application, defined in `service.py`. An
Envoy runs in the same container as a sidecar, configured with the
`service-envoy.yaml` file. Finally, the `Dockerfile-service` is used to create a
container that runs Envoy and the service on startup.

The front proxy is simpler. It runs envoy, configured with the
`front-envoy.yaml` file, and uses `Dockerfile-frontenvoy` as its container
definition.

The `docker-compose.yaml` file provides a description of how to build, package
and run the front proxy and services together. Running `docker-compose up
--build -d` (build containers, then run them in detached mode) will build our
containers, then start a single instance of the front proxy and two service
instances, one configured as "service1" and the other as "service2".

Running `docker-compose ps` should show the following output

```terminal
$ docker-compose ps
          Name                        Command               State                      Ports                    
----------------------------------------------------------------------------------------------------------------
frontproxy_front-envoy_1   /bin/sh -c /usr/local/bin/ ...   Up      0.0.0.0:8000->80/tcp, 0.0.0.0:8001->8001/tcp
frontproxy_service1_1      /bin/sh -c /usr/local/bin/ ...   Up      80/tcp                                      
frontproxy_service2_1      /bin/sh -c /usr/local/bin/ ...   Up      80/tcp         
```

You can log into a bash shell on a machine by using docker-compose as well

```terminal
$ docker-compose exec front-envoy /bin/bash
root@4bae7506fa03:/# 
```

# Sending Traffic

Docker-compose has mapped port 8000 on the front-proxy to your local
network. Open your browser to http://localhost:8000/service/1, or run `curl
localhost:8000/service/1`. You should see

```terminal
$ curl localhost:8000/service/1
Hello from behind Envoy (service 1)! hostname: 6632a613837e resolvedhostname: 172.19.0.3
```

Going to http://localhost:8000/service/2 should result in 

```terminal
$ curl localhost:8000/service/2
Hello from behind Envoy (service 2)! hostname: bf97b0b3294d resolvedhostname: 172.19.0.2
```

You're connecting to Envoy, operating as a front proxy, which is in turn sending
your request to service 1 or service 2.

# Configuring Envoy

Let's take a look at how Envoy is configured. Inside the `docker-compose.yaml`
file you'll see the following definition for the front-envoy service

```yaml
  front-envoy:
    build:
      context: ../
      dockerfile: front-proxy/Dockerfile-frontenvoy
    volumes:
      - ./front-envoy.yaml:/etc/front-envoy.yaml
    networks:
      - envoymesh
    expose:
      - "80"
      - "8001"
    ports:
      - "8000:80"
      - "8001:8001"
```

Going from top to bottom, this says
  1. build a container using the Dockerfile-frontenvoy file located in the
  current directory
  2. mount the front-envoy.yaml file in thi sdirectory as /etc/front-envoy.yaml
  3. use the envoymesh network for this container
  4. expose ports 80 (for general traffic) and 8001 (for the admin server)
  5. map the host port 8000 to container port 80, and the host port 8001 to
  container port 8001
  
Knowing that our front proxy uses the front-envoy.yaml file, let's take a deeper
look. Our file has two top level elements, `static_resources` and `admin`.

```yaml
static_resources:
admin:
```

The `admin` block is relatively simple.

```yaml
admin:
  access_log_path: "/dev/null"
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 8001
```

The `access_log_path` field is set to /dev/null, meaning access logs to the
admin server are discarded. The `address` object tells Envoy to create an admin
server listening on port 8001.

The `static_resources` block contains definitions for clusters and listeners
that aren't dynamically managed. The `admin` block configures our admin
server.

Our front proxy has a single listener, configured to listen on port 80, with an
HTTP filter chain.

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
```

Within our http connection manager filter configuration there is a definition
for a single virtual host, configured to accept traffic for all domains.

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

Routes are configured here, mapping traffic for `/service/1` and `/service/2` to
the appropriate clusters.

Next come static cluster definitions

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

You can configure timeouts, circuit breakers, discovery settings and more on
clusters. In this example endpoints are discovered with DNS.

# Modifying Configuration

You can modify the config files, rebuild docker images, and test the changes. To
add access logging to your HTTP filter, add the `access_log` object to your
filter config, as shown here.

```yaml
    - filters:
      - name: envoy.http_connection_manager
        config:
          codec_type: auto
          stat_prefix: ingress_http
          access_log:
            - name: envoy.file_access_log
              config:
                path: "/var/log/access.log"
          route_config:
```

Destroy your docker-compose stack with `docker-compose down`, then rebuild it
with `docker-compose up --build -d`. Make a few requests to your services using
curl, then log into a shell with `docker-compose exec front-envoy /bin/bash`. An
access.log file should be in /var/log, showing the results of your requests.

# Admin Server

An often overlooked feature of Envoy is the built in admin server. If you open
your browser to `http://localhost:8001` you should see a page with links to more
information. The `/clusters` endpoint shows statistics on upstream clusters, and
the `stats` endpoint shows more general statistics. You can get information
about the server build at `/server_info`, query and alter logging levels at
`/logging`, and more. General help is available at the `/help` endpoint.

# Further Exploration

If you're interested in exploring more of Envoy's capabilities,
the [Envoy examples](https://github.com/envoyproxy/envoy/tree/master/examples)
have more complex topologies that will get you slightly more real world, but
still statically discovered examples. When you're comfortable with these,
the [routing examples](./routing.html) are a good introduction into Envoy's more
advanced traffic management capabilities.

If you'd like to learn more about how to operate Envoy in a production setting,
the
[service discovery integration](./service-discovery.html),
[front proxy](./front-proxy.html), and [service mesh](./service-mesh.html)
articles walk through what it means to integrate Envoy with your existing environment.


