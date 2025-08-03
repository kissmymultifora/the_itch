#!/bin/bash

awk -F'|' 'NR == FNR { $1 = ""; $2 = ""; seen[$0]++ } NR != FNR { orig = $0; $1 = ""; $2 = ""; if (!seen[$0]) print orig }' first.txt second.txt