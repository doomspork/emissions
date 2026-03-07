# Changelog

## [0.2.0](https://github.com/doomspork/emissions/compare/emissions-v0.1.0...emissions-v0.2.0) (2026-03-07)


### Features

* add 9 guide pages with nested Phoenix Channels adapter ([#8](https://github.com/doomspork/emissions/issues/8)) ([5ffbbf5](https://github.com/doomspork/emissions/commit/5ffbbf5d3c926cbd7e881c5659f2f98469a8570d))
* add core types, behaviours, and topic router ([22eef40](https://github.com/doomspork/emissions/commit/22eef40df757897fc9c90dec309fbaca0b0cdb77))
* add GenStage delivery pipeline with adapter consumers ([8197afb](https://github.com/doomspork/emissions/commit/8197afba5a846b71ad1694d9ae0c72aff3a858c5))
* add handler dispatcher for internal event processing ([2ee5667](https://github.com/doomspork/emissions/commit/2ee5667750ad324b58205296f5da73882b1e24f6))
* add multi-tenant scoping to PubSubAdapter ([#9](https://github.com/doomspork/emissions/issues/9)) ([c84697e](https://github.com/doomspork/emissions/commit/c84697e280dc5f7fac4b82a52a2d12c2ff5ca632))
* add optional Plug for automatic buffer lifecycle ([#6](https://github.com/doomspork/emissions/issues/6)) ([cb40894](https://github.com/doomspork/emissions/commit/cb408941195d5827ded08d5cee3f5e1fe4f917b0))
* add per-request event buffer system ([7027a5c](https://github.com/doomspork/emissions/commit/7027a5c7c8d7b82f396c6938559b0e9947507022))
* add Phoenix Channels adapter for real-time event delivery ([#7](https://github.com/doomspork/emissions/issues/7)) ([08ff8fc](https://github.com/doomspork/emissions/commit/08ff8fc4e7b0732978f387b6ca7892387040331f))
* add pluggable serializers as core adapter concern ([#10](https://github.com/doomspork/emissions/issues/10)) ([2b1b982](https://github.com/doomspork/emissions/commit/2b1b9825a3f1d5c8519e2ce81ccc5f20304013ec))
* add public API, application supervisor, and telemetry ([a12c7a2](https://github.com/doomspork/emissions/commit/a12c7a27f1ceedecc1cd542db19516b03413d3de))
* add test helpers and test adapter ([52a826f](https://github.com/doomspork/emissions/commit/52a826f091a3d42d9d8eddd7bc923579b4901cd8))
* scaffold emissions library with dependencies ([4b8bc4b](https://github.com/doomspork/emissions/commit/4b8bc4b7145081655d33fb462bc26b09b035f608))


### Bug Fixes

* address Copilot review feedback ([7b9a719](https://github.com/doomspork/emissions/commit/7b9a7193eac9b43c99e464780dd99a74bed6c936))
* address review findings across pipeline, buffer, and event modules ([05d9c62](https://github.com/doomspork/emissions/commit/05d9c62ff30a916f667cd7fd339a1bc8d796ab96))
