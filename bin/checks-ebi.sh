#!/usr/bin/bash
set -euo pipefail

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

( cd $ROOT_DIR && [ -d "local" ] || carton )

if [ -d "$ROOT_DIR/local/R-3.6.1/bin" ] ; then
  PATH=$ROOT_DIR/local/R-3.6.1/bin:$PATH
  export PATH
fi

# hasDESeq2=$(R --slave --no-restore --file=- <<< 'installed.packages()' | grep ^DESeq2)
# if [ 0 -eq $(R --slave --no-restore --file=- <<< 'installed.packages()' | grep -c ^DESeq2) ]; then
#  echo "Your R doesn't have DESeq2 installed: " $(which R)
# fi
if [ "$#" -gt 0 ]; then
  PERL5LIB="$ROOT_DIR/lib:$ROOT_DIR/local/lib/perl5" prove $( find "$ROOT_DIR/t/" -type f $(perl -e 'print join(" -o ", map {"-name *$_*"} @ARGV )' "$@")  )
else
  PERL5LIB="$ROOT_DIR/lib:$ROOT_DIR/local/lib/perl5" prove -r $ROOT_DIR/t/
fi
