#!/bin/bash
#
# getopt-template.bash (use getopt utility)
#
export LANG=C
usage_exit() {
        echo "Usage: getopt-template.bash [-a] [-d dir] item1 item2 ..." 1>&2
        exit 1
}
#
# Options
#
echo "$@"       ####DEBUG
GETOPT=`getopt -q -o ad:h -l extra,file -- "$@"` ; [ $? != 0 ] && usage_exit
eval set -- "$GETOPT"
echo "$@"       ####DEBUG
while true
do
  case $1 in
  -a)   A_FLAG=yes      ; shift
        ;;
  -d)   OUTDIR=$2       ; shift 2
        ;;
  -h)   usage_exit
        ;;
  --)   shift ; break
        ;;
  *)    usage_exit
        ;;
  esac
done
#
echo \$#=$#             ####DEBUG
echo \$@="$@"           ####DEBUG
echo A_FLAG=$A_FLAG     ####DEBUG
echo OUTDIR=$OUTDIR     ####DEBUG
