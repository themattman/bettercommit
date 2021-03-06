#!/bin/sh ## readlink(1), realpath(1) with GNU extensions like `readlink -f`.

## A XSI/POSIX shell implementation of readlink(1), supporting GNU extensions.
## Also a realpath(1) [like the mksh builtin], but doesn't wrap realpath(3).
## GNU *short* options are supported, just avoid the --longopt flag aliases.
## Otherwise, the functionality should be identical.

## One benefit of a using a pure shell implementation is that it can be used
## *within a script* to canonicalize the path *of the script itself*, without
## relying on non-standard external utilities; just include the function in
## your script and you can call readlink -f "$0".

## Latest version should be somewhere around http://github.com/geoff-codes.
## (c) 2015 Geoff Nixon. Public Domain; no warranty expressed or implied.

readlink(){
  ## Functions/variables are all prefixed since local variables are not POSIX.

  readlink_exists=1
  readlink_dirs_exist=1
  readlink_print=echo
  readlink_sep=''

  readlink_usage(){
    echo "usage: "$(basename "$0")" [-efmnqsvz] [file ...]" >&2
  }

  OPTIND=1; while getopts "efhmnqsvz?" readlink_opt; do
      case "$readlink_opt" in
        e) readlink_realpath=1; readlink_dirs_exist=1; readlink_exists=1 ;;
        f) readlink_realpath=1; readlink_dirs_exist=1; readlink_exists=  ;;
        h) readlink_usage; exit 0                                        ;;
        m) readlink_realpath=1; readlink_dirs_exist= ; readlink_exists=  ;;
        n) readlink_print=printf                                         ;;
      q|s) readlink_verbose=0                                            ;;
        v) readlink_verbose=1                                            ;;
        z) readlink_print=printf; readlink_sep='\0'                      ;;
       \?) readlink_usage; exit 1                                        ;;
      esac
  done
  shift $((OPTIND - 1))


  readlink_readlink(){
    readlink_readlink="$(ls -ld "$@" | sed 's|.* -> ||')"

    [ -$readlink_realpath- != -- ] &&
      [ "$(echo "$readlink_readlink" | cut -c1)" != "/" ] &&
        readlink_readlink="$(pwd -P)/$readlink_readlink"

    echo "$readlink_readlink"
  }

  readlink_canonicalize(){
    [ -"$(basename "$@")"- = -"."- ] || [ -"$(basename "$@")"- = -".."- ] &&
      readlink_canon="$(cd "$(pwd -P)/$(basename "$@")"; pwd -P)" ||
      readlink_canon="$(pwd -P)/$(basename "$@")"
    readlink_canonical="$(echo "$readlink_canon" | sed 's|//|/|g')"

    echo "$readlink_canonical"
  }

  readlink_no_dir(){
    [ -$readlink_dirs_exist- = -- ] &&
      $readlink_print "$@$readlink_sep" && exit 0

    [ -$readlink_verbose- = -- ] ||
      echo "Directory $(dirname "$@") doesn't exist." >&2 && exit 1
  }

  readlink_no_target(){
     [ -$readlink_exists- = -- ] &&
      $readlink_print "$(readlink_canonicalize "$@")$readlink_sep" && exit 0

    [ -$readlink_verbose- = -- ] ||
      echo "$@: No such file or directory." >&2 && exit 1
  }

  readlink_not_link(){
    [ -$readlink_realpath- = -- ] && [ -$readlink_verbose- = -- ] && exit 1 ||
    [ -$readlink_realpath- = -- ] && [ -$readlink_verbose- != -- ] &&
      echo "$@ is not a link." >&2  && exit 1

    [ -$readlink_realpath- != -- ]                         &&
      readlink_canonical="$(readlink_canonicalize "$@")"   &&
        $readlink_print "$readlink_canonical$readlink_sep" && exit 0

    [ -$readlink_verbose-  = -- ] ||
    { [ -f "$@" ] && readlink_file_type="regular file"                     ||
        [ -d "$@" ] && readlink_file_type="directory"                      ||
          [ -p "$@" ] && readlink_file_type="FIFO"                         ||
            [ -b "$@" ] && readlink_file_type="block special file"         ||
              [ -c "$@" ] && readlink_file_type="character special file"   ||
                [ -S "$@" ] && readlink_file_type="socket"
      echo "$(basename "$0"): "$@": is a $readlink_file_type." >&2; exit 1
    }
  }

  readlink_try(){
    readlink_cur_dir="$(dirname "$@")"
    readlink_cur_base="$(basename "$@")"

    cd "$readlink_cur_dir" 2>/dev/null || readlink_no_dir "$@"
    [ -e "$readlink_cur_base" ]        || readlink_no_target "$(pwd -P)/$@"
    [ -L "$readlink_cur_base" ]        || readlink_not_link "$@"

    readlink_readlink="$(readlink_readlink "$readlink_cur_base")"

    [ -$readlink_realpath- = -- ]                                 &&
      $readlink_print "$readlink_readlink$readlink_sep" && exit 0 ||
        readlink_try "$readlink_readlink"
  }


  for readlink_target; do :; done
  [ -"$readlink_target"- = -""- ] && readlink_usage && exit 1
  readlink_try "$readlink_target"
}

# [ "$(basename "$0")" = realpath ] && readlink -f "$@" || readlink "$@"
