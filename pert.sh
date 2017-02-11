#!/bin/bash

CSV=$1
DOT=`basename $CSV csv`dot
PNG=`basename $CSV csv`png

./pert.rb $CSV > $DOT
dot -Tpng $DOT > $PNG
