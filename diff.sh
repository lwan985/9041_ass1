#!/bin/bash
dir=`echo "$0" | sed 's/diff.sh//' | sed 's/.\///'`
path=`pwd`"/$dir"
cd $path

for file in *
do
    #echo "$file"
    if [[ "$file" =~ .pl$ ]]
    then
        file_name=`echo "$file" | sed 's/.pl//'`
        ../python2perl.pl < "$file_name.py" > "$file_name""_temp.pl" || continue
        perl "$file_name.pl" > 1.txt
        perl "$file_name""_temp.pl" > 2.txt
        if diff 1.txt 2.txt > /dev/null;
        then
            echo "$file translation SUCCESSFUL!"
            rm "$file_name""_temp.pl" || continue
        else
            echo "$file Fail!"
        fi
    fi
done
rm 1.txt || continue
rm 2.txt || continue
