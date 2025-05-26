# Memento

**Memento** is a simple version control system written in Zig.  
This is a **personal study project**—I built it on my own to learn how VCSs work, not for production use.

## Features

Currently, Memento supports the following commands:

- `init` — Initialize a new repository
- `add` — Add files to the staging area
- `commit` — Commit staged changes

## Installation

To build and use Memento locally, you'll need:

- [Zig](https://ziglang.org/download/) (tested with version 0.14.0 or newer)
- A POSIX-compliant system (Linux, macOS, or WSL on Windows)

### Build Locally

```sh
git clone https://github.com/yourusername/memento.git
cd memento
zig build -Drelease-fast
```

The compiled binary will be at:

```
./zig-out/bin/memento
```

You can move it into your `$PATH`:

```sh
cp ./zig-out/bin/memento ~/.local/bin/
```

### Install via Homebrew

> [!WARNING]
> Soon

```sh
brew tap pmqueiroz/tap
brew install pmqueiroz/tap/memento
```

## Configuration

Memento doesn’t require any global config. Each repo is self-contained in a
`.memento/` directory.

Repo config options go in `.memento/config`.

## Usage

Run `memento <command>` in your terminal:

### `init`

```sh
memento init
```

Creates a `.memento/` directory with internal metadata.

---

### `add <file> [...]`

```sh
memento add file.txt other.txt
```

Stages files for the next commit.

---

### `commit -m "<message>"`

```sh
memento commit -m "Initial commit"
```

Commits all staged changes with your message.

---
