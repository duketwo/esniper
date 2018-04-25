#! /bin/sh

if [ $# -ne 3 ]; then
	echo "ERROR: ReleaseBuild.sh requires three arguments, which are major, minor " >&2
	echo "   and step versions. For example, to build version 2.15.6 you would give " >&2
	echo "   2 15 6 as arguments." >&2
	echo "   Previous release was `cat version.txt`" >&2
	exit 2
fi

# setup environment variables:

MAJOR="$1"
MINOR="$2"
STEP="$3"
CURRENT=$MAJOR.$MINOR.$STEP
CURRFILE=esniper-$MAJOR-$MINOR-$STEP
CURRTAG=Version_${MAJOR}_${MINOR}_${STEP}

if ! git diff-files --quiet --ignore-submodules -- 
then
	echo "ERROR: local modifications found." >&2
	echo "   Please commit and push everything or clean up your workspace." >&2
	exit 3
fi

# FIXME check for local commits not pushed yet.

echo "ATTENTION! If you have not updated, committed and pushed ChangeLog, "
echo "please quit this script by pressing CTRL+C and do it now!"
echo "Press enter to continue."
read line

echo Creating ReleaseNote and README file from ChangeLog.

awk 'BEGIN {empty=0;stop=0;buffer="";}
/^[     ]*$/ {
  empty=1;
  if(!stop && length(buffer)) printf "%s", buffer;
  buffer = "";
}
{ if(!stop) {
    if(!empty) print;
    else {
      buffer = buffer $0 "\n";
      if(match($0, /\* [0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]* released/)) stop=1;
    }
  }
}' ChangeLog > ReleaseNote
cp ReleaseNote README

echo Please check the contents of the ReleaseNote file. It should contain
echo all changes for the current version but not the history as in ChangeLog.
echo "--- start ---"
cat ReleaseNote
echo "---  end  ---"
echo "If the ReleaseNote file is not OK or if you are not sure, press CTRL+C"
echo "to stop this script now and fix ChangeLog or this script."
echo "Press enter to continue."
read line

echo Rebuilding automake files with current version number.  CVS will be called four
echo times. You will see some "lost" errors, in the last CVS command.  That is OK.

perl -i.bak -p -e 's/(AM_INIT_AUTOMAKE\(esniper),.*\)/\1,'${CURRENT}')/' configure.in
make
git add configure.in
git commit -m "$CURRENT new version number in configure.in"
sleep 2
touch aclocal.m4 Makefile.am
git add --force aclocal.m4 Makefile.am
git commit --allow-empty -m "$CURRENT re-generated aclocal.m4 Makefile.am"
sleep 2
touch configure Makefile.in
git add --force configure Makefile.in
git commit --allow-empty -m "$CURRENT re-generated configure Makefile.in"
rm configure.in aclocal.m4 Makefile.am configure Makefile.in
git checkout -f

echo Modifying version.txt and index.html, then checkin with CVS.

echo $CURRENT >version.txt

# The perl command did not work. Replaced by download link to latest version.
#perl -i.bak -p -e 's/esniper-.*[.]tgz/'${CURRENT}'.tgz/' index.html

git add version.txt ReleaseNote README index.html
git commit -m "$CURRENT updated version.txt ReleaseNote README index.html"

echo Tagging source.

if ! git tag -a -m $CURRENT $CURRTAG
then
   echo "ERROR: adding tag $CURRTAG failed" >&2
   exit 4
fi

echo Pushing all changes to upstream. Hopefully no conflicts occur.
echo git push --tags || exit

echo Creating source tar file ${CURRFILE}.tgz

rm -rf ./$CURRFILE

mkdir $CURRFILE $CURRFILE/frontends
cp auction.c auction.h $CURRFILE
cp auctionfile.c auctionfile.h $CURRFILE
cp auctioninfo.c auctioninfo.h $CURRFILE
cp buffer.c buffer.h $CURRFILE
cp esniper.c esniper.h $CURRFILE
cp history.c history.h $CURRFILE
cp html.c html.h $CURRFILE
cp http.c http.h $CURRFILE
cp options.c options.h $CURRFILE
cp util.c util.h $CURRFILE
cp aclocal.m4 configure configure.in depcomp $CURRFILE
cp install-sh Makefile.am Makefile.in missing $CURRFILE
cp AUTHORS COPYING INSTALL NEWS README TODO $CURRFILE
cp ChangeLog $CURRFILE
cp esniper.1 esniper_man.html misc.mk $CURRFILE
cp sample_auction.txt sample_config.txt $CURRFILE
cp frontends/README frontends/snipe $CURRFILE/frontends
tar cvf - $CURRFILE | gzip >$CURRFILE.tgz
