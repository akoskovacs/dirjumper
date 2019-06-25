#!/bin/bash

# ------------------------------------------------------------------
# Copyleft (C) Ákos Kovács - 2019
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# ------------------------------------------------------------------

## You can set the alias used by the script by defining the environment variable $DIRJUMPER_ALIAS
if [[ $DIRJUMPER_ALIAS = '' ]]; then
    DIRJUMPER_ALIAS='j'
fi
alias $DIRJUMPER_ALIAS='dirjumper'

## You can disable coloring by:
#export $DIRJUMPER_COLOR=1

if [[ $DIRJUMPER_COLOR = '' ]]; then
    COLOR_RED="\x1b[31m"
    COLOR_BLUE="\x1b[34m"
    COLOR_BBLUE="\x1b[1;34m"
    COLOR_PURPLE="\x1b[35m"
    COLOR_BPURPLE="\x1b[1;35m"
    COLOR_GREEN="\x1b[32m"
    COLOR_BGREEN="\x1b[1;32m"
    COLOR_YELLOW="\x1b[33m"
    COLOR_GRAY="\x1b[30m"
    COLOR_LGRAY="\x1b[37m"
    COLOR_END="\x1b[0m"
fi

## Shell init file
SH_RC_FILE=".bashrc"
## Home configuration directory under ~
CONFDIR=".config"

DJEXE="dj.sh"
DJFILE="dj.list"

DJDIR=".dirjumper"
DJPATH="$HOME/$CONFDIR/$DJDIR"

DJLIST="$DJPATH/$DJFILE"
DJBIN="$DJPATH/$DJEXE"

VERSION="0.4.1"

function dirjumper () {
    ## Stable, main update server
    local REPO="https://raw.githubusercontent.com/akoskovacs/dirjumper/master"

    ## Uncomment for upstream updates
    #local REPO="https://raw.githubusercontent.com/akoskovacs/dirjumper/upstream"

    ## Uncomment for local debugging
    #local REPO="http://localhost:8000"

    local OPTIND optname

    print_examples () {
        echo -e "Example usage:"
        echo -e "$COLOR_GREEN $ $DIRJUMPER_ALIAS -a ex\t\t\t\t$COLOR_LGRAY# bookmarks the current directory as 'ex'$COLOR_END"
        echo -e "$COLOR_GREEN $ $DIRJUMPER_ALIAS ex\t\t\t\t\t$COLOR_LGRAY# changes the directory to the bookmared 'ex' previously$COLOR_END"
        echo -e "$COLOR_GREEN $ $DIRJUMPER_ALIAS -a ex /usr/lib/example\t\t$COLOR_LGRAY# bookmarks '/usr/lib/example' as 'ex'$COLOR_END"
        echo -e "$COLOR_GREEN $ $DIRJUMPER_ALIAS -r ex e\t\t\t\t$COLOR_LGRAY# renames the alias 'ex' to 'e'$COLOR_END"
        echo -e "$COLOR_GREEN $ $DIRJUMPER_ALIAS -d e\t\t\t\t$COLOR_LGRAY# delete 'e' permanently$COLOR_END"
        echo
        echo -e "${COLOR_LGRAY}You can also directly edit the list of aliases at:"
        echo -e "\t'$DJLIST'${COLOR_END}"
        echo
    }

    print_help () {
        echo -e "Usage: $COLOR_BBLUE$DIRJUMPER_ALIAS -ardghv [<ARGS>]$COLOR_END"
        echo -e "\t$COLOR_BLUE-a <ALIAS> [<DIR>]$COLOR_END\t\tAdd an alias, use the working dir. if <DIR> is not set"
        echo -e "\t$COLOR_BLUE-r <OLD-ALIAS> <NEW-ALIAS>$COLOR_END\tRename a directory alias"
        echo -e "\t$COLOR_BLUE-d <ALIAS>$COLOR_END\t\t\tDelete a directory alias"
        echo -e "\t$COLOR_BLUE-g <ALIAS>$COLOR_END\t\t\tGet the full path for an alias"
        echo -e "\t$COLOR_BLUE-l$COLOR_END\t\t\t\tList all aliases\n"
        echo -e "\t$COLOR_BLUE-u$COLOR_END\t\t\t\tUpgrade the script to the latest version"
        echo -e "\t$COLOR_BLUE-w$COLOR_END\t\t\t\tDowngrade the script to an older version\n"
        echo -e "\t$COLOR_BLUE-h$COLOR_END\t\t\t\tThis help message"
        echo -e "\t$COLOR_BLUE-v$COLOR_END\t\t\t\tThe version of the script"
        echo
        print_examples
    }

    ## Not all environments have realpath
    own_realpath() {
        local ourpwd=$PWD
        cd "$(dirname "$1")"
        local link=$(readlink "$(basename "$1")")
        while [ "$link" ]; do
            cd "$(dirname "$link")"
            link=$(readlink "$(basename "$1")")
        done
        own_realpath="$PWD/$(basename "$1")"
        cd "$ourpwd"
        echo "$own_realpath"
    }

    ## Format and color alias/directory list
    list_aliases () {
        # cat "$DJLIST"
        local wd=`pwd`
        while read line; do
            local al=`echo $line | cut -d " " -f1`
            local pth=`echo $line | cut -d " " -f2-`
            local pth_color=$COLOR_BBLUE
            local pth_sel=" "
            # If the current working directory is something we have 
            # an alias for make it known
            if [[ $pth = $wd ]]; then
                pth_color=$COLOR_BGREEN
                pth_sel="+" 
            fi
            printf "$pth_color\t$pth_sel %s$END_COLOR\t$COLOR_PURPLE%s$END_COLOR\n" $al $pth
        done < "$DJLIST"
    }

    ## Get the directory from the given alias
    read_alias () {
        egrep "\b$1\b" "$DJLIST" | sort | cut -d " " -f2- | sort
    }

    find_alias () {
        egrep "\b$1\b" "$DJLIST" | sort | cut -d " " -f1 | sort
    }

    get_alias() {
        local dir=`read_alias $1`
        if [[ $dir = "" ]]; then
            echo -e "${COLOR_RED}Alias '$1' not found! $COLOR_END" >&2
            return 1
        else
            echo $dir
        fi
    }

    ## Validates a string as alias
    check_alias () {
        if [[ "$1" =~ ^[0-9A-Za-z_@!%=.,]+$ ]]; then
            return 0
        fi
        echo -en $COLOR_RED
        echo "Invalid name for an alias!"
        echo -en $COLOR_END
        return 1
    }

    ## Change the current directory to the bookmarked one (if any)
    cd_alias () {
        check_alias $1
        if [[ $? -ne 0  ]]; then
            return 1
        fi
        local dir=`get_alias $1`
        if [[ $dir != "" ]]; then
            cd $dir
        fi
    }

    ## Bookmark the given or if it is not given the current directory to the list
    add_alias () {
        local dname=$2
        check_alias $1
        if [[ $? -ne 0 ]]; then
            return 1
        fi
            
        if [[ $dname = "" ]]; then
            dname=`pwd`
            echo -en $COLOR_YELLOW
            echo "Bookmarking the current directory '$dname' as '$1'"
            echo -en $COLOR_END
        fi
        dname=`own_realpath $dname`
        local odname=`find_alias $1`
        if [[ $odname = "" ]]; then
            echo "$1 $dname" >> "$DJLIST"
        else
            echo -en $COLOR_RED
            echo "Alias '$1' is already exist for path '$odname'!"
            echo -en $COLOR_END
            echo -en $COLOR_YELLOW
            echo "Use '$DIRJUMPER_ALIAS -r $1 <new-alias>' to rename it"
            echo -en $COLOR_END
        fi
    }

    rename_alias () {
        if [[ $2 = "" ]]; then
            echo -en $COLOR_RED
            echo "You must give the alias a new name!"
            echo -en $COLOR_END
            return 1
        fi
        check_alias $1
        if [[ $? -ne 0 ]]; then
            return 1
        fi

        local oname=`get_alias $1`
        if [[ $oname != "" ]]; then
            sed -i "s/^\b$1\b/$2/" "$DJLIST"
        fi
    }

    delete_alias () {
        check_alias $1
        if [[ $? -ne 0 ]]; then
            return 1
        fi
        local oname=`get_alias $1`
        if [[ $oname != "" ]]; then
            sed -i "/^\b$1\b/d" "$DJLIST"
        fi
    }

    ## Updates the current install if a new version is available
    update_dirjumper () {
        echo -e "${COLOR_YELLOW}[+] Checking for new version (current is v$VERSION)...${COLOR_END}"

        cd $DJPATH
        new_version=$(wget "$REPO/VERSION" -O- -o /tmp/dj.log)
        if [ $? -ne 0 ]; then 
            cat /tmp/dj.log
            echo -e "${COLOR_RED}[!] Error while downloading version information!${COLOR_END}"
            return 1
        fi
        if [ $VERSION = $new_version ]; then
            echo -e "${COLOR_GREEN}[+] Your version is up-to-date (v$VERSION)${COLOR_END}"
        fi
        echo -e "${COLOR_GREEN}[+] New version (v$new_version) found...${COLOR_END}"
        echo -ne "${COLOR_YELLOW}[?] Do you want to upgrade? [y/N]: ${COLOR_END}"
        read answ
        if [ $answ = "y" -o $answ = "Y" ]; then
            mv dj dj.old
            wget "$REPO/dj" -o/tmp/dj.log
            if [ $? -ne 0 ]; then
                cat /tmp/dj.log
                echo -e "${COLOR_RED}[!] Error while downloading upgrades!${COLOR_END}"
            fi
            chmod +x dj
            echo -e "${COLOR_GREEN}[+] Upgrade done...${COLOR_END}"
            echo -e "${COLOR_LGRAY}[*] Open a new shell to apply changes...${COLOR_END}"
            rm /tmp/dj.log
        else
            echo -e "${COLOR_RED}[-] Upgrade aborted.${COLOR_END}"
        fi
    }

    ## Restore and older version
    downgrade_dirjumper () {
        cd $DJPATH
        if [ -e dj.old ]; then
            old_version=$(./dj.old -v)
            mv dj dj.older
            mv dj.old dj
            mv dj.older dj.old
            echo -e "${COLOR_GREEN}[+] Sucessfully downgraded from '${old_version}' to '${VERSION}'.${COLOR_END}"
        else
            echo -e "${COLOR_RED}[!] No older version found!${COLOR_END}"
        fi
    }

    ## main entry point
    while getopts "a:r:d:g:liuwsvh" optname; do
        case "${optname}" in
            "v")
                echo $VERSION
                ;;
            "a")
                add_alias $OPTARG ${@:$OPTIND:1}
                ;;
            "r")
                rename_alias $OPTARG ${@:$OPTIND:1}
                ;;
            "d")
                delete_alias $OPTARG
                ;;
            "g")
                read_alias  $OPTARG
                ;;
            "s")
                init_sh
                ;;
            "l")
                list_aliases
                ;;
            "u")
                update_dirjumper
                ;;
            "w")
                downgrade_dirjumper
                ;;
            "h")
                print_help
                ;;
            "?")
                echo -e "${COLOR_RED}Unknown option $OPTARG${COLOR_END}"
                ;;
            ":")
                echo -e "${COLOR_RED}No argument value for option $OPTARG${COLOR_END}"
                ;;
            *)
                echo -e "${COLOR_RED}Unknown error while processing options${COLOR_RED}"
                ;;
        esac
    done
    shift $(($OPTIND - 1))

    ## Jump to alias if we still have args untouched by getopts
    if [[ $1 != '' ]]; then
        cd_alias $1
    fi

    ## No args, so print the whole list
    if [[( $# -eq 0 ) && ( $OPTIND -eq 1 )]]; then
        list_aliases
    fi

    ## Remove function names from the global namespace,
    #  since everything will be sourced from the main init script.
    unset -f print_examples
    unset -f print_help
    unset -f own_realpath
    unset -f list_aliases
    unset -f read_alias
    unset -f find_alias
    unset -f check_alias
    unset -f get_alias
    unset -f cd_alias
    unset -f add_alias
    unset -f rename_alias
    unset -f delete_alias
    unset -f update_dirjumper
    unset -f downgrade_dirjumper
}

## Creates the alias list and appends the init script after downloading
install_dirjumper () {
    echo "[+] Creating installation directory '$DJPATH'..."
    mkdir -p "$DJPATH"
    echo "[+] Installing '$DJBIN'..."
    cp "$0" "$DJBIN"
    echo "[+] Creating '$DJLIST'..."
    touch "$DJLIST"
    echo "[+] Appending dirjump to '$SH_RC_FILE'..."
    echo -e "# <dirjumper>" >> "$HOME/$SH_RC_FILE"
    echo -e "source \"$DJBIN\"" >> "$HOME/$SH_RC_FILE"
    echo -e "# </dirjumper>" >> "$HOME/$SH_RC_FILE"
    echo -e "$COLOR_GREEN[+] All done. Start a new shell to apply changes...$COLOR_END"
    echo -e "$COLOR_LGRAY[*] Now you can use '$DIRJUMPER_ALIAS -a <alias>' to add an alias for this directory."
    echo -e "[*] And then use '$DIRJUMPER_ALIAS <alias>' to return here."
    echo -e "[*] Use '$DIRJUMPER_ALIAS -h' to find out more... "
    echo -e $COLOR_END
}

## Install when executed as a script with the '-i' option
if [[ $1 = 'install' ]]; then
    install_dirjumper
fi

unset -f install_dirjumper
