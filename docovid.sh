#!/bin/bash
#
# usage: docovid.sh          batch mode
#        docovid.sh -i       interactive (crude step by step) mode
#

# default settings: edit with care
INTERACT=n       # y: step by step interaction
SWAP=y           # n: don't swap db
GETDATA=y        # n: don't update uniprot and gff

progname=$0

function usage () {
	cat <<EOF

Usage:
$progname [-d] [-i] [-s]
	-d: no checking of sources (uniprot and gff) for update
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


while getopts "dis" opt; do
   case $opt in
	d )  echo "- Don't mirror sources" ; GETDATA=n;;
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
DATADIR=/micklem/data/covid

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
echo "AO!"
cd $PDIR
pwd
USE=gin
CURR=`ls -l covidmine.properties | cut -f2 -d">" | cut -f3 -d.`
if [ $CURR = "gin" ]
then
USE=tonic
fi
echo $USE
export DD=`date "+%d-%m-%Y %H.%M"`
sed -i 's/preAlpha.*/preAlpha \<i\>'"$USE"'\<\/i\> '"$DD"'/' $COV.$USE

rm $COV
ln -s $COV.$USE $COV

echo $CURR" -> "$USE

}

function getSources {
# do the mirroring!
# TODO: avoid the gff expansion if no changes

FTPROT=ftp://ftp.uniprot.org/pub/databases/uniprot/pre_release/
UNIDIR=$DATADIR/uniprot
FASDIR=$DATADIR/fasta
GFFDIR=$DATADIR/gff

GFFILE=GCF_009858895.2_ASM985889v3_genomic

# fix for now
cd $GFFDIR/mirror
wget -N https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/009/858/895/GCF_009858895.2_ASM985889v3/GCF_009858895.2_ASM985889v3_genomic.gff.gz
mv $GFFDIR/GCF_009858895.2_ASM985889v3_genomic.gff $GFFDIR/oldies/GCF_009858895.2_ASM985889v3_genomic.gff.`date "+%y%m%d.%H%M"`
gzip -d -c *.gff.gz > $GFFDIR/GCF_009858895.2_ASM985889v3_genomic.gff

cd $UNIDIR
wget -N $FTPROT/*.fasta
wget -N $FTPROT/covid-19.xml

}



if [ $SWAP = "y" ]
then
   interact "Swapping build db"
   swap
fi

if [ $GETDATA = "y" ]
then
   interact "Getting sources"
   getSources
fi


cd $COVDIR

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

