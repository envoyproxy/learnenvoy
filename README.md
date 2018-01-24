# LEARN ENVOY

## Prerequisites

### Git-lfs

Before cloning the repo, you'll need to [install git-lfs](https://git-lfs.github.com/).
Otherwise you won't be able to see any of the images.

### Ruby

Jekyll is built with ruby. There are many ways to install ruby on a
mac. Pick the one that is least infuriating to you. Using homebrew is a
fine answer. You'll also need gems (installed with ruby if you're
using homebrew) and bundler, because how else are you going to gem
up your gems.

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

## Building the site

To serve the site for local development, run

```
jekyll serve
```

Then go to http://localhost:4000

To build the site for distribution run

```shell
jekyll build
```

And gizp or whatever all the stuff in `_site`.

## Site Layout

TBD

## Pull Requests
