# Git Semantic Versioning Plugins

## Table Of Contents

- [Introduction](#introduction)
- [Installation](#installation)
- [Plugins](#plugins)
  - [Keep A Changelog](#keep-a-changelog---keepachangelogsh)
  - [NPM `package.json`](#npm-packagejson---npmpackagejsonsh)
- [Contributing](#contributing)

## Introduction

git-semver can run its own plugins. These are self contained executable files that live under either:


Location                        | Contains
------------------------------- | ------------------------
`./.git-semver/plugins`         | Project plugins (added and committed) which run on just the current git project
`${HOME}/.git-semver/plugins/`  | User plugins which run on all git projects                

Plugins are executed orderedly, so you can number-prefix them to ensure execution order. Number prefixed plugins will run before anything else, and they will be executed from lower to higher. Plugins can also stop a tag being generated (for example if a version file does not exist).

See [Contributing](#contributing) for detail on creating a plugin or take a look at the [example plugin] or any of the [real plugins](#plugins).

## Installation

Plugins can be installed by copying them into `.git-semver/plugins/` in either the project or under the user's home directory.

## Plugins

### Keep A Changelog - [`keepachangelog.sh`]

A changelog is a file which contains a curated, chronologically ordered list of notable changes for each version of a project.

git-semver uses changelog convention from [Keep a CHANGELOG](http://keepachangelog.com). A changelog lists notable changes for each release of a project.

For a new version to be generated, a changelog must have already been commited which includes:

- Details of the version (including _version number_ and _date_)
- A list of changes under one or more of the headings:
  - **Added** for new features.
  - **Changed** for changes in existing functionality.
  - **Deprecated** for once-stable features removed in upcoming releases.
  - **Removed** for deprecated features removed in this release.
  - **Fixed** for any bug fixes.
  - **Security** to invite users to upgrade in case of vulnerabilities.
- An updated **unreleased** link at the bottom of the file
- A version link at the bottom of the file

``` markdown
## [{{new version}}] - {{YYYY-MM-DD}}

### Added
- Details...

...

[unreleased]: https://github.com/oban/oban-site/compare/{{new version}}...HEAD
[{{new version}}]: https://github.com/oban/oban-site/compare/{{current version}}...{{version}}
```

See [Keep a CHANGELOG] for full details.

### NPM `package.json` - [`npmpackagejson.sh`]

The [`package.json`] file is used by [NPM], typically for [Node.js] applications, however can also be used in other projects where development tools (such as runners or builders like [Gulp] or [Grunt]) or languages like [CoffeeScript] or [SASS] are required.

`package.json` includes a version property, which `npmpackagejson.sh` will check:

``` json
{
   ...
   "version": "3.2.1",
   ...
}
```

### Major and minor tags - [`90-major_and_minor_tag.sh`]

This plugins creates 2 extra tags each time you `git-semver major` or `git-semver minor`, one with the minor version and other with the major one.

In other words, if you create a `3.0.0` version, this plugin will also create a `3.0` and `3` tag. Also, if you create a `3.1.0` tag, it will delete the previously created `3` tag, and create it again pointing to the `3.1.0` commit, together with a brand new `3.1` tag.

This is useful, for example, to maintain multiple versions of an API: If you have a legacy version `1.5.3` API you need to maintain, and a new version `2`, you can use this plugin to maintain a "rolling" `1.5` tag, and always deploy the latest bugfix for your legacy API, and maybe build against a `2` tag for the new one, to get the latest features.

### Python `setup.py` - [`setuppy_update.sh`]

This plugin makes sure you never forget to update your package version.

When active, it will search for a setup.py file in the root of the project, and change the `version` argument passed to the setup class to the version being tagged. Then, it will commit it with a "Updated setup.py version" message.

## Contributing

A plugin can be any executable file stored in `.git-semver/plugins/`.

### Description

If the first parameter is `--about`, then the plugin should print a one-line description of itself, and exit `0`.

### Parameters

The plugins must take the positional parameters:

Parameter             | Value
--------------------- | -------------------------
`version_new`         | Version git-semver is attempting to add
`version_current`     | Current version the project is at (or blank if no version)
`git_hash`            | The current full SHA-1 hash
`git_branch`          | The current local branch
`git_root`            | The full path of the git project

All or none of these may be used.

### Exit codes

The plugin must exit with one of the codes:

Exit Code   | Meaning
---------   | -------
`0`         | No error
`111`       | Warning: continue processing plugins and apply version
`112`       | Error: continue processing plugins (to allow other generated errors) but stop before applying version tag
`113`       | Fatal error: stop immediately

Any other codes are ignored, and will cause git-semver to continue processing plugins and apply a version.

### Output

Plugins can print anything to `stdout` or `stderr`. This will be formatted and displayed by git-semver.

### Pull requests

Please contribute your plugin by opening a pull request. 

See [CONTRIBUTING.md] for more details.

### Notes

Plugin format was borrowed from [Git hooks][Git hooks].

[CONTRIBUTING.md]:      CONTRIBUTING.md
[CoffeeScript]:         http://coffeescript.org
[example plugin]:       plugins/example.sh
[Git hooks]:            https://github.com/icefox/git-hooks
[Grunt]:                http://gruntjs.com
[Gulp]:                 http://gulpjs.com
[Keep a CHANGELOG]:     http://keepachangelog.com
[`keepachangelog.sh`]:  plugins/keepachangelog.sh
[`npmpackagejson.sh`]:  plugins/nopmpackagejson.sh
[Node.js]:              https://nodejs.org
[NPM]:                  https://www.npmjs.com
[`package.json`]:       http://browsenpm.org/package.json
[SASS]:                 http://sass-lang.com

