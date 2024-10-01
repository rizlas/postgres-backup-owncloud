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


def parse_xml(xml_file: str) -> list:
    """Parse XML file generated via WebDAV's PROPFIND.

    This function reads an XML file, finds all valid file entries (based on their
    extension), and returns a list of tuples containing the filename and its last
    modified date. The date is normalized to midnight (00:00:00) for comparison
    purposes.

    Parameters
    ----------
    xml_file : str
        Path to the XML file to be parsed.

    Returns
    -------
    list
        A list of tuples where each tuple contains:
            - filename (str): The name of the file extracted from the WebDAV response.
            - last_modified_date (datetime): The last modified date, truncated to
              midnight.

    """
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


def list_folder(folder_path: str) -> list:
    """List files in a specified folder and retrieve their last modified dates.

    This returns a list of tuples containing each filename and its last modified date.
    The date is normalized to midnight (00:00:00) for comparison purposes.

    Parameters
    ----------
    folder_path : str
        Path to the folder to be scanned.

    Returns
    -------
    list
        A list of tuples where each tuple contains:
            - filename (str): The name of the file.
            - last_modified_date (datetime): The last modified date, truncated to
              midnight.

    """
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


def filterdate(files: list, days: int) -> None:
    """Filter a list of files and print those older than a specified number of days.

    This function compares the last modified dates of the provided files against a
    cutoff date, which is `n` days before the current date. It filters out files that
    are older than the cutoff and prints their names as a comma-separated string. This
    output can be used by external scripts (e.g. `backup.sh`).

    Parameters
    ----------
    files : list
        A list of tuples where each tuple contains:
            - filename (str): The name of the file.
            - last_modified_date (datetime): The last modified date, truncated to
              midnight.
    days : int
        The number of days to use as a cutoff. Files older than this many days will be
        filtered.
    """
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


def latest(files: list, user_email: str, database_name: str, passphrase_crypted: bool):
    """Find and print the latest backup file from a list of files.

    Find and print the latest backup file from a list of files, filtered by user email,
    database name, and whether the file is passphrase-encrypted.

    This function filters the provided list of files based on several criteria: - The
    filename must match the specified database name. - The file extension must either be
    `.gpg` (for passphrase-encrypted or
      email-specific files) or `.dump` (for non-encrypted, general files).
    - If a user email is provided, the filename must contain the email. If no email is
      provided, files containing an email (with '@') are excluded.

    The latest file based on its last modified date is then printed. This output is
    intended for external use, such as by a shell script (e.g. `restore.sh`).

    Parameters
    ----------
    files : list
        A list of tuples where each tuple contains:
            - filename (str): The name of the file.
            - last_modified_date (datetime): The last modified date, truncated to
              midnight.
    user_email : str
        An optional email address to filter backups. Files must contain this email in
        their name if provided. If empty, files containing an email are excluded.
    database_name : str
        The name of the database to filter backups. Filenames must start with this
        database name.
    passphrase_crypted : bool
        A flag indicating whether to search for passphrase-encrypted files (with `.gpg`
        extension). If False, the function searches for non-encrypted `.dump` files.
    """
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
