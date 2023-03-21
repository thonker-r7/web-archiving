#!/bin/bash
# Tim H 2023
# dumps a single TikTok user's videos into local path
# Example usage:
# ./dump-single-tiktok-user.sh therock
#
# TODO:
#   * create a new jSON file every time, include timestamp in filename
#   * create a json DIFF, determine if/when any of the following has changed
#       * a video was taken down
#       * a comment was deleted
#       * a description changed (if possible)
#
#   * add support for digitally signing the hashsum files for authenticity
#   * potentially add support for scrolling all the way down on profile pages
#       to make sure it's downloading ALL the old videos
#   * change the output destination to be a parameter for this script: $2
#
# Known issues:
#   * If a video/comments have been downloaded before, it will overwrite the
#       previous .JSON file, but not update the hashsum. The old hashsum
#       will stay in hashsums.sha256, and it will appear as if the hashsum
#       check fails when checked.

# quit if any errors are encountered.
set -e

# where to dump the files. It'll create subdirectories automatically
DESTINATION_DOWNLOAD_PATH_BASE="$HOME/Downloads/tiktok_downloads"

# single username passed as the only parameter
DUMP_USERNAME="$1"

# temporary files
TMP_URL_LIST_FILENAME="TMP-TikTok-urls_to_download-$DUMP_USERNAME.txt"
TMP_HTML_DUMP_FILENAME="TMP-TikTok-profile_page-$DUMP_USERNAME.html"

# additional variables, derived from others
# don't add anything before $DUMP_USERNAME, there may be an @ symbol
DUMP_URL_SUBSTRING="$DUMP_USERNAME/video/"
DUMP_PROFILE_URL="https://www.tiktok.com/@$DUMP_USERNAME"
DESTINATION_DOWNLOAD_PATH_USER="$DESTINATION_DOWNLOAD_PATH_BASE/$DUMP_USERNAME"

create_list_of_user_video_URLs () {
    # visit the page using Selenium (so that JavaScript is rendered), and
    # output the full HTML to a local text file.
    # https://stackoverflow.com/questions/22739514/how-to-get-html-with-javascript-rendered-sourcecode-by-using-selenium
    echo "Extracting HTML file for user page using Selenium..."
     ./dump-video-list.py --url="$DUMP_PROFILE_URL" > "$TMP_HTML_DUMP_FILENAME"
    echo "Extracting video URLs from HTML file..."
    # parse the local HTML file (rendered by Selenium) with Lynx to extract
    # all of the URLs to each video post by a user
    lynx -dump -nonumbers -hiddenlinks=listonly "$TMP_HTML_DUMP_FILENAME" | \
        grep "$DUMP_URL_SUBSTRING" | sort --unique > "$TMP_URL_LIST_FILENAME"
}

dump_tiktok_user () {
    # call the third party utility yt-dlp to download videos and metadata
    # from a batch file that contains the list URLs to each video
    # yt-dlp will automatically look for a yt-dlp.conf file located in the
    # same directory and load configuration from it.
    # any additional configuration here (flags passed here) overwrites the
    # config file.
    yt-dlp --batch-file "$TMP_URL_LIST_FILENAME" \
        -o "$DESTINATION_DOWNLOAD_PATH_USER/TikTok_%(creator)s_%(upload_date)s_%(id)s.%(ext)s"
}

update_hashsums() {
    # creates the hashsums for any new videos downloaded and appends them
    # to the existing hashsums.sha256 file. Creates the hashsums.sha256 file
    # if it doesn't not already exist.

    cd "$DESTINATION_DOWNLOAD_PATH_USER" || exit 1
    touch hashsums.sha256 # create the file in case it doesn't exist
    
    find . -type f ! -name '*.sha256' -print0 |
        while IFS= read -r -d '' ITER_FILE; do
            # skip calculating the hashsum of this file if it has already been
            #   done. Otherwise calculate it and append it to the file
            # TODO: find a solution for .json files that change on every run
            if ! grep -q "$ITER_FILE" hashsums.sha256 ; then
                sha256sum "$ITER_FILE" >> hashsums.sha256
            fi
    done
}

# create the download path if it does not exist yet
# may not be necessary:
mkdir -p "$DESTINATION_DOWNLOAD_PATH_USER"

# use a browser to visit the profile page and generate a list of 
# unique URLs for each video's page. Will pass that to next function
create_list_of_user_video_URLs

# parse the list of URLs and download the new videos
# remove the temporary file when done
dump_tiktok_user

# remove temporary files
rm "$TMP_URL_LIST_FILENAME" "$TMP_HTML_DUMP_FILENAME"

# hash the newly downloaded files so they can be checked for
# integrity in the future.
update_hashsums

echo "finished dump-single-tiktok-user.sh successfully"