# toml decoder

A d toml decoder for [toml-test](https://github.com/BurntSushi/toml-test).

## Usage
Install toml-test
```
$ git clone https://github.com/BurntSushi/toml-test.git
$ cd toml-test
$ go build ./cmd/toml-test
```

Compile `toml_decoder`
```
$ cd toml_decoder
$ make // or
$ ninja
```
In order to generate `makefile` with [reggae](https://github.com/atilaneves/reggae/blob/master/doc/export.md)
```
$ reggae --export
```

copy `dtoml-dec` into `toml-test` and
```
$ toml-test toml-decoder
```
