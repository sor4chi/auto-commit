# Git Auto Commit

This is a simple script that will automatically commit and push your changes to your git repository.

## Dependencies

- git
- bash
- curl
- jq

Mainly, "jq" is the only dependency that is not installed by default on most systems. so you need to install it first.

https://stedolan.github.io/jq/

## Usage

1. Clone this repository
2. `./install.sh` to run the script

### Optional

how to uninstall:

```bash
./uninstall.sh
```

## How it works
this script will work as git subcommand, so you can use it like this:

```bash
git auto-commit

# optional arguments
git auto-commit ja # 日本語でコミットメッセージを作成
```

## License

[MIT](./LICENSE)
