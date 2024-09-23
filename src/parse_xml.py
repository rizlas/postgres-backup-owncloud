#!/usr/bin/python3

from os.path import basename, splitext

import xml.etree.ElementTree as E
from datetime import datetime, timedelta
import argparse

VALID_EXTENSION = [".dump", ".gpg"]


def parse_cli():
    parser = argparse.ArgumentParser(
        description="Backup manager for filtering and finding backups from ownCloud XML"
    )
    subparsers = parser.add_subparsers(
        dest="command", required=True, help="Subcommands"
    )

    # Subcommand: filterdate
    parser_filterdate = subparsers.add_parser(
        "filterdate", help="Filter files older than X days"
    )
    parser_filterdate.add_argument("xml_file", help="The XML file to process")
    parser_filterdate.add_argument(
        "--days",
        type=int,
        required=True,
        help="Filter files modified in the last X days",
    )

    # Subcommand: latest
    parser_latest = subparsers.add_parser(
        "latest", help="Get the latest backup available"
    )
    parser_latest.add_argument("xml_file", help="The XML file to process")
    parser_latest.add_argument(
        "--user-email",
        required=False,
        default="",
        help="Filter backup crypted with a specific user email",
    )
    parser_latest.add_argument(
        "--passphrase-crypted",
        action="store_true",
        help="Specify if the latest backup is passphrase-crypted",
    )

    return parser.parse_args()


def parse_xml(xml_file):
    tree = E.parse(xml_file)
    root = tree.getroot()
    files = []

    for response in root.findall("{DAV:}response"):
        full_name = response.find("{DAV:}href").text.strip()
        filename = basename(full_name)
        _, file_extensions = splitext(full_name)

        if filename == "" or file_extensions not in VALID_EXTENSION:
            continue

        properties = response.find("{DAV:}propstat")
        lastmodify = properties.find("{DAV:}prop").find("{DAV:}getlastmodified").text

        last_modified_date = datetime.strptime(lastmodify, "%a, %d %b %Y %H:%M:%S GMT")
        last_modified_date = last_modified_date.replace(
            hour=0, minute=0, second=0, microsecond=0
        )

        files.append((filename, last_modified_date))

    return files


def filterdate(files, days):
    # Get timenow, only day month year count, and subtract n days.
    now = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    cutoff_date = now - timedelta(days=days)

    # List comprehension to filter files older than the cutoff date
    files_to_be_deleted = [
        filename
        for filename, last_modified_date in files
        if last_modified_date < cutoff_date
    ]

    # !!! This print will be used from backup.sh
    print(",".join(files_to_be_deleted))


def latest(files, user_email, passphrase_crypted):
    filtered_files = []
    extension_to_find = ".gpg" if user_email or passphrase_crypted else ".dump"

    for filename, last_modified_date in files:
        _, file_extensions = splitext(filename)

        # No filename no party
        # Skip useless extensions
        if file_extensions != extension_to_find:
            continue

        # If user email is specified, skip backups without the email in it's filename
        if user_email and user_email not in filename:
            continue

        filtered_files.append((filename, last_modified_date))

    if filtered_files:
        latest_file = max(filtered_files, key=lambda x: x[1])
        print(latest_file[0])


def main():
    args = parse_cli()
    files = parse_xml(args.xml_file)

    if args.command == "filterdate":
        filterdate(files, args.days)
    elif args.command == "latest":
        latest(files, args.user_email, args.passphrase_crypted)


if __name__ == "__main__":
    main()
