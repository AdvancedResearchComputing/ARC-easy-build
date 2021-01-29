#!/bin/bash
#Script to rebuild an easyconfig and its dependencies. 
#The script works in two steps:
# 1. Make a list of dependencies and write to file
# 2. Rebuild from the file
#...because the user will often want to remove some items from the list 
#to avoid rebuilding more than they intend. The script also provides an 
#option for locating the easyconfigs in the easybuild repo so they're 
#rebuilt without any local customizations.
#
#Author: Justin Krometis, jkrometis@vt.edu

list=false
from_repo=false
build=false
buildpkgs="rebuild.txt"
buildfiles="rebuild_ecs.txt"

function printUsage {
  echo "Usage: rebuild.sh [OPTION]"
  echo
  echo Options:
  echo "--list config.eb       Make a list of dependencies for config.eb"
  echo "--from_repo            Convert the list of dependencies into an original list of easyconfigs from the repo"
  echo "--build                Build everything in the list of configs"
  echo "--pkgs=[filename]      Custom output file for dependencies (default: $buildpkgs)"
  echo "--configs=[filename]   Custom output file for easyconfigs (default: $buildpkgs, or $buildfiles if --from_repo is specified)"
  echo "-h,--help              Print this message"
  echo
  echo "Examples:"
  echo "   rebuild.sh --list intel-2020b.eb                        #make a list of dependencies for intel-2020b.eb"
  echo "   rebuild.sh --from_repo                                  #find dependencies in the easybuild repo"
  echo "   rebuild.sh --build                                      #rebuild everything in the list of configs"
  echo "   rebuild.sh --list --build intel-2020b.eb                #make a list of dependencies and rebuild them all (might build more than you want)"
  echo "   rebuild.sh --list --from_repo --build intel-2020b.eb    #make a list of dependencies, find them in the EB repo, and rebuild them all (might build more than you want)"
}

#if the user didn't provide anything, just print the help message and exit
if [ $# -eq 0 ]; then
    printUsage
    exit
fi

optspec=":h:-:"
while getopts "$optspec" optchar; do
    case "${optchar}" in
        -)
            case "${OPTARG}" in
                help)
                    printUsage
                    exit
                    ;;
                list)
                    list=true
                    ;;
                from_repo)
                    from_repo=true
                    ;;
                build)
                    build=true
                    ;;
                pkgs)
                    buildpkgs="${!OPTIND}"
                    OPTIND=$(( $OPTIND + 1 ))
                    ;;
                pkgs=*)
                    buildpkgs="${OPTARG#*=}"
                    ;;
                configs)
                    buildfiles="${!OPTIND}"
                    OPTIND=$(( $OPTIND + 1 ))
                    ;;
                configs=*)
                    buildfiles="${OPTARG#*=}"
                    ;;
                *)
                    break;
                    ;;
            esac;;
        -h)
          printUsage
          exit
          ;;
        *)
          break;
          ;;
    esac
done

shift $((OPTIND-1))

#assume the package name is everything before the first hyphen followed by a number
function getPkg {
  fl=$1
  echo $fl | sed 's/-[0-9].*$//'
}

#version is everything after the package name+hyphen before the .eb
function getVersion {
  fl=$1
  p=$( getPkg $fl )
  echo $fl | sed "s/^$p-\(.*\)\.eb$/\1/"
}


#make a list of dependencies for the given config
if [ "$list" = true ] ; then
  #error out if they didn't provide a config to check
  if [ $# -eq 0 ]; then
      echo "Please provide the easyconfig for which you want the list of dependencies."
      exit 1
  fi
  config=$1

  #get a list of dependencies
  printf "writing list of dependencies to ${buildpkgs}..."
  eb -Dr $config | grep '^ \*' | sed 's/(.*)//' | sed 's|^.*\/||' > $buildpkgs
  if [ $? -ne 0 ]; then
    printf "failed. exiting...\n"
    exit 1
  fi
  printf "done\n"
  
  #check build dates
  echo "these packages were built on the following dates. use this information to update the list of packages in ${buildpkgs} and rerun this script as necessary with --build"
  for fl in $( cat $buildpkgs ); do 
    p=$( getPkg $fl )
    v=$( getVersion $fl )
    ls -lh $EBROOTEASYBUILD/../../$p/$v/easybuild/*.log
  done
fi

#if requested, generate a list of specs from the easybuild 
#repo associated with those packages
if [ "$from_repo" = true ] ; then
  echo "Making list of easyconfigs from the easybuild repo in $buildfiles"
  > $buildfiles
  #get a list of full (original) easyconfig paths
  for fl in $( cat $buildpkgs ); do 
    p=$( getPkg $fl )
    pf=$( echo $p | grep -o '^.' | tr '[:upper:]' '[:lower:]') #first initial
    flfull="$EBROOTEASYBUILD/easybuild/easyconfigs/$pf/$p/$fl"
    echo $flfull >> $buildfiles 
  done
  
  #check that the full easyconfig paths exist
  #manually fix any that that are not found
  for fl in $( cat $buildfiles ); do 
    ls -lh $fl
  done
  if [ $? -ne 0 ]; then
    echo "Some of the build files were not found. Either edit $buildfiles to correct the paths or run without --repo so that the easyconfigs are found automatically. Exiting..."
    exit 1
  fi
#otherwise just use the list of packages directly
else
  buildfiles="$buildpkgs"
fi

#rebuild everything 
if [ "$build" = true ] ; then
  if [ ! -f "$buildfiles" ]; then
    echo "List of files to build $buildfiles does not exist."
    exit 1
  fi
  #rebuild all files
  echo "list of configs from ${buildfiles}:"
  cat $buildfiles
  read -p "rebuild the above easyconfigs? " -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    printf "\n$( date ): starting rebuild\n"
    for fl in $( cat $buildfiles ); do 
      eb -r --force $fl; 
    done
    echo "$( date ): finished rebuild"
  else
    printf "\nuser declined rebuild. exiting...\n"
  fi
fi
