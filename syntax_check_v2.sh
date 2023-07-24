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

# Function to print usage and exit
usageExclude() {
    echo "Usage: $0 [-e|--exclude|--exclude=| <excluded_directory1>,<excluded_directory2>,...]"
    exit 1
}

# Function to check if a file is in any of the excluded directories
function is_in_excluded_directories {
    file="$1"
    for dir in "${excluded_directories[@]}"; do
        if [[ "$file" == "$dir"* ]]; then
            return 0
        fi
    done

    return 1
}

is_exclude=false

# Parse command-line options using getopts
while getopts ":e:s:-:" opt; do
    case "$opt" in
    # handle case `-e`
    e)
        is_exclude=true
        IFS=',' read -ra dirs <<<"$OPTARG"
        for dir in "${dirs[@]}"; do
            excluded_directories+=("$dir")
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
    # handle long option
    -)
        case "${OPTARG}" in

        # handle long option `--exclude`
        exclude | exclude=*)
            # Check if there is an equal sign "=" in the argument, case `--exclude=`
            if [[ "$OPTARG" == *"="* ]]; then
                IFS=',' read -ra dirs <<<"${OPTARG#*=}"
            else
                # If no equal sign, get the next argument, case `--exclude /path/to/exclude`
                IFS=',' read -ra dirs <<<"${!OPTIND}"
                OPTIND=$((OPTIND + 1))
            fi
            is_exclude=true
            for dir in "${dirs[@]}"; do
                excluded_directories+=("$dir")
            done
            ;;
        esac
        ;;
    esac
done

# Shift the processed options out of the argument list
shift $((OPTIND - 1))

if [[ "$is_exclude" = true && ${#excluded_directories[@]} -le 0 ]]; then
    usageExclude
fi
# argument list after all of the options
path_to_check=("$@")

# if there is no target path then append all the files that have .php extension from the entire project
if [ "${#path_to_check[@]}" -le 0 ]; then
    while IFS= read -r -d '' path; do
        path_to_check+=("$path")
    done < <(find $DIR -name '*.php' -print0)
fi

error_messages=()
parse_error_count=0
# Loop through the list of paths to run php lint against
for file in "${path_to_check[@]}"; do
    # Check if the file is in any of the excluded directories
    if is_in_excluded_directories "$file"; then
        echo "Skipping syntax check for: $file (excluded)"
        continue
    fi
    # Run php -l and capture only stderr
    error_output=$(php -l "$file" 2>&1 1>/dev/null)
    # if exit code from `error_output` not equal 0
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
done

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
