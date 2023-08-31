# Changelog
Custom Python Runtime

All notable changes to the runtime will be documented in this file. Versioning follows the format vX, where X is the version number.

## [Unreleased]

## [v9] - 2023-08-31
### Fixed
* Fix dev customization scripts not being run
* Fix package names in makefile
* Fix pylint-pydantic upgrading pydantic to unsupported version

## [v8] - 2023-08-28
### Fixed
* pydantic source install in devcontainer

## [v7] - 2023-08-26
### Changed
* Update default to python 3.11.5
### Added
* Dev build with development tools and utils, for devcontainer use

## [v6] - 2023-08-04
### Changed
* Change package architecture name to match uname output
### Added
* Add test for pip

## [v5] - 2023-08-02
### Added
* Add test for manifest file
### Fixed
* Fix arm64 test container launch

## [v4] - 2023-08-02
### Added
* ARM64 builds
### Changed
* Use cached build artifacts when possible to speed up overall build process

## [v3] - 2023-07-26
### Added
* Add basic tests

## [v2] - 2023-07-25
### Fixed
* Fix packages being installed to user instead of site

## [v1] - 2023-07-19
* Initial release
