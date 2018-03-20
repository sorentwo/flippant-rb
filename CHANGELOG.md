## v0.9.0 2018-03-20

### Enhancements

* [Flippant] - Add a new Postgres adatper, backed by PG and ActiveRecord pools.
* [Flippant] - Add `setup` to facilitate adapter setup (i.e. Postgres).
* [Flippant] - Modify `enable` and `disable` to prevent duplicate values and
  operate atomically without a transaction.
* [Flippant] - Add `dump/1` and `load/1` functions for backups and portability.

### Changes

* [Flippant::Adapter] - Values are no longer guaranteed to be sorted. Some
  adapters guarantee sorting, but race conditions prevent it in the Postgres
  adapter, so it is no longer guaranteed.

## v0.6.0 2017-08-08

### Enhancements

* [Flippant] - Merge additional values when enabling features. This prevents
  clobbering existing values in "last write wins" situations.
* [Flippant] - Support enabling or disabling of individual values. This makes it
  possible to remove a single value from a group's rules.
* [Flippant] - Add `rename/2` for renaming existing features.
* [Flippant] - Add `exists?/1` for checking whether a feature exists at all,
  and `exists?/2` for checking whether a feature exists for a particular group.

### Changes

* [Flippant] - Allow passing symbols to disable a feature.
* [Flippant] - Raise an error when enabling a feature for a group that doesn't
  exist. This forces an order of defining groups before enabling features, but
  it will prevent trying to register groups that don't exist or with typos.

## v0.5.1 2017-01-26

### Changes

* [Flippant::Adapter::Redis] - Constructor uses keyword arguments.

## v0.5.0 2017-01-24

* Initial release, largely ported from sorentwo/flippant, the Elixir version.
