#!/usr/bin/env python
# unpack_and_check.py
#
# Unpack tar files and verify that the chucksums in the Claritas manifest file match those of the copied files
# Must be run from within drive folder

import os
import re
import logging
import argparse
from pyflow import WorkflowRunner

SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))

def unpack_and_check(no_unpack, no_check):
    # Check for manifest file
    manifest = 'Manifest.csv'
    if not os.path.exists(manifest):
        print "Manifest.csv not found!"
        exit(1)
    setup_logging()
    # Unpack tar files
    workflow = TransferWorkflow(manifest, no_unpack, no_check)
    response = workflow.run(mode="local", nCores=2)
    if not response == 0:
        print "FAILED!"
        logging.error("Workflow failed!")
    else:
        print "Success"
        logging.info("Success")

def setup_logging():
    log_name = "checksum.log"
    logging.basicConfig(filename=log_name,
                            format='%(asctime)s %(name)-12s %(levelname)-8s %(message)s', level=logging.INFO)

class TransferWorkflow(WorkflowRunner):
    def __init__(self, manifest, no_unpack, no_check):
        self.manifest = manifest
        self.checksum_script = os.path.join(SCRIPT_DIR, "checksum.py")
        self.no_unpack = no_unpack
        self.no_check = no_check

    def workflow(self):
        with open(self.manifest) as f:
            samples = {}
            files = {}
            for line in f:
                if not re.match(r'^CLA*', line):
                    continue
                line = line.rstrip()
                drive_id, sample_id, file, checksum = line.split(",")
                if not sample_id in samples:
                    samples[sample_id] = 1
                files[file] = [sample_id, checksum]

            if not self.no_unpack:
                for s in samples:
                    untar_cmd = ['tar','-xvf',"%s.tar" % s]
                    untar_name = "untar_%s" % s
                    self.addTask(untar_name, untar_cmd)

            if not self.no_check:
                for f in files:
                    sample_id = files[f][0]
                    checksum = files[f][1]
                    cmd = [self.checksum_script, "--file", f, "--md5sum", checksum]
                    name = os.path.basename(f)
                    name = name.replace(".", "_")
                    untar_name = "untar_%s" % sample_id
                    if self.no_unpack:
                        untar_name = None
                    self.addTask(name, cmd, dependencies=untar_name)

def parse_command_line():
    parser = argparse.ArgumentParser(
        description = 'This script transfers data from a hard drive to a local computing cluster.')

    parser.add_argument("--do_not_unpack", default=False, action='store_true',
                                help="md5sum hash to check against")
    parser.add_argument("--do_not_check", default=False, action='store_true',
                                help="File to check.")

    options = parser.parse_args()
    return options

if __name__ == "__main__":
    options = parse_command_line()
    unpack_and_check(options.do_not_unpack, options.do_not_check)