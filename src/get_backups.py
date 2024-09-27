#!/usr/bin/python3

import os

import xml.etree.ElementTree as E
from datetime import datetime, timedelta
import argparse

VALID_EXTENSION = [".dump", ".gpg"]


def parse_cli():
    common_parser = argparse.ArgumentParser(add_help=False)
    common_parser.add_argument(
        "--xml-file",
        help="The XML file to process (generated via PROPFIND). "
        "Takes precedence over share_path if both are provided",
    )
    common_parser.add_argument(
        "--share-path",
        help="Path to the mounted share (used if --xml-file is not provided)",
    )

    parser = argparse.ArgumentParser(
        description="Backup manager for filtering and finding backups"
        " from ownCloud XML or a mounted share"
    )
    subparsers = parser.add_subparsers(
        dest="command", required=True, help="Subcommands"
    )

    # Subcommand: filterdate
    parser_filterdate = subparsers.add_parser(
        "filterdate",
        help="Filter files older than X days",
        parents=[common_parser],
    )
    parser_filterdate.add_argument(
        "--days",
        type=int,
        required=True,
        help="Filter files older than X days",
    )

    # Subcommand: latest
    parser_latest = subparsers.add_parser(
        "latest",
        help="Get the latest backup available",
        parents=[common_parser],
    )
    parser_latest.add_argument(
        "--database-name",
        required=True,
        help="Filter backup crypted with a specific database name",
    )
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

    args = parser.parse_args()

    if not args.xml_file and not args.share_path:
        parser.error("At least one of 'xml_file' or 'share_path' must be specified.")

    return args


def parse_xml(xml_file):
    tree = E.parse(xml_file)
    root = tree.getroot()
    files = []

    for response in root.findall("{DAV:}response"):
        full_name = response.find("{DAV:}href").text.strip()
        filename = os.path.basename(full_name)
        _, file_extensions = os.path.splitext(full_name)

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


def list_folder(folder_path):
    files = []

    for filename in os.listdir(folder_path):
        file_path = os.path.join(folder_path, filename)

        if os.path.isfile(file_path):
            last_modified_date = datetime.fromtimestamp(os.path.getmtime(file_path))
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


def latest(files, user_email, database_name, passphrase_crypted):
    filtered_files = []
    extension_to_find = ".gpg" if user_email or passphrase_crypted else ".dump"

    for filename, last_modified_date in files:
        _, file_extensions = os.path.splitext(filename)

        # No filename no party
        # Skip useless extensions or databases with different name
        if file_extensions != extension_to_find or not filename.startswith(
            database_name
        ):
            continue

        # If user email is specified, skip backups without the email in it's filename
        if user_email and user_email not in filename:
            continue

        # If user_email is not specified, skip backups that contain an email in the
        # filename
        if not user_email and "@" in filename:
            continue

        filtered_files.append((filename, last_modified_date))

    if filtered_files:
        latest_file = max(filtered_files, key=lambda x: x[1])
        print(latest_file[0])


def main():
    args = parse_cli()
    if args.xml_file:
        files = parse_xml(args.xml_file)
    elif args.share_path:
        files = list_folder(args.share_path)

    if args.command == "filterdate":
        filterdate(files, args.days)
    elif args.command == "latest":
        latest(files, args.user_email, args.database_name, args.passphrase_crypted)


if __name__ == "__main__":
    main()
