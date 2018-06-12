---
layout: article
title: Getting Help
description: >
  Trying to debug Envoy and need more information? Learn how to get more
  data out of Envoy and the best places to ask for help!
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

[//]: # (Getting Help)

## How to Get More Information

To enable debug logging for Envoy, send the following request to
the admin interface, which is included in the bootstrap, or
configured separately in the case of a custom xDS configuration.

`GET /logging`

You can also pass these flags to the Envoy binary:

```console
-l <string>, --log-level <string> --log-path <path string>
```

It will set both the log level, and the path in which your logs
are stored.

## How to Get Help

The Envoy community is active, and lives on Github, as well as
several mailing lists, and a Slack team. Find out more by
visiting
[the contact section](https://github.com/envoyproxy/envoy#contact)

When talking to other users and maintainers on Slack, be sure to
clearly identify your issues, the steps you've attempted to
remedy each one, and provide any pertinent logs. As a very
developer-friendly environment, help abounds. The other users
you will encounter are at a variety of experience levels with
Envoy, but everyone wants to collaborate to make Envoy better.
Have fun with it.
