# Git Semantic Versioning Plugins

## Table Of Contents

- [Introduction](#introduction)
- [Installation](#installation)
- [Plugins](#plugins)
  - [Keep A Changelog](#keep-a-changelog)
  - [NPM package.json](#npm-package-json)
- [Contributing](#contributing)

## Introduction

git-semver can run its own plugins. These are self contained executable files that live under either:

- ./.git-semver/plugins        - Project plugins, added (and committed) to the git repository, to be run on just the current git project
- ${HOME}/.git-semver/plugins/ - User plugins, to be run on all git projects

Plugin can stop a tag being generated (for example if a version file does not exist).

See [Contributing](#contributing) for detail on creating a plugin or take a look at the [example plugin] or any of the [real plugins](#plugins).

## Installation

Plugins can be installed by copying them into `.git-semver/plugins/` in either the project or under the user's home directory.

## Plugins

### Keep A Changelog - [keepachangelog.sh]

A changelog is a file which contains a curated, chronologically ordered list of notable changes for each version of a project.

git-semver uses changelog convention from [Keep a CHANGELOG](http://keepachangelog.com). A changelog lists notable changes for each release of a project.

For a new version to be generated, a changelog must have already been commited which includes:

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
## [{{new version}}] - {{YYYY-MM-DD}}

### Added
- Details...

...

[unreleased]: https://github.com/oban/oban-site/compare/{{new version}}...HEAD
[{{new version}}]: https://github.com/oban/oban-site/compare/{{current version}}...{{version}}
```

See [Keep a CHANGELOG] for full details.

### NPM package.json - [npmpackagejson.sh]

The [package.json] file is used by [NPM], typically for [Node.js] applications, however can also be used in other projects where development tools (such as runners or builders like [Gulp] or [Grunt]) or languages like [CoffeeScript] or [SASS] are required.

package.json includes a version property, which npmpackagejson.sh will check:

``` json
{
   ...
   "version": "3.2.1",
   ...
}
```

## Contributing

A plugin can be any executable file stored in `.git-semver/plugins/`.

### Description

If the first parameter is `--about` then the plugin should print a one-line description of itself and exit 0.

### Parameters

The plugins must take the positional parameters:

1. version_new        - Version git-semver is attempting to add
2. version_current    - Current version the project is at (or blank if no version)
3. git_hash           - The current full SHA-1 hash
4. git_branch         - The current local branch
5. git_root           - The full path of the git project

All of none of these may be used.

### Exit codes

The plugin must exit with one of the codes:

- 0       - No error
- 111     - Warning: continue processing plugins and apply version
- 112     - Error: continue processing plugins (to allow other generated errors) but stop before applying version tag
- 113     - Fatal error: stop immediately

Any other code is ignored and will cause git-semver to continue processing plugins and apply a version.

### Output

Plugins can print anything to `stdout` or `stderr`. This will be formatted and displayed by git-semver.

### Pull requests

Please contribute your plugin by opening a pull request. See [CONTRIBUTING.md] for more details.

### Notes

Plugin format was borrowed from [Git hooks][Git hooks].

[CONTRIBUTING.md]: CONTRIBUTING.md
[CoffeeScript]: coffeescript.org
[example plugin]: plugins/example.sh
[Git hooks]: https://github.com/icefox/git-hooks
[Grunt]: http://gruntjs.com/
[Gulp]: http://gulpjs.com
[Keep a CHANGELOG]: http://keepachangelog.com/
[keepachangelog.sh]: plugins/keepachangelog.sh
[npmpackagejson.sh]: plugins/nopmpackagejson.sh
[Node.js]: https://nodejs.org/
[NPM]: https://www.npmjs.com/
[package.json]: http://browsenpm.org/package.json
[SASS]: http://sass-lang.com/
