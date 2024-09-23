#!/usr/bin/python3

from os.path import basename, splitext

import xml.etree.ElementTree as E
from datetime import datetime, timedelta
import argparse

VALID_EXTENSION = ["dump", "dump.gpg"]


def main():
    parser = argparse.ArgumentParser(
        description="Extract filenames from XML based on date filters."
    )
    parser.add_argument("xml_file", help="The XML file to process")
    parser.add_argument(
        "--days", type=int, help="Filter files modified in the last X days"
    )

    args = parser.parse_args()

    tree = E.parse(args.xml_file)
    root = tree.getroot()

    files_to_be_deleted = []
    # Get timenow, only day month year count, and subtract n days.
    now = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    cutoff_date = now - timedelta(days=args.days)

    # Retrieve file names and modify date from xml
    for response in root.findall("{DAV:}response"):
        full_name = response.find("{DAV:}href").text.strip()
        filename = basename(full_name)
        _, file_extensions = splitext(full_name)

        # No filename no party
        if filename == "" and file_extensions not in VALID_EXTENSION:
            continue

        properties = response.find("{DAV:}propstat")
        lastmodify = properties.find("{DAV:}prop").find("{DAV:}getlastmodified").text

        last_modified_date = datetime.strptime(lastmodify, "%a, %d %b %Y %H:%M:%S GMT")
        last_modified_date = last_modified_date.replace(
            hour=0, minute=0, second=0, microsecond=0
        )

        # Files older than X days
        if last_modified_date < cutoff_date:
            files_to_be_deleted.append(filename)

    # !!! This print will be used from backup.sh
    print(",".join(files_to_be_deleted))


if __name__ == "__main__":
    main()
