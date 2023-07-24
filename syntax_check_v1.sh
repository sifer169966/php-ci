#!/usr/bin/env bash

# Bash PHP Linter for Pre-commits
#
# Exit 0 if no errors found
# Exit 1 if errors were found (incase -s argument has been passed to `first`)
#
# Requires
# - php
#
# Arguments
# -s : When to stop checking for errors
#      all   : Default. Will check ALL given files until there isn't anymore
#      first : Will stop checking when it encounters the first file that has an error
#
#      Example
#      -s first
#      -s all
# -e,--exclude : exclude target file or directory, Default it gonna checking for entire project
#      "directory/to/exclude/*"   : exclude all of the files into the target directory
#      "file/to/exclude/file.php" : exclude specific file
#      Example
#      -e  "directory/to/exclude/*"
#      --exclude  "file/to/exclude/file.php"

# Check Flags - denotes if we should check all files or stop at the first error file
check_args_flag_all='all'
check_args_flag_first='first'
check_all=true

# Plugin title
title="PHP Linter"

# Print a welcome and locate the exec for this tool
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $DIR/helpers/colors.sh
source $DIR/helpers/formatters.sh
source $DIR/helpers/welcome.sh

# Flag to denote if a PHP error was found
php_errors_found=false

# Directories to exclude (add more directories if needed)
excluded_directories=()
is_exclude=false

# Function to print usage and exit
usageExclude() {
    echo "Usage: $0 [-e|--exclude|--exclude=|-exclude <excluded_directory1>,<excluded_directory2>,...]"
    exit 1
}

# Parse command-line options using getopts
while getopts ":e:s:-:" opt; do
    case "$opt" in
    # handle case `-e`
    e)
        is_exclude=true
        IFS=',' read -ra dirs <<<"$OPTARG"
        for dir in "${dirs[@]}"; do
            excluded_directories+=("$DIR/$dir")
        done
        ;;
    # handle `-s`
    s)
        if [ $OPTARG == $check_args_flag_first ]; then
            check_all=false
        elif [ $OPTARG == $check_args_flag_all ]; then
            check_all=true
        else
            check_all=true
        fi
        ;;
    # handle `--exclude`
    -exclude | -e)
        case "${OPTARG}" in
        # handle long option `--exclude="/path/to/exclude1,/path/to/exclude2"`
        exclude=*)
            is_exclude=true
            IFS=',' read -ra dirs <<<"${OPTARG#*=}"
            for dir in "${dirs[@]}"; do
                excluded_directories+=("$dir")
            done
            ;;
        # handle long option `--exclude "/path/to/exclude1,/path/to/exclude2"`
        exclude)
            is_exclude=true
            IFS=',' read -ra dirs <<<"${!OPTIND}"
            OPTIND=$((OPTIND + 1))
            for dir in "${dirs[@]}"; do
                excluded_directories+=("$dir")
            done
            ;;
        *)
            usageExclude
            ;;
        esac
        ;;
    esac
done

# Shift the processed options out of the argument list
shift $((OPTIND - 1))

# Construct the exclude options for find command
exclude_options=()

for dir in "${excluded_directories[@]}"; do
    exclude_options+=("-not" "-path" "$dir" "-prune")
done

# Array to store error messages
error_messages=()
# Loop through the list of paths to run php lint against
parse_error_count=0
while IFS= read -r -d '' path; do
    # Run php -l and capture only stderr
    error_output=$(php -l "$path" 2>&1 1>/dev/null)
    if [ $? -ne 0 ]; then
        # Store the error message in the error_messages array
        error_messages+=("$error_output")
        parse_error_count=$(($parse_error_count + 1))
        php_errors_found=true
        if [ "$check_all" = false ]; then
            hr
            echo -e "${txtmag}Stopping at the first file with PHP Parse errors${txtrst}"
            hr
            for message in "${error_messages[@]}"; do
                echo -en "${txtrst} ${txtred}$message${txtrst} \n"
            done
            hr
            exit 1
        fi
    fi
done < <(find $DIR -name '*.php' "${exclude_options[@]}" -print0)

if [ "$php_errors_found" = true ]; then
    hr
    echo -en "${bldmag}$parse_error_count${txtrst} ${txtylw}PHP Parse error(s) were found!${txtrst} \n"
    hr
    # Print all error messages at the end of the process, one message per line
    if [ "${#error_messages[@]}" -gt 0 ]; then
        for message in "${error_messages[@]}"; do
            echo -en "${txtrst} ${txtred}$message${txtrst} \n"
        done
        hr
    fi
    exit 1
fi

exit 0
