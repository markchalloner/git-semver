# Git Semantic Versioning

## Table Of Contents

- [Introduction](#introduction)
- [Installation](#installation)
- [Plugins](#plugins)
  - [Keep A Changelog](#keep-a-changelog)
  - [NPM package.json](#npm-package-json)
- [Contributing](#contributing)

## Introduction

A git plugin to make adherance to [Semantic Versioning 2.0.0] easier, with its own plugin architecture for optional version management of:

- [Keep a Changelog][Keep a CHANGELOG] [CHANGELOG.md] file
- [NPM] [package.json] file
- ...

See [PLUGINS.md] for a description of plugins.

### Semantic versioning

[Semantic Versioning 2.0.0] is a scheme for versioning, which includes 3 parts e.g. ```3.2.1``` the components of which are:

  - Major: Used only for backward compatible breaking changes, i.e. when we have an all new theme etc.
  - Minor: Used for normal development, i.e. creating a new template
  - Bug fixes

## Installation

Via git clone.

The installer installs git-semver into the first of the following directories that exist and are in the path:

- /usr/local/bin
- /usr/bin
- /bin

In Linux, OSX and Windows Cygwin the installer will create a symlink. In Windows MinGW creates a stub instead.

``` bash
(git clone git@github.com:markchalloner/git-semver.git && \
cd git-semver && \
git checkout $(git tag | grep '^[0-9]\+\.[0-9]\+\.[0-9]\+$' | tail -n 1) && \
sudo ./install.sh)
```

The installer will not overwrite any existing [configuration](#configuration).

## Usage

### Get latest version tag

``` bash
git semver get
```

Will return empty if no version has been created.

### Create a new version tag

Versions are created as tags and are generated using:

``` bash
git semver [major|minor|patch|next]
```

#### Patch (Next)

Increment the patch component (0.1.0 -> 0.1.1)

``` bash
git semver patch|next
```

If no version has been created, the initial version will be: **0.1.0**

#### Minor

Increment the minor component (0.1.0 -> 0.2.0)

``` bash
git semver minor
```

If no version has been created, the initial version will be: **0.1.0**

#### Major

Increment the major component (0.1.0 -> 1.0.0)

``` bash
git semver major
```

If no version has been created, the initial version will be: **1.0.0**

### Update

See [Updates]

``` bash
git semver update
```

### Help

Run git semver with no arguments to see usage

``` bash
git semver [help]
```

## Configuration

Configuration is stored in the file `${HOME}/.git-semver/config`. An example configuration file with the default settings can be found at [config.example].

## Updates

The tool has a built in updater that checks for a new version of git semver

``` bash
git semver update
```

By default it will automatically check for a new version daily. The automatic check can be disabled by changing the [configuration](#configuration) setting:

``` bash
UPDATE_CHECK=0
```

The updaate check interval in days can be set by changing the [configuration](#configuration) setting:

``` bash
UPDATE_CHECK_INTERVAL_DAYS=1
```

The date of the last check is saved in `${HOME}/.git-semver/update`

## Uninstallation

### Automatically

Via uninstaller in clone directory. Navigate to your original clone directory and run:

``` bash
sudo git-semver/uninstall.sh [-p|--purge]
```

The purge switch will additionally remove the configuration directory.

### Manually

git-semver is installed by placing a symlink/stub in one of the bin directories in the path.

- ${HOME}/bin
- /usr/local/bin
- /usr/bin
- /bin

It can be deleted easily:

``` bash
sudo rm $(which git-semver)
```

The configuration directory can be removed with:

``` bash
rm -rf ${HOME}/.git-semver
```

## Changelog

Please see [CHANGELOG.md] for more information what has changed recently.

## Contributing

Please see [CONTRIBUTING.md] for details.

[CHANGELOG.md]: CHANGELOG.md
[Change Log Management]: http://keepachangelog.com/
[CONTRIBUTING.md]: CONTRIBUTING.md
[config.example]: config.example
[Keep a CHANGELOG]: http://keepachangelog.com/
[NPM]: https://www.npmjs.com/
[package.json]: http://browsenpm.org/package.json
[PLUGINS.md]: PLUGINS.md
[Semantic Versioning 2.0.0]: http://semver.org/spec/v2.0.0.html
