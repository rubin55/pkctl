#!/usr/bin/env bash

# Copyright © 2011-2017 RAAF Technology bv

# A few settings. Change these to suit your needs.
export PATH="/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin:$PATH"
work="/tmp/pkctl"
url="http://1.2.3.4/auth"
comment="# ~/.ssh/authorized_keys - This file is generated by auth tool.
# All your base are belong to us. You have no chance to survive make your time."

platform='unknown'
unamestr=$(uname)
if [[ "$unamestr" =~ "Linux" ]]; then
   platform='linux'
elif [[ "$unamestr" =~ "BSD" ]]; then
   platform='bsd'
elif [[ "$unamestr" =~ "DragonFly" ]]; then
   platform='bsd'
elif [[ "$unamestr" =~ "Darwin" ]]; then
   platform='darwin'
elif [[ "$unamestr" =~ "SunOS" ]]; then
   platform='sunos'
elif [[ "$unamestr" =~ "HP-UX" ]]; then
   platform='hpux'
elif [[ "$unamestr" =~ "AIX" ]]; then
   platform='aix'
else
   platform='unknown'
fi


# Make sure working directory exists and enter if so.
enterWork() {
    if [ -d "$work" ]; then
	mkdir -p "$work/work"
        cd "$work/work"
    else
        echo "Working directory not found. ($work)"
        echo "You might need to run init first."
        exit 1
    fi
}

# Show a user name if it exists.
getUser() {
    if [ "$1" ]; then
        account="$1"
    fi

    if [ "$account" ]; then
        if [ "$platform" = "linux" -o  "$platform" = "bsd" -o  "$platform" = "sunos" ]; then
             getent passwd "$account" | cut -d ':' -f 1 | sort -u
        elif [ "$platform" = "hpux" -o "$platform" = "aix" ]; then
            cat /etc/passwd | cut -d: -f1 | grep -w "$account" | sort -u
        elif [ "$platform" = "darwin" ]; then
            name="$(dscacheutil -q user -a name "$account" | grep '^name: ' | sed 's|name: ||g' | sort -u)"
            if [ ! $(echo $name | grep '^_') ]; then
                echo "$name"
            fi
        else
            echo "Platform is unknown, cannot list user $account."
            exit 1
        fi
    fi
}

# Show a list of home directories for every user account, or show a specific user account home.
getHome() {
    if [ "$1" ]; then
        account="$1"
    fi

    if [ "$account" ]; then
        if [ "$platform" = "linux" -o  "$platform" = "bsd" -o  "$platform" = "sunos" ]; then
             getent passwd "$account" | cut -d ':' -f 6 | sort -u
        elif [ "$platform" = "hpux" -o "$platform" = "aix" ]; then
            cat /etc/passwd | grep -w "$account" | cut -d: -f6 | sort -u
        elif [ "$platform" = "darwin" ]; then
            dscacheutil -q user -a name "$account" | grep '^dir: ' | sed 's|dir: ||g' | sort -u
        else
            echo "Platform is unknown, cannot list user $account."
            exit 1
        fi
    else
        if [ "$platform" = "linux" -o  "$platform" = "bsd" -o  "$platform" = "sunos" ]; then
            getent passwd | cut -d ':' -f 6 | sort -u
        elif [ "$platform" = "hpux" -o "$platform" = "aix" ]; then
            cat /etc/passwd | cut -d: -f6 | sort -u
        elif [ "$platform" = "darwin" ]; then
            dscacheutil -q user | grep '^dir: ' | sed 's|dir: ||g' | sort -u
        else
            echo "Platform is unknown, cannot enumerate user accounts."
            exit 1
        fi
    fi
}

# Get the uid for a given account.
getUid() {
    if [ "$1" ]; then
        account="$1"
    fi

    if [ "$platform" = "sunos" ]; then
        id="/usr/xpg4/bin/id"
    else
        id="id"
    fi

    if [ "$account" ]; then
        "$id" -u "$account"
    else
        echo "Please specify account to get a uid for."
        exit 1
    fi
}

# Get the gid for a given account.
getGid() {
    if [ "$1" ]; then
        account="$1"
    fi

    if [ "$platform" = "sunos" ]; then
        id="/usr/xpg4/bin/id"
    else
        id="id"
    fi

    if [ "$account" ]; then
        "$id" -g "$account"
    else
        echo "Please specify account to get a gid for."
        exit 1
    fi
}

# Main case statement.
case "$1" in
  auto)
  $0 clean
  $0 init
  $0 purge
  $0 build
  $0 install
  ;;
  init)
    if [ -d "$work" ]; then
        echo "Working directory already exists. ($work)"
        echo "You can only re-init after running clean."
        exit 1
    fi

    echo "Creating and entering $work"
    mkdir -p "$work"
    cd "$work"

    wget="$(which wget 2> /dev/null)"
    curl="$(which curl 2> /dev/null)"
    if [ ! -z "$wget" ]; then
        echo "Fetching data using wget"
        wget -q -r -nH --cut-dirs=1 --no-parent --reject "index.html*" $url
    elif [ ! -z "$curl" ]; then
        echo "Fetching data using curl"
        curl -s -O $url/pkctl.sh
        for subdir in humans roles services specifics; do
            mkdir $subdir
            cd $subdir
            for file in $(curl -s http://$url/$subdir/ |
                      grep href |
                      sed 's/.*href="//' |
                      sed 's/".*//' |
                      grep '^[a-zA-Z].*'); do
                curl -s -O http://$url/$subdir/$file
            done
            cd - > /dev/null
        done
    else
        echo "Could not find either curl or wget on your path."
        echo "Please make sure either curl or wget are available."
        exit 1
    fi;

    echo "Making sure work directory is clean"
    rm -f work/*.keys

    echo "Setting executable bits"
    chmod 755 "$work/*.sh"

    echo "Done. Please continue at $work"
    ;;

  clean)
    # Remove any previously fetched data. Don't specify $work here.
    rm -rf "/tmp/pkctl"
    ;;

  list)
    # Make sure working directory exists and enter if so.
    enterWork

    # List all authorized keys files on the system.
    echo "Listing currently installed authorized keys for all users"
    for home in $(getHome); do
        if [ -e "$home/.ssh/authorized_keys" ]; then
            echo "$home/.ssh/authorized_keys"
        fi
    done
    echo ""
    ;;

  purge)
    # Make sure working directory exists and enter if so.
    enterWork

    # Purge any and all authorized keys files on the system.
    echo "Removing currently installed authorized keys for all users"
    for home in $(getHome); do
        if [ -e "$home/.ssh/authorized_keys" ]; then
            echo "$home/.ssh/authorized_keys"
            rm $home/.ssh/authorized_keys
        fi
    done
    echo ""
    ;;

  build)
    # Make sure working directory exists and enter if so.
    enterWork

    # Build new authorized keys files under work directory, but clean first.
    rm -f *.keys

    # Construct human and service keys if an account exists.
    for group in humans services; do
        accounts=$(ls ../$group | sed "s|.keys||g")
        for account in $accounts; do
            if [ "$(getUser $account)" ]; then
                echo "Adding key for $account to $account.keys"
                if [ ! -e "$account.keys" ]; then
                    echo "$comment" > $account.keys
                fi
                cat ../$group/$account.keys >> $account.keys
            fi
        done
    done
    echo ""

    # Construct service account keys.
    for role in $(ls ../roles); do
        systems="all"
        . ../roles/$role
        for system in $systems; do
            for service in $services; do
                if [ "$(getUser $service)" ]; then
                    if [ ! -e "$service.keys" ]; then
                        echo "$comment" > $service.keys
                    fi
                    for human in $humans; do
                        echo "Adding key for $human to $service.keys"
                        cat ../humans/$human.keys >> $service.keys
                    done
                fi
            done
        done
    done
    echo ""

    # If a service account on a machine has an entry in specifics/, add to key file.
    for entry in $(ls ../specifics); do
        account=$(echo "$entry" | cut -d '@' -f 1 | tr A-Z a-z)
        host=$(echo "$entry" | cut -d '@' -f 2 | cut -d '.' -f 1 | tr A-Z a-z)
        if [ $shortname = $host ]; then
            if [ ! -e "$account.keys" ]; then
                echo "$comment" > $account.keys
            fi
            echo "Adding machine specific keys to account $account on $host"
            cat ../specifics/$account@$host.keys >> $account.keys
        fi
    done
    echo ""
    ;;

  install)
    # Make sure working directory exists and enter if so.
    enterWork

    # Install previously generated keys onto the system.
    if [ ! "$(ls *.keys 2> /dev/null)" ]; then
        echo "No generated keys found under work directory."
        echo "Please run build first."
        exit 1
    fi

    for file in $(ls *.keys); do
        account="$(echo $file | sed "s|.keys||g")"
        homedir="$(getHome $account)"
        uid="$(getUid $account)"
        gid="$(getGid $account)"
        if [ -d "$homedir" ]; then
            echo "Installing $homedir/.ssh/authorized_keys"
            mkdir -p $homedir/.ssh
            cp $file $homedir/.ssh/authorized_keys
            chmod 755 $homedir
            chmod 755 $homedir/.ssh
            chmod 644 $homedir/.ssh/authorized_keys
            chown -R $uid:$gid $homedir/.ssh
        elif [ -e "$homedir" ]; then
            echo "Account's homedirectory is actually not a directory ($homedir)"
            echo "Skipping authorized_keys installation."
        else
            echo "Account $account has no homedirectory ($homedir)."
            echo "Creating an empty home directory and setting ownership."
            echo "Installing $homedir/.ssh/authorized_keys"
            mkdir -p $homedir/.ssh
            cp $file $homedir/.ssh/authorized_keys
            chmod 755 $homedir
            chmod 755 $homedir/.ssh
            chmod 644 $homedir/.ssh/authorized_keys
            chown -R $uid:$gid $homedir/.ssh
        fi

    done
    ;;

  version)
    echo "RELEASE.STRING.VERSION
    RELEASE.STRING.COPYRIGHT
    RELEASE.STRING.RELDATE
    RELEASE.STRING.BUILT
    RELEASE.STRING.LICENSE" | sed 's/^[ \t]*//;s/[ \t]*$//'
    ;;

  *)
    echo "Usage: $0 auto|init|clean|list|purge|build|install|version"
    exit 1
esac
