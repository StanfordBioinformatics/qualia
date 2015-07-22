#!/usr/bin/env python
# checksum.py
#
# Check the md5sum hash of a given file against a provided hash

import os
import argparse
import logging
import subprocess

def checksum(md5sum, file):
    setup_logging()
    if not os.path.exists(file):
        print "File not found! %s" % file
        logging.info("md5sum check FAIL: %file - file not found")
        exit(1)

    hash = get_md5sum(file)
    if not hash == md5sum:
        print "md5sum check failed: %s actual: %s reported: %s" % (file, hash, md5sum)
        logging.info("md5sum check FAILED: %s actual: %s reported: %s" % (file, hash, md5sum))
        exit(0)
    logging.info("md5sum check PASS: %s actual: %s reported: %s" % (file, hash, md5sum))

def get_md5sum(file):
    cmd = ['md5sum', file]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = p.communicate()
    if not p.returncode == 0:
        print "md5sum hash of %s failed" % file
    hash = out.split(" ")[0]
    return hash

def setup_logging():
    log_name = "checksum.log"
    logging.basicConfig(filename=log_name,
                            format='%(asctime)s %(name)-12s %(levelname)-8s %(message)s', level=logging.INFO)

def parse_command_line():
    parser = argparse.ArgumentParser(
        description = 'This script transfers data from a hard drive to a local computing cluster.')

    parser.add_argument("--md5sum", default=None,
                                help="md5sum hash to check against")
    parser.add_argument("--file", default=None,
                                help="File to check.")

    options = parser.parse_args()
    if options.md5sum is None or options.file is None:
        print "Exiting, must specify both options.  See checksum.py --help for details."
        exit(0)
    return options

if __name__ == "__main__":
    options = parse_command_line()
    checksum(options.md5sum, options.file)