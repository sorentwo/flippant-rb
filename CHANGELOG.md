## v0.6.0 - 2017-08-08

### Changes

* [Flippant] - Allow passing symbols to disable a feature.
* [Flippant] - Raise an error when enabling a feature for a group that doesn't
  exist. This forces an order of defining groups before enabling features, but
  it will prevent trying to register groups that don't exist or with typos.

## v0.5.1 - 2017-01-26

### Changes

* [Flippant::Adapter::Redis] - Constructor uses keyword arguments.

## v0.5.0 - 2017-01-24

* Initial release, largely ported from sorentwo/flippant, the Elixir version.
