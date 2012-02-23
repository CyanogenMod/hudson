#!/usr/bin/env bash

if [ -z "$WORKSPACE" ]
then
  echo WORKSPACE not specified
  exit 1
fi

cd $WORKSPACE
rm -rf archive
mkdir -p archive
export BUILD_NO=$BUILD_NUMBER
unset BUILD_NUMBER

export PATH=~/bin:$PATH

export USE_CCACHE=1
export BUILD_WITH_COLORS=0

REPO=$(which repo)
if [ -z "$REPO" ]
then
  mkdir -p ~/bin
  curl https://dl-ssl.google.com/dl/googlesource/git-repo/repo > ~/bin/repo
  chmod a+x ~/bin/repo
fi

if [ -z "$REPO_BRANCH" ]
then
  echo REPO_BRANCH not specified
  exit 1
fi

git config --global user.name $(whoami)@$NODE_NAME
git config --global user.email jenkins@cyanogenmod.com

if [ ! -d $REPO_BRANCH ]
then
  mkdir $REPO_BRANCH
  if [ ! -z "$BOOTSTRAP" -a -d "$BOOTSTRAP" ]
  then
    echo Bootstrapping repo with: $BOOTSTRAP
    cp -R $BOOTSTRAP/.repo $REPO_BRANCH
  fi
  cd $REPO_BRANCH
  repo init -u git://github.com/CyanogenMod/android.git -b $REPO_BRANCH
else
  cd $REPO_BRANCH
  # temp hack for turl
  repo init -u git://github.com/CyanogenMod/android.git -b $REPO_BRANCH
fi

# make sure ccache is in PATH
export PATH="$PATH:$REPO_BRANCH/prebuilt/$(uname|awk '{print tolower($0)}')-x86/ccache"

cp $WORKSPACE/hudson/$REPO_BRANCH.xml .repo/local_manifest.xml

echo Syncing...
repo sync

if [ -f $WORKSPACE/hudson/$REPO_BRANCH-setup.sh ]
then
  $WORKSPACE/hudson/$REPO_BRANCH-setup.sh
fi

. build/envsetup.sh
lunch $LUNCH

rm -f $OUT/update*.zip*

UNAME=$(uname)

if [ "$UNAME" = "Darwin" ]
then
  THREADS=$(sysctl hw.ncpu | cut -f 2 -d :)
else
  THREADS=$(cat /proc/cpuinfo | grep processor | wc -l)
fi

if [ "$RELEASE_TYPE" = "CM_NIGHTLY" ]
then
  export CM_NIGHTLY=true
elif [ "$RELEASE_TYPE" = "CM_SNAPSHOT" ]
then
  export CM_SNAPSHOT=true
elif [ "$RELEASE_TYPE" = "CM_RELEASE" ]
then
  export CM_RELEASE=true
fi

if [ ! "$(ccache -s|grep -E 'max cache size'|awk '{print $4}')" = "5.0" ]
then
  ccache -M 5G
fi

make $CLEAN_TYPE
make -j$THREADS bacon
RESULT=$?

cp $OUT/update*.zip* $WORKSPACE/archive

exit $RESULT
