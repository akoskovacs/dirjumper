# :rocket: dirjumper

Tired of typing long paths or hunting through `cd` history? **dirjumper** lets you bookmark any directory with a short alias and jump to it instantly from anywhere.

```sh
$ j apt          # jumps to /etc/apt/sources.list.d
$ j logs         # jumps to /var/log/nginx
$ j proj         # jumps to ~/projects/my-app
```

> The `upstream` branch contains the currently developed version, while the `master` branch holds the stable release.

---

## :clipboard: Table of Contents

- [:package: Installation](#package-installation)
- [:wrench: Usage](#wrench-usage)
  - [Add an alias](#heavy_plus_sign-adding-a-new-alias-for-the-current-directory)
  - [Jump](#zap-jumping)
  - [List aliases](#bar_chart-listing-out-the-aliases)
  - [Rename an alias](#pencil2-renaming-aliases)
  - [Delete an alias](#wastebasket-deleting-an-alias)
  - [Use in commands](#hammer_and_wrench-using-the-directory-in-a-regular-command)
  - [Upgrade / Downgrade](#fire-living-on-the-edge)
- [:open_file_folder: What is installed?](#open_file_folder-what-is-installed)
- [:gear: Configuration](#gear-configuration)
- [:blue_book: Quick reference](#blue_book-quick-reference)

---

## :package: Installation

**Requirements:** bash shell with read/write access to the current directory. `wget` or `curl` must be available.

Run one of the following in a writable directory:

**With wget:**
```sh
wget https://raw.githubusercontent.com/akoskovacs/dirjumper/master/dj.sh && bash dj.sh install && rm dj.sh
```

**With curl:**
```sh
curl -sSL https://raw.githubusercontent.com/akoskovacs/dirjumper/master/dj.sh > dj.sh && bash dj.sh install && rm dj.sh
```

The installer will set everything up and clean up after itself automatically.

> :information_source: **Windows:** This also works in GNU-type environments (e.g. Git Bash, WSL). If `~/.bashrc` does not exist yet, create it first:
> ```sh
> touch ~/.bashrc
> ```

---

## :wrench: Usage

### :heavy_plus_sign: Adding a new alias for the current directory

Navigate to the directory you want to bookmark, then add an alias:

```sh
$ cd /var/log/cups
$ j -a cu
```

The current directory is now bookmarked as `cu`.

### :file_folder: Adding an alias for an arbitrary directory

You can also bookmark any path without navigating to it first:

```sh
$ j -a apt /etc/apt/sources.list.d
```

### :zap: Jumping

```sh
$ j apt
$ pwd
/etc/apt/sources.list.d
$ j cu
$ pwd
/var/log/cups
```

### :bar_chart: Listing out the aliases

```sh
$ j
```

Output:

```
    cu   /var/log/cups
    apt  /etc/apt/sources.list.d
```

If your current working directory has a known alias, it will be preceded by a `+` sign and highlighted in green.

### :pencil2: Renaming aliases

```sh
$ j -r cu cps
$ j cps
$ pwd
/var/log/cups
```

### :wastebasket: Deleting an alias

```sh
$ j -d cps
```

And `cps` is forgotten forever. :cry:

### :hammer_and_wrench: Using the directory in a regular command

The `-g` flag returns the path for a given alias, making it easy to use in subshells:

```sh
$ ls $(j -g apt)                                     # list /etc/apt/sources.list.d
$ cat $(j -g apt)/official-package-repositories.list
```

### :fire: Living on the edge

dirjumper can upgrade and downgrade itself using the `-u` and `-w` options. Upgrading requires an internet connection and `wget`.

**Upgrading:**
```sh
$ j -u
[+] Checking for new version (current is v0.4.0)...
[+] New version (v10.5.0) found...
[?] Do you want to upgrade? [y/N]: y
    ...
```

**Downgrading (revoking an upgrade):**
```sh
$ j -w
[+] Sucessfully downgraded from '0.2.0' to '0.1.1'.
```

---

## :open_file_folder: What is installed?

The installer places the script in `$HOME/.config/.dirjumper/`, along with a `dj.list` file where your aliases are stored.

> :warning: These are **not** shell aliases — they are dirjumper's own alias list, stored in `dj.list`.

The installer also appends a small snippet to your `.bashrc`:

```sh
# <dirjumper>
source /home/akos/.config/.dirjumper/dj.sh
# </dirjumper>
```

The `<dirjumper>` tags act as markers so future versions can safely update the snippet without breaking your config.

---

## :gear: Configuration

The following environment variables can be set in your `.bashrc`, inside the dirjumper tags. Be aware that upgrading dirjumper may overwrite custom values placed there.

### `DIRJUMPER_ALIAS`

Changes the command used to invoke dirjumper. Default is `j`.

```sh
# <dirjumper>
export DIRJUMPER_ALIAS="go"   # use "go <alias>" instead of "j <alias>"
source /home/akos/.config/.dirjumper/dj.sh
# </dirjumper>
```

### `DIRJUMPER_COLOR`

Set to `0` to disable colored output. Any non-empty value other than `0` also disables colors.

```sh
# <dirjumper>
export DIRJUMPER_COLOR=0      # disable colors
source /home/akos/.config/.dirjumper/dj.sh
# </dirjumper>
```

---

## :blue_book: Quick reference

| Command | Description |
|---|---|
| `j <alias>` | Jump to the directory for `<alias>` |
| `j` | List all aliases |
| `j -a <alias>` | Bookmark the current directory as `<alias>` |
| `j -a <alias> <path>` | Bookmark `<path>` as `<alias>` |
| `j -r <old> <new>` | Rename an alias |
| `j -d <alias>` | Delete an alias |
| `j -g <alias>` | Print the path for `<alias>` (for use in scripts) |
| `j -u` | Upgrade to the latest version |
| `j -w` | Downgrade to the previous version |
