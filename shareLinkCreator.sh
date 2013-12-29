#!/bin/bash

# (c) Copyright 2013 Bjoern Schiessle <bjoern@schiessle.org>
#
# This program is free software released under the MIT License, for more details
# see LICENSE.txt or http://opensource.org/licenses/MIT
#
# Description: 
#
# This script can be integrated in the Thunar file manager as a "custom
# action". If you configure the "custom action" in Thunar, make sure that you
# pass the parameter "%F" to the program. Once the custom action is configured
# you can execute the program from the right-click context menu. The program
# works for all file types and also for directories. Once the script gets
# executed it will first upload the files/directories to your ownCloud and
# afterwards it will generate a public link to access them. The link will be
# copied directly to your clipboard and a dialog will inform you about the
# URL. If you uploaded a single file or directory than the file/directory will
# be created directly below your "uploadTarget" as defined below. If you
# selected multiple files, than the programm will group them together in a
# directory named with the current timestamp.
#
# Before you can use the program you need to adjust at least the "baseURL",
# "username" and "password" config parameter below
#
# Requirements:
#
# - curl
# - xclip
# - zenity

# config parameters
baseURL="http://localhost/oc"
uploadTarget="instant%20links6"
username="schiesbn"
password="schiesbn"

# constants
TRUE=0
FALSE=1

url="$baseURL/remote.php/webdav/$uploadTarget"
shareAPI="$baseURL/ocs/v1.php/apps/files_sharing/api/v1/shares"


# check if base dir for file upload exists
baseDirExists() {
    if curl -u $username:$password --output /dev/null --silent --head --fail "$url"; then
        return $FALSE
    fi
    return $TRUE
}

# upload files, first parameter will be the upload target from the second
# parameter on we have the list of files
uploadFiles() {
    for filePath in ${@:2}
    do
        if [ -f "$filePath" ]; then
            curl -u $username:$password -T $filePath "$1/$(basename $filePath)"
        else
            curl -u $username:$password -X MKCOL "$1/$(basename $filePath)"
            uploadDirectory "$1/$(basename $filePath)" $filePath 
        fi
        count=$(($count+1))
        echo $(($count*100/$numOfFiles)) >&3;
    done
    return $TRUE
}

# upload a directory recursively, first parameter contains the upload target
# and the second parameter contains the path to the local directory
uploadDirectory() {
    for filePath in `ls $2`; do
        if [ -d "$2/$filePath" ]; then
            curl -u $username:$password -X MKCOL "$1/$filePath"
            uploadDirectory "$1/$filePath" "$2/$filePath"      
        else
            curl -u $username:$password -T "$2/$filePath" "$1/$filePath"
        fi
    done

}

# create public link share, first parameter contains the path of the shared file/folder
createShare() {
    result=$(curl -u $username:$password --silent $shareAPI -d path=$1 -d shareType=3)
    shareLink=$(echo $result | sed -e 's/.*<url>\(.*\)<\/url>.*/\1/')
    shareLink=$(echo $shareLink | sed 's/\&amp;/\&/')
    echo "foo" | xclip
    return $TRUE

}

exec 3> >(zenity --progress --title="ownCloud Public Link Creator" --text="Uploading files and generating a public link" --auto-kill --auto-close --percentage=0 --width=400)

numOfFiles=$#
count=0

if baseDirExists; then
    curl -u $username:$password -X MKCOL "$url"
fi

# if we have more than one file selected we create a folder with
# the current timestamp
if [ $# -gt 1 ]; then
    share=$(date +%s)
    url="$url/$share"
    curl -u $username:$password -X MKCOL "$url"
elif [ $# -eq 1 ]; then
    share=$(basename $1)
else
    zenity --error --title="ownCloud Public Link Creator" --text="no file was selected!"
    exit 1
fi

args=("$@")
if uploadFiles $url "$@"; then
    createShare "/$uploadTarget/$share"
fi

output="File uploaded successfully. Following public link was generated and copied to your clipboard: $shareLink"
zenity --info --title="ownCloud Public Link Creator" --text="$output" --no-markup

# we need to write the share link to the clipboard at the end of the script
echo $shareLink | xclip

