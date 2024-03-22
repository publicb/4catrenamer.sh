#!/usr/bin/bash

# $1 directory containing the files to be renamed
# $2 metadata csv file from 4cat

target_dir="$1"
meta_file="$2" 

# get correct column numbers from the metadata csv, as they are not always the same

id_field=$(sed -n $'1s/,/\\\n/gp' "$meta_file" | grep -nx 'id' | cut -d: -f1)
ts_field=$(sed -n $'1s/,/\\\n/gp' "$meta_file" | grep -nx 'timestamp' | cut -d: -f1)
au_field=$(sed -n $'1s/,/\\\n/gp' "$meta_file" | grep -nx 'author' | cut -d: -f1)

if [ -d "$target_dir" ]; then
	echo "target dir set to $target_dir"
else
	echo "not a directory. try again."
	exit 1
fi

if [ -f "$meta_file" ]; then
	echo "meta file set to $meta_file"
else
	echo "invalid meta file specified. try again"
	exit 1
fi

# create target dir for renamed files if it does not exist
# create logfile if it does not exist
# clear existing log file

mkdir -p "$target_dir/renamed" 
touch "$target_dir/rename.log" 
echo "" > "$target_dir/rename.log"

# cleanup files before renaming

for i in "$target_dir"/src/*; do
		
		# remove 4cat duplicates
		
		if [ "${i: -6}" == "-0.jpg" ]; then
				echo "removing duplicate file"
				rm -v "$i"
		fi
		
		# convert png to jpg, remove original files. png files cannot be looked up in the csv for some reason

		if [ "${i: -4}" == ".png" ]; then
			echo "converting png to jpg"
			mogrify -format jpg -verbose  "$i";     
			rm -v "$i";
		fi
done

# move 4cat metadata file out of source folder

if [ -f "$target_dir"/src/.metadata.json ]; then
		mv "$target_dir"/src/.metadata.json "$target_dir"
fi

# start of the main loop for looking up files in the metadata csv

for file in "$target_dir"/src/*
do
	if [ -f "$file" ]; then # prevents renaming of files in subdirectories
		orig_filename="$(find "$file" | xargs -0 basename)" # read filename without the path

# assemble the new_filename: 
# 1) prepare metadata csv with csvquote 
# 2) look up the file name in the metadata csv, without the extension (as per https://unix.stackexchange.com/questions/462385/how-to-remove-filename-extension-from-a-list-of-filenames-in-bash)
# 3) make sure only the first result is read - sometimes a filename is listed multiple times
# 4) pass shell variables to awk
# 5) remove "-" and ":" from the timestamp and replace spaces with a "-"
# 6) print new file name consisting of timestamp, author and post id
# 7) end csvquote

		new_filename="$(csvquote "$meta_file" | grep "${orig_filename%.*}" | head -n1 |  awk -v id="$id_field" -v ts="$ts_field" -v au="$au_field"  'BEGIN{ FS="," } { gsub("[:-]","",$ts); gsub(" ","-",$ts) } { print $ts "-" $au "-" $id  }' | csvquote -u)"


# get the extension from the original file

		extension="$(find "$target_dir"/src/"$orig_filename" | awk 'BEGIN{FS="."}{print $NF}')"
		new_filename+=".$extension"

# copy the file to the target directory using the new name

	cp -uv "$file" "$target_dir"/renamed/"$new_filename" 2>&1 | tee -a "$target_dir"/rename.log
	fi
done
