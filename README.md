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

[//]: # (LearnEnvoy)

# LearnEnvoy

[LearnEnvoy](https://learnenvoy.io) is a community content site that helps
organizations get the most out of the
[Envoy proxy](https://envoyproxy.github.io).

The goal of LearnEnvoy is to help developers go from "hey, Envoy sounds
powerful" to a fully-functional production deployment.

The content is based on real production deployments, successes and failures, and
interviews with teams running Envoy at scale. The guides cover everything from
the configuration basics to strategies for distributed system resilience.

## Project Background

LearnEnvoy was originally developed at [Turbine
Labs](https://www.turbinelabs.io). It was started based on the experiences
building [Houston](https://www.turbinelabs.io/product), a control plane,
management UI, and observability platform for Envoy.

We open-sourced this site because we know we're not always right, and even if we
are, Envoy and its best practices are evolving faster than any single
organization can keep up. Feel free to fork it, edit it, share it with others,
and contribute back to it.

## Contributing

Want to contribute a change? Great! Here are a few ways you can jump in:

 - Be sure to read our [Code of Conduct](CODE_OF_CONDUCT.md)
 - Browse our [open issues](https://github.com/turbinelabs/learnenvoy/issues)
 - Suggest a new section or area for improvement by
   [opening an issue](https://github.com/turbinelabs/learnenvoy/issues/new)

If you're running Envoy at your company and want your success story told, send
an email to hello@turbinelabs.io. We'd love to interview you and post your
experience on the site.

## Running LearnEnvoy.io

### Prerequisites

#### Git-lfs

Before cloning the repo, you'll need to [install git-lfs](https://git-lfs.github.com/).
Otherwise you won't be able to see any of the images.

#### Ruby

Jekyll is built with ruby. There are many ways to install ruby on a
mac. Pick the one that is least infuriating to you. Using homebrew is a
fine answer. You'll also need gems (installed with ruby if you're
using homebrew) and bundler, because how else are you going to gem
up your gems. Then we wrap it all with make because we have to hoist some
javascript out of the gems directory. It's beautiful.


```shell
brew install ruby
gem install bundler
```

then verify you have reasonably modern versions

```shell
> ruby -v
ruby 2.4.0p0 (2016-12-24 revision 57164) [x86_64-darwin16]
> bundle -v
Bundler version 1.14.6
```

Now, from within this project directory run

```shell
bundle
```

To make sure your Gems are packaged up correctly for running jekyll

### Building the site

To serve the site for local development, run

```
make serve
```

Then go to http://localhost:4000

To build the site for distribution run

```shell
make build
```

And gizp or whatever all the stuff in `_site`.

## Site Architecture

### Theme

We use the [agency theme](https://github.com/y7kim/agency-jekyll-theme) for the
site. Styling overrides are in `assets/main.scss` and in the `_sass`
directory. We have copied all of the scss assets from the gem, so we shouldn't
have to worry about order of application from the gem and our thing (non-gem
files _should_ take precedence)

### Topics

The main page is organized along a series of topics. Topics are defined in four
places (gross).

1. `_includes/nav.html` defines the topmost nav. Each section needs an entry
   here
2. `_layouts/main.html` has an include for each topic
3. `_includes/<topic>.html` controls rendering for the topic
4. `_data/<topic>.yaml` provides a structured "database" of entries in a topic

### Articles

If an item in `_data/<topic>.yaml` contains an `article` field, jekyll will look
for a corresponding markdown file in the `_articles` subdirectory. Articles are
rendered with the layout in `_layouts/article.html`. see
`_data/getting-started.yaml` for a _very_ slim example for the 'on your laptop'
article.
