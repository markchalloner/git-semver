# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).
This file uses change log convention from [Keep a CHANGELOG](http://keepachangelog.com).

## [Unreleased][unreleased]

## [3.0.1] - 2018-07-13
### Fixed
- Incorrect statements in README.
- Shellcheck errors.

## Removed
- Unused helper functions and variables.

## [3.0.0] - 2018-07-13
### Added
- Support for the [XDG Base Directory Specification][xdg_basedirs]. Details:
  - Configuration will now prefer `$XDG_CONFIG_HOME/.git-semver/config` if it exists
  - Update files will now prefer `$XDG_DATA_HOME/.git-semver/update` if it exists
  - The previous values for both files are now used as a fallback. 
    Existing files under `$HOME/.git-semver/` will continue to work as long as 
    the `$XDG_*` paths do not exist.
- Support for installation to `$HOME/.local/bin/`.
- Version prefix config.
- Tag signing config.

### Fixed
- Make plugins executable and allow errors to be raised to user.

### Removed
- Built in updater. Updates can be done via a git pull.

## [2.0.2] - 2015-07-24
### Fixed
- More fixes to updater

## [2.0.1] - 2015-07-24
### Fixed
- Minor fixes to updater

## [2.0.0] - 2015-07-24
### Added
- New plugin architecture. Changelog validation is now disabled by default.

## [1.1.2] - 2015-07-22
### Fixed
- Moved disown to git-semver.sh
- Pull down tags on update check
- Optimise get version in setting
- Check if commit is on a branch befire outputting help on amending commits

## [1.1.1] - 2015-07-22
### Fixed
- Update now runs installer
- Workaround when writing stub to avoid permission errors

## [1.1.0] - 2015-07-07
### Added
- Update checks
- Ability to disable changelog checks
- Purge option to uninstaller to remove configuration files

### Fixed
- Installer symlink on MinGW

## [1.0.2] - 2015-07-06
### Fixed
- Bug in reading previous version from [CHANGELOG.md]
- Installer to use ~/bin first if possible

## [1.0.1] - 2015-06-08
### Added
- [CONTRIBUTING.md]
- Help for recommiting after change

### Fixed
- [README.md]
- Bugs in reading git origin
- Show all errors in one go
- More compatible with Windows (and possibly OSX)

## 1.0.0 - 2015-06-08
### Added
- Initial version
- Readme file with documentation [README.md]
- Licence file [LICENCE.md]
- Installer and uninstaller

[CHANGELOG.md]: CHANGELOG.md
[CONTRIBUTING.md]: CONTRIBUTING.md
[LICENCE.md]: LICENCE.md
[README.md]: README.md
[xdg_basedirs]: http://standards.freedesktop.org/basedir-spec/basedir-spec-latest.html

[unreleased]: https://github.com/markchalloner/git-semver/compare/3.0.1...HEAD
[3.0.1]: https://github.com/markchalloner/git-semver/compare/3.0.0...3.0.1
[3.0.0]: https://github.com/markchalloner/git-semver/compare/2.0.2...3.0.0
[2.0.2]: https://github.com/markchalloner/git-semver/compare/2.0.1...2.0.2
[2.0.1]: https://github.com/markchalloner/git-semver/compare/2.0.0...2.0.1
[2.0.0]: https://github.com/markchalloner/git-semver/compare/1.1.2...2.0.0
[1.1.2]: https://github.com/markchalloner/git-semver/compare/1.1.1...1.1.2
[1.1.1]: https://github.com/markchalloner/git-semver/compare/1.1.0...1.1.1
[1.1.0]: https://github.com/markchalloner/git-semver/compare/1.0.2...1.1.0
[1.0.2]: https://github.com/markchalloner/git-semver/compare/1.0.1...1.0.2
[1.0.1]: https://github.com/markchalloner/git-semver/compare/1.0.0...1.0.1
