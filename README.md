# dirjumper

Jump easly between frequently used directories, by bookmarking them with short aliases. The `upstream` branch contains
the currently developed version, while the `master` branch holds the stable release.
# Download and install
Only a bash shell is needed. The current directory has to have read and write rights. Copy and execute one of these commands in your bash shell:
``` sh
wget https://raw.githubusercontent.com/akoskovacs/dirjumper/master/dj.sh && bash dj.sh install
```
or, with curl
``` sh
curl -sSL https://raw.githubusercontent.com/akoskovacs/dirjumper/master/dj.sh && bash dj.sh install
```

The downloaded script will be removed automatically from the current directory after the installation is completed.
# Usage
## Adding a new alias for the current directory
``` sh
$ cd /var/log/cups
$ j -a cu
```
The current directory is now available with the alias 'cu'.

## Adding an arbitrary directory (from anywhere)
``` sh
$ j -a apt /etc/apt/sources.list.d
```
## Jumping
``` sh
$ j apt
$ pwd
/etc/apt/sources.list.d
$ j cu
$ pwd     
/var/log/cups
```
## Listing out the aliases
``` sh
$ j 
```
You will get this output:

``` sh
    cu   /var/log/cups
    apt  /etc/apt/sources.list.d
```
If your working directory has a known alias it will be preceded with a plus `+` sign
 and its alias will be green.
## Renaming aliases
``` sh
$ j -r cu cps
$ j cps
$ pwd
/var/log/cups
```
## Deleting an alias
``` sh
$ j -d cps
```
And 'cps' is forgotten forever. :(

## Using the directory in a regular command
``` sh
$ ls $(j -g apt) # listing /etc/apt/sources.list.d
$ cat $(j -g apt)/official-package-repositories.list
```

## Living on the edge
The script can automatically upgrade and downgrade itself using the `-u` and `-w` 
options respectively. For upgrades you have to have (of course) a stable internet 
connection and `wget`.

### Upgrading
``` sh
$ j -u
[+] Checking for new version (current is v0.4.0)...
[+] New version (v10.5.0) found...
[?] Do you want to upgrade? [y/N]: y
    ...
```
### Downgrading (revoking upgrades)
``` sh
$ j -w
[+] Sucessfully downgraded from '0.2.0' to '0.1.1'.
```

# What is installed?
By default, the script copies itself to the `$HOME/.config/.dirjumper`. The `.dirjumper`
directory contains the script and the `dj.list` file 
where the aliases are assigned. *These are not to be confused with shell aliases, which are a built-in way for aliasing commands.*

The script also appends some code to the `.bashrc`. Some distributions might rewrite
this rc script. The appended snippet usually looks like this:
```sh
# <dirjumper>
source /home/akos/.config/.dirjumper/dj.sh
# </dirjumper>
```
The dirjumper "tags" are used as separators, so later versions
could safely modify its inner contents.

# Configuration
You have some limited configuration options in the current version of
`dirjumper`.

These could be set from your `.bashrc` file, practically between
the aformentioned "tags". This is not required though and a later
version could potentially overwrite your settings so be awera of that.

`$DIRJUMPER_ALIAS` is provided to set the alias used to interface
with the script. By default this is `j` for jump.

```sh
# <dirjumper>
export $DIRJUMPER_ALIAS="go" # go <alias> could be used
source /home/akos/.config/.dirjumper/dj.sh
# </dirjumper>
```

`$DIRJUMPER_COLOR` could be set to 0 in order to disable output coloring. The default value is `''` (empty string). **As of now any
other value will disable output coloring.**

```sh
# <dirjumper>
export $DIRJUMPER_COLOR=0 # disable colors
source /home/akos/.config/.dirjumper/dj.sh
# </dirjumper>
```
