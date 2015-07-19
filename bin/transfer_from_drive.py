#!/usr/bin/env python
# transfer_from_drive.py
#
# Copy files from a mounted hard drive to computing cluster
# A hard drive mount point can be specified with --hard_drive or
# drives can be searched for in the mount dir with --search

import os
import argparse
import logging
import re
from pyflow import WorkflowRunner
import commands

MOUNT_DIR = '/Volumes'
DESTINATION = '/srv/gsfs0/projects/mvp/Claritas_ion_torrent_exomes/data'
SERVER = "scg3"
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
LOG_DIR = os.path.join(SCRIPT_DIR, "..", 'logs')

def transfer_data(hard_drive=None, search=False):

    # search if necessary
    if search is True:
        hard_drive = search_mount_dir()
    drive_path = MOUNT_DIR + "/" + hard_drive
    if not os.path.exists(drive_path):
        print "Hard drive not found! %s" % drive_path

    run_dir = os.path.join(LOG_DIR, hard_drive)
    if not os.path.exists(run_dir):
        os.makedirs(run_dir)
    os.chdir(run_dir)

    set_up_logging(hard_drive)

    print "Copying files from %s" % hard_drive
    logging.info("Hard drive: %s" % hard_drive)
    logging.info("Destination: %s:%s/%s" % (SERVER, DESTINATION, hard_drive))

    create_destination(SERVER, DESTINATION, hard_drive)

    files = get_files(drive_path)
    workflow = TransferWorkflow(drive_path, files, hard_drive, SERVER)
    return_value = workflow.run(mode="local", nCores=4)
    if not return_value == 0:
        print "Transfer failed!  See logs for details. %s" % LOG_DIR
        logging.error("Transfer failed!  See pyflow logs for details.")
    else:
        print "Success"
        logging.info("Success")

def get_files(drive_path):
    files = os.listdir(drive_path)
    return files

def search_mount_dir():
    hard_drives = [d for d in os.listdir(MOUNT_DIR) if re.match(r'CLA*', d)]
    if len(hard_drives) > 1:
        print("More than one drive mounted.  Please use --hard_drive to specify one drive to copy.")
        print("\t".join(hard_drives))
        exit(0)
    if len(hard_drives) < 1:
        print("No drives found in %s" % MOUNT_DIR)
        exit(0)
    return hard_drives[0]

def create_destination(server, destination, hard_drive):
    path_to_create = os.path.join(destination, hard_drive)
    ssh_cmd = "ssh %s mkdir %s" % (server, path_to_create)
    response = commands.getstatusoutput(ssh_cmd)

def set_up_logging(hard_drive):
    log_path = os.path.join(LOG_DIR, hard_drive, "transfer.log")
    logging.basicConfig(filename=log_path,
                            format='%(asctime)s %(name)-12s %(levelname)-8s %(message)s', level=logging.INFO)

class TransferWorkflow(WorkflowRunner):
    def __init__(self, drive_path, files, hard_drive, server):
        self.files = files
        self.drive_path = drive_path
        self.destination = os.path.join(DESTINATION, hard_drive)
        self.copy_job = os.path.join(SCRIPT_DIR, "copy.sh")
        self.server = server

    def workflow(self):
        for f in self.files:
            file_path = os.path.join(self.drive_path, f)
            logging.info("To copy: %s" % f)
            destination = self.server + ":" + os.path.join(self.destination, f)
            cmd = ["rsync", "-avLP", file_path, destination]
            name = "copy_%s" % f.replace(".", "_")
            self.addTask(name, cmd)

def parse_command_line():
    parser = argparse.ArgumentParser(
        description = 'This script transfers data from a hard drive to a local computing cluster.')

    parser.add_argument("--hard_drive", default=None,
                                help="Hard drive to copy data from")
    parser.add_argument("--search", default=False, action='store_true',
                                help="Search in mount directory for hard drives matching CLA*. Only one allowed.")

    options = parser.parse_args()
    if options.hard_drive is None and options.search is False:
        print "Exiting, specify a hard drive or search.  See transfer_from_drive.py --help for details."
        exit(0)

    if options.hard_drive is not None and options.search is True:
        print "Only one option allowed.  Please specify a hard drive or search, not both. " \
              "See transfer_from_drive.py --help for details."

    return options

if __name__ == "__main__":
    options = parse_command_line()
    transfer_data(options.hard_drive, options.search)