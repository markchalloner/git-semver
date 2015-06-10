# Git Semver Plugin

## Introduction

A git plugin to make adherance to 

- [Semantic Versioning 2.0.0]
- [Change Log Management]

easier.

Git semvar requires a [CHANGELOG] file to be maintained. This will be need be filled for the version before the version is created.

### Semantic versioning

[Semantic Versioning 2.0.0] is a scheme for versioning, which includes 3 parts e.g. ```3.2.1``` the components of which are:

  - Major: Used only for backward compatible breaking changes, i.e. when we have an all new theme etc.
  - Minor: Used for normal development, i.e. creating a new template
  - Bug fixes

### Change log

A change log is a file which contains a curated, chronologically ordered list of notable changes for each version of a project.

git-semvar uses change log convention from [Keep a CHANGELOG](http://keepachangelog.com). A change log lists notable changes for each release of a project.

For a new version to be generated, a change log must have already been commited which includes:

- Details of the version (including version number and, date)
- A list of changes under one or more of the headings:
  - Added for new features.
  - Changed for changes in existing functionality.
  - Deprecated for once-stable features removed in upcoming releases.
  - Removed for deprecated features removed in this release.
  - Fixed for any bug fixes.
  - Security to invite users to upgrade in case of vulnerabilities.
- An updated unreleased link at the bottom of the file
- A version link at the bottom of the file

``` markdown
## [{{version}}] - {{YYYY-MM-DD}}

### Added
- Details...
...
[unreleased]: https://github.com/oban/oban-site/compare/{{version}}...HEAD
[{{version}}]: https://github.com/oban/oban-site/compare/{{previous version}}...{{version}}
```

See [Keep a CHANGELOG] for full details.

## Installation

Via git clone. The installer creates a symlink at /usr/local/bin/git-semvar:

``` bash
git clone git@github.com/markchalloner/git-semvar.git
sudo git-semvar/install.sh
```

## Usage

### Get latest version tag

``` bash
git semvar get
```

Will return empty if no version has been created.

### Create a new version tag

Versions are created as tags and are generated using:

``` bash
git semvar [major|minor|patch|next]
```

#### Patch (Next)

Increment the patch component (0.1.0 -> 0.1.1)

``` bash
git semvar patch|next
```

If no version has been created, the initial version will be: **0.1.0**

#### Minor

Increment the minor component (0.1.0 -> 0.2.0)

``` bash
git semvar minor
```

If no version has been created, the initial version will be: **0.1.0**

#### Major

Increment the major component (0.1.0 -> 1.0.0)

``` bash
git semvar major
```

If no version has been created, the initial version will be: **1.0.0**

### Help

Run git semvar with no arguments to see usage

``` bash
git semvar [help]
```

## Updates

Updates can be pulled down from github. Navigate to your original clone directory and run:

``` bash
git pull
```

## Uninstallation

Via uninstaller in clone directory. Navigate to your original clone directory and run:

``` bash
sudo git-semvar/uninstall.sh
```

Manually

git-semver is installed by placing a symlink in /usr/local/bin. This can be deleted easily:

``` bash
sudo rm /usr/local/bin/git-semver
```

## Change log

Please see [CHANGELOG] for more information what has changed recently.

## Contributing

Please see [CONTRIBUTING] for details.

[CHANGELOG]: CHANGELOG.md
[CONTRIBUTING]: CONTRIBUTING.md
[Semantic Versioning 2.0.0]: http://semver.org/spec/v2.0.0.html
[Change Log Management]: http://keepachangelog.com/
[Keep a CHANGELOG]: http://keepachangelog.com/
