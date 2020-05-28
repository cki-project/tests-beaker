#!/bin/bash
#
# Install packages according to metadata file
#

function get_pkgs
{
    typeset metadata_file=${1?"*** metadata file ***"}
    typeset pkgs=""
    typeset keyword=""
    for keyword in "dependencies" "softDependencies"; do
        typeset kv=$(egrep "^$keyword=" $metadata_file)
        [[ -z $kv ]] && continue

        # convert ';' to ',' as a new var $keyword will be created via eval
        kv=$(echo $kv | sed 's/;/,/g')
        # strip comment starting with '#'
        eval "$kv"

        eval _pkgs=\$${keyword}
        pkgs+=" $(echo $_pkgs | sed 's/,/ /g')"
        unset _pkgs $keyword
    done
    echo $pkgs
}

function get_pkg_mgr
{
    [[ -x /usr/bin/dnf ]] && echo dnf || echo yum
}

function usage
{
    echo "Usage: $1 [-n] <metadata file>" >&2
    echo "e.g." >&2
    echo "       $1 -n metadata # dry run" >&2
    echo "       $1 metadata" >&2
}

dry_run="no"
while getopts ':nh' iopt; do
    case $iopt in
        n) dry_run="yes" ;;
        h) usage $0; exit 1 ;;
        :) echo "Option '-$OPTARG' wants an argument" >&2; exit 1 ;;
        '?') echo "Option '-$OPTARG' not supported" >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

metadata_file=${1:-"metadata"}
if [[ ! -f $metadata_file ]]; then
    echo "File $metadata_file not found" >&2
    usage $0
    exit 1
fi

pkgs=$(get_pkgs $metadata_file)
if [[ -z $pkgs ]]; then
    echo "Packages to install not found" >&2
    exit 0
fi

pkg_mgr=$(get_pkg_mgr)
if [[ $dry_run == "yes" ]]; then
    echo "=== DRY RUN ==="
    echo $pkg_mgr -y install $pkgs
    exit 0
fi
echo "Now install packages <$pkgs>, please wait for a while ..."
$pkg_mgr -y install $pkgs
exit $?
