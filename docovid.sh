#!/bin/bash
#
# usage: docovid.sh          batch mode
#        docovid.sh -i       interactive (crude step by step) mode
#

# default settings: edit with care
INTERACT=n       # y: step by step interaction
SWAP=y           # n: don't swap db

progname=$0

function usage () {
	cat <<EOF

Usage:
$progname [-i] [-s]
	-i: interactive mode
	-s: no swapping of build db (for example after a build fail)
	-v: verbode mode

examples:

$progname			do the release without asking for permission..
$progname -i      		interactive version (for step by step release)
$progname -s      		do the release without swapping db
$progname -is      		interactive version without swapping

EOF
	exit 0
}




while getopts "is" opt; do
   case $opt in
	i )  echo "- Interactive mode" ; INTERACT=y;;
        s )  echo "- Don't swap db" ; SWAP=n;;
        h )  usage ;;
	\?)  usage ;;
   esac
done

shift $(($OPTIND - 1))
PDIR=$HOME/.intermine
COV=covidmine.properties
COVDIR=/micklem/data/thalemine/git/covidmine


function interact {
# if testing, wait here before continuing
if [ $INTERACT = "y" ]
then
echo "$1"
echo "Press return to continue (^C to exit).."
echo -n "->"
read 
fi
}

function swap {
# to change build db

cd $PDIR
USE=gin
CURR=`ls -l covidmine.properties | cut -f2 -d">" | cut -f3 -d.`
if [ $CURR = "gin" ]
then 
USE=tonic
fi

export DD=`date "+%d-%m-%Y %H.%M"`
sed -i 's/preAlpha.*/preAlpha \<i\>'"$USE"'\<\/i\> '"$DD"'/' $COV.$USE 

rm $COV
ln -s $COV.$USE $COV

echo $CURR" -> "$USE 

}


if [ $SWAP = "y" ]
then
interact "Swapping build db"
fi


cd $COVDIR

#interact "Getting sources"
#./getSources.sh

interact "Building.."

#export JAVA_HOME=""
rm $DATADIR/dumps/cov*

# check if success
./project_build -b -v localhost $DATADIR/dumps/cov\
|| { printf "%b" "\n  build FAILED!\n" ; exit 1 ; }
#./project_build -b -v  localhost $DATADIR/dumps/cov 

# if on production machine (mega3? p1?) you don't need those
#./gradlew postProcess -Pprocess=create-autocomplete-index
#./gradlew postProcess -Pprocess=create-search-index

interact "Deploying"

./gradlew cargoRedeployRemote

