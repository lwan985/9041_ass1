#!/bin/bash
dir=`echo "$0" | sed 's/diff.sh//' | sed 's/.\///'`
path=`pwd`"/$dir"
cd $path

for file in *
do
    #echo "$file"
    if [[ "$file" =~ .py$ ]]
    then
        file_name=`echo "$file" | sed 's/.py//'`
        perl /home/ashnh/Desktop/COMP9041/Assignment_1/python2perl.pl < "$file_name.py" > "$file_name""_temp.pl" || continue
        python "$file_name.py" < "/home/ashnh/Desktop/COMP9041/Assignment_1/subset_5/enrollments" > 1.txt || exit 0
        perl "$file_name""_temp.pl" < "/home/ashnh/Desktop/COMP9041/Assignment_1/subset_5/enrollments" > 2.txt || exit 0
        if diff 1.txt 2.txt > /dev/null;
        then
            echo "$file translation SUCCESSFUL!"
            rm "$file_name""_temp.pl" || continue
        else
            echo "$file Fail!"
        fi
    fi
done
rm 1.txt || true
rm 2.txt || true
