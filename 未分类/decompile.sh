#!/bin/bash
cd "$(dirname "$0")"

test -e decompiled || mkdir decompiled

java -jar lysis-java.jar compiled/$1 > decompiled/$1.txt